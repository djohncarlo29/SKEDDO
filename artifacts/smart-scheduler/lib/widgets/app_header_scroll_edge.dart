import 'package:flutter/gestures.dart' show DragStartBehavior;
import 'package:flutter/scheduler.dart' show SchedulerPhase;
import 'package:flutter/widgets.dart';
import 'package:flutter_liquid_glass_widgets/liquid_glass_widgets.dart'
    show GlassLargeTitleController;
import 'package:liquid_glass_easy/liquid_glass_easy.dart'
    show LiquidGlassEdge, LiquidGlassScrollEdge;

import '../app_theme.dart' show kSFProText;

const double kAppHeaderToolbarHeight = 44;
const double kAppHeaderTitleHeight = 57;
const double kAppHeaderTitleCollapseDistance = kAppHeaderTitleHeight;
const double kAppHeaderTitleTextBottomInset = 10;
const double kAppHeaderExpandedTitleContentGap = 16;
// The pinned toolbar button extends below the 44pt layout row. This expanded-
// only adjustment brings the large-title capline to a 16pt gap below the
// 40pt toolbar circle at the default title size, without changing collapse
// distance or compact-state geometry.
const double kAppHeaderExpandedTitleDownshift = 7.2;
const double kAppHeaderContentTopSpacing = 16;
// The settled leading circle extends to 50pt below the status-bar safe area.
// Compact content starts 16pt below that visible edge, so account for the
// different portrait and landscape header layout slots.
const double kAppHeaderSettledToolbarCircleBottom = 50.0;
// Shared toolbar centerline, measured from the app content origin below the
// status-bar safe area. Compact titles align to this, not the shorter row.
const double kAppHeaderSettledToolbarCircleCenter = 30.0;
const double kAppHeaderLandscapeToolbarHeight = 52.0;
const double kAppHeaderScrollEdgeHeaderBottomExtension = 16;
const double _kAppHeaderScrollEdgeMaxTintOpacity = 0.24;

double appHeaderCompactContentSpacingForOrientation(Orientation orientation) {
  final toolbarSlotHeight = orientation == Orientation.landscape
      ? kAppHeaderLandscapeToolbarHeight
      : kAppHeaderToolbarHeight;
  // Landscape pages have no collapsible title, so their scroll viewport
  // remains raised by the shared 16pt edge extension. The local spacer must
  // restore that extension before placing the first content edge.
  final viewportRaise = orientation == Orientation.landscape
      ? kAppHeaderScrollEdgeHeaderBottomExtension
      : 0.0;
  return (kAppHeaderSettledToolbarCircleBottom +
          kAppHeaderContentTopSpacing -
          toolbarSlotHeight +
          viewportRaise)
      .clamp(0.0, double.infinity)
      .toDouble();
}

double appHeaderExpandedTitleDownshiftForProgress(double collapseProgress) =>
    kAppHeaderExpandedTitleDownshift *
    (1.0 - collapseProgress.clamp(0.0, 1.0).toDouble());
const double _kAppHeaderScrollEdgeMaxBlurSigma = 4;

/// Shared scroll rules for second-level app headers.
///
/// Normal scrolling moves the title with its owning content and drives the
/// shell's Liquid Glass edge. Leading overscroll is different: content may
/// rubber-band, but the title stays at its resting position.
abstract final class AppHeaderScrollBehavior {
  /// Returns the non-negative distance scrolled away from the top.
  ///
  /// Use this for shell-owned titles and the shared scroll-edge progress so
  /// leading rubber-band overscroll never pulls those titles downward.
  static double contentOffset(ScrollMetrics metrics) {
    final offset = scrollOffsetIncludingOverscroll(metrics);
    if (!offset.isFinite || offset <= 0.0) return 0.0;
    return offset;
  }

  /// Returns the signed scroll position, including leading overscroll.
  ///
  /// Only use this while translating an active user drag into header movement.
  /// Clamping here would make a collapsed header immovable during a downward
  /// drag when the underlying scroll position is already at its leading edge.
  static double scrollOffsetIncludingOverscroll(ScrollMetrics metrics) {
    final offset = metrics.pixels - metrics.minScrollExtent;
    return offset.isFinite ? offset : 0.0;
  }

  /// Converts the package controller's normalized collapse value into the
  /// outgoing-title fade used by its GlassLargeTitle implementation.
  static double packageLargeTitleFadeProgress(double collapseProgress) {
    final progress = collapseProgress.isFinite
        ? collapseProgress.clamp(0.0, 1.0).toDouble()
        : 0.0;
    return 1.0 - Curves.easeIn.transform(1.0 - progress);
  }

  /// Converts the owning scroll position into the same normalized collapse
  /// progress used by the shell's [GlassLargeTitleController].
  ///
  /// The shell and in-scroll Calendar titles must use one distance so the
  /// outgoing large title and incoming compact title hand off in sync.
  static double titleCollapseProgress(double contentOffset) {
    if (!contentOffset.isFinite || contentOffset <= 0.0) return 0.0;
    return (contentOffset / kAppHeaderTitleCollapseDistance)
        .clamp(0.0, 1.0)
        .toDouble();
  }

  /// Mirrors GlassAppBar's compact-title fade without replacing the app's
  /// existing toolbar or Liquid Glass composition.
  static double packageCompactTitleFadeProgress(double collapseProgress) {
    final progress = collapseProgress.isFinite
        ? collapseProgress.clamp(0.0, 1.0).toDouble()
        : 0.0;
    final barProgress = ((progress - 0.5) / 0.5).clamp(0.0, 1.0);
    return Curves.easeOut.transform(barProgress);
  }

  /// The shell-owned large title follows the actual scroll position. The title
  /// slot remains in the scroll extent while it passes beneath the pinned
  /// toolbar, so adding a second slot-collapse distance would move the title
  /// twice as fast as the content.
  static double shellLargeTitleTravelOffset(double contentOffset) {
    if (!contentOffset.isFinite || contentOffset <= 0.0) return 0.0;
    return contentOffset;
  }

  /// Builds the glass edge while the large title passes through the pinned
  /// header, then continues as content passes beneath the toolbar.
  static double scrollEdgeProgress(double contentOffset) {
    if (!contentOffset.isFinite || contentOffset <= 0.0) return 0.0;
    return (contentOffset / (kAppHeaderTitleHeight + kAppHeaderToolbarHeight))
        .clamp(0.0, 1.0)
        .toDouble();
  }

  /// Returns the translation that cancels leading overscroll for a title
  /// which is otherwise laid out inside the scrollable content.
  static double leadingOverscrollCorrection(ScrollMetrics metrics) {
    final offset = metrics.pixels - metrics.minScrollExtent;
    if (!offset.isFinite || offset >= 0.0) return 0.0;
    return offset;
  }
}

/// Binds the package controller to the active outer header position.
///
/// Header collapse comes only from that real sliver position. The coordinated
/// inner body's offset contributes to glass-edge progress, not collapse state.
/// Legacy non-collapsing scroll surfaces can still bind their own position.
class AppHeaderTitleTransition extends ChangeNotifier {
  AppHeaderTitleTransition() : _controller = GlassLargeTitleController() {
    _controller.addListener(_forwardControllerChange);
    AppHeaderScrollView._positionRegistry.addListener(
      _handleNestedRegistryChanged,
    );
  }

  GlassLargeTitleController _controller;
  ScrollPosition? _position;
  ScrollPosition? _nestedBodyPosition;
  double _cachedContentOffset = 0.0;
  double _cachedCollapseProgress = 0.0;
  double _cachedSearchCollapseProgress = 0.0;
  double? _pendingHandoffCollapseProgress;
  double? _pendingHandoffSearchProgress;
  double _lastNotifiedContentOffset = 0.0;
  double _lastNotifiedCollapseProgress = 0.0;
  double? _lastPreparedCollapseProgress;
  bool _isBinding = false;
  bool _isSuspended = false;
  bool _notificationScheduled = false;
  bool _disposed = false;

  ScrollPosition? get position => _position;
  double get collapseProgress =>
      _pendingHandoffCollapseProgress ??
      (_position == null
          ? _cachedCollapseProgress
          : _controller.collapseProgress);
  double get rawScrollOffset => _controller.rawScrollOffset;
  double get searchBarCollapseProgress {
    final pending = _pendingHandoffSearchProgress;
    if (pending != null) return pending;
    if (_position == null) return _cachedSearchCollapseProgress;
    final extent = AppHeaderScrollView._searchExtentsByOuterPosition[_position];
    if (extent == null) return _cachedSearchCollapseProgress;
    // A screen with only the compact toolbar must not reopen a third header
    // level merely because the destination has a search bar.
    if (extent == 0) return collapseProgress >= 1 ? 1.0 : 0.0;
    return _controller.searchBarCollapseProgress;
  }

  double get contentOffset {
    final pendingProgress = _pendingHandoffCollapseProgress;
    if (pendingProgress != null) {
      return pendingProgress * kAppHeaderTitleCollapseDistance;
    }
    final currentPosition = _position;
    if (currentPosition == null || !currentPosition.hasContentDimensions) {
      return _cachedContentOffset;
    }
    _cachedContentOffset = AppHeaderScrollBehavior.contentOffset(
      currentPosition,
    ) + (_nestedBodyPosition == null
        ? 0.0
        : AppHeaderScrollBehavior.contentOffset(_nestedBodyPosition!));
    return _cachedContentOffset;
  }

  /// Binds to the single active scroll position. Recreating the package
  /// controller on handoff makes it recalculate from that position immediately.
  /// When [preserveCollapseProgress] is true, the new destination is positioned
  /// at the same shared header state before it becomes the active source. Each
  /// page also keeps separate expanded and scrolled body offsets so an expanded
  /// handoff never paints a stale destination position for a frame.
  void bindTo(
    ScrollPosition? position, {
    bool preserveCollapseProgress = false,
  }) {
    _isSuspended = false;
    if (identical(position, _position)) {
      _syncNestedBodyPosition();
      if (_pendingHandoffCollapseProgress == null &&
          (!preserveCollapseProgress || position != null)) {
        return;
      }
      if (preserveCollapseProgress) {
        _pendingHandoffSearchProgress = searchBarCollapseProgress;
        _pendingHandoffCollapseProgress = collapseProgress;
      }
      _isBinding = true;
      _applyPendingHandoff();
      _isBinding = false;
      _notifyIfChanged();
      _prepareInactiveDestinations(force: true);
      return;
    }

    final inheritedProgress = preserveCollapseProgress
        ? collapseProgress
        : _pendingHandoffCollapseProgress;
    final inheritedSearchProgress = preserveCollapseProgress
        ? searchBarCollapseProgress
        : _pendingHandoffSearchProgress;
    if (_position != null) {
      contentOffset;
      AppHeaderScrollView._rememberPositionBackup(_position!);
    }
    if (preserveCollapseProgress) {
      _pendingHandoffCollapseProgress = inheritedProgress;
      _pendingHandoffSearchProgress = inheritedSearchProgress;
    }

    final oldPosition = _position;
    _isBinding = true;
    _nestedBodyPosition?.removeListener(_handlePositionChanged);
    _nestedBodyPosition = null;
    _controller.removeListener(_forwardControllerChange);
    if (oldPosition != null) {
      oldPosition.removeListener(_handlePositionChanged);
      _controller.scrollController.detach(oldPosition);
    }
    _controller.dispose();

    _position = position;
    _syncNestedBodyPosition();
    if (position != null && preserveCollapseProgress) {
      // Keep the destination's former scrolled position as its non-expanded
      // backup before aligning it with the active screen's header state.
      AppHeaderScrollView._rememberPositionBackup(position);
    }
    if (position == null && _pendingHandoffCollapseProgress == null) {
      _cachedContentOffset = 0.0;
      _cachedCollapseProgress = 0.0;
      _cachedSearchCollapseProgress = 0.0;
    }
    _controller = GlassLargeTitleController(
      searchBarHeight:
          AppHeaderScrollView._searchExtentsByOuterPosition[position] ?? 0.0,
    )
      ..addListener(_forwardControllerChange);
    if (position != null) {
      _controller.scrollController.attach(position);
      position.addListener(_handlePositionChanged);
      // GlassLargeTitle reports the measured title row from layout. The
      // existing shell reserves a fixed title slot, so use that exact geometry.
      _controller.reportMeasuredHeight(kAppHeaderTitleCollapseDistance);
      _applyPendingHandoff();
      if (preserveCollapseProgress && inheritedProgress != null) {
        _restoreBodyPositionForHandoff(position, inheritedProgress);
      }
    } else if (_pendingHandoffCollapseProgress != null) {
      _cachedCollapseProgress = _pendingHandoffCollapseProgress!;
      _cachedContentOffset =
          _pendingHandoffCollapseProgress! * kAppHeaderTitleCollapseDistance;
    }
    if (_pendingHandoffCollapseProgress == null) {
      _cachedContentOffset = contentOffset;
      _cachedCollapseProgress = collapseProgress;
    }
    _lastNotifiedContentOffset = contentOffset;
    _lastNotifiedCollapseProgress = collapseProgress;
    _cachedSearchCollapseProgress = searchBarCollapseProgress;
    _isBinding = false;
    _prepareInactiveDestinations(force: true);
    _publishChange();
  }

  /// Stops observing scroll changes while a search transition owns the header,
  /// without changing the current visual state.
  void suspend() {
    final position = _position;
    _isSuspended = true;
    if (position == null) return;
    contentOffset;
    _cachedCollapseProgress = collapseProgress;
    _cachedSearchCollapseProgress = searchBarCollapseProgress;
    position.removeListener(_handlePositionChanged);
    _nestedBodyPosition?.removeListener(_handlePositionChanged);
    _nestedBodyPosition = null;
    _controller.scrollController.detach(position);
    _position = null;
  }

  void _forwardControllerChange() {
    _notifyIfChanged();
  }

  void _syncNestedBodyPosition() {
    final next = AppHeaderScrollView._bodyPositionsByOuterPosition[_position];
    if (identical(next, _nestedBodyPosition)) return;
    _nestedBodyPosition?.removeListener(_handlePositionChanged);
    _nestedBodyPosition = next;
    next?.addListener(_handlePositionChanged);
  }

  void _handleNestedRegistryChanged() {
    _syncNestedBodyPosition();
    final searchExtent =
        AppHeaderScrollView._searchExtentsByOuterPosition[_position] ?? 0.0;
    if (searchExtent > 0) _controller.reportSearchBarHeight(searchExtent);
    if (_pendingHandoffCollapseProgress != null) {
      _isBinding = true;
      _applyPendingHandoff();
      _isBinding = false;
    }
    _prepareInactiveDestinations(force: true);
    _notifyIfChanged();
  }

  /// Observe real outer/body positions even after the package's normalized
  /// collapse value stops changing, so the existing glass edge keeps following
  /// content passing beneath the compact toolbar.
  void _handlePositionChanged() {
    if (_isBinding) return;
    if (_pendingHandoffCollapseProgress != null) {
      _isBinding = true;
      _applyPendingHandoff();
      _isBinding = false;
    }
    final position = _position;
    if (position != null) {
      AppHeaderScrollView._rememberPositionBackup(position);
    }
    _prepareInactiveDestinations();
    _notifyIfChanged();
  }

  /// Keep every mounted destination's body ready for the active screen's
  /// latest header state. Do not move inactive outer header positions here:
  /// their local layouts already respond to the shared title, and their outer
  /// position is aligned by bindTo() before the destination is revealed.
  void _prepareInactiveDestinations({bool force = false}) {
    if (_disposed || _isSuspended) return;

    final progress = collapseProgress.clamp(0.0, 1.0).toDouble();
    if (!force &&
        _lastPreparedCollapseProgress != null &&
        (progress - _lastPreparedCollapseProgress!).abs() < 0.0005) {
      return;
    }
    _lastPreparedCollapseProgress = progress;

    for (final destination
        in AppHeaderScrollView._bodyPositionsByOuterPosition.keys.toList()) {
      if (identical(destination, _position) ||
          !destination.hasContentDimensions) {
        continue;
      }
      AppHeaderScrollView._rememberPositionBackup(destination);
      // A compact destination's body backup is retained separately and applied
      // after bindTo() first aligns its outer header. Jumping the body while
      // that inactive outer position is still expanded can couple the two and
      // corrupt the saved compact offset.
      if (progress >= 1.0 - 0.001) continue;
      _restoreBodyPositionForHandoff(destination, progress);
    }
  }

  void _restoreBodyPositionForHandoff(
    ScrollPosition outerPosition,
    double sharedCollapseProgress,
  ) {
    final bodyPosition = AppHeaderScrollView._bodyPositionForOuterPosition(
      outerPosition,
    );
    if (bodyPosition == null ||
        !bodyPosition.hasContentDimensions) {
      return;
    }

    // The body remains on its expanded backup throughout header-only
    // movement. Only a fully compact header selects the scrolled backup.
    final shouldExpand = sharedCollapseProgress < 1.0 - 0.001;
    final bodyOffset = AppHeaderScrollView._bodyOffsetForHandoff(
      outerPosition,
      expanded: shouldExpand,
    );
    if (bodyOffset == null) return;

    final bodyController =
        AppHeaderScrollView._contentControllerForOuterPosition(outerPosition);
    final bodyPositions = bodyController?.positions.toList() ??
        <ScrollPosition>[bodyPosition];
    for (final destinationBody in bodyPositions) {
      final destinationOuter =
          AppHeaderScrollView._outerPositionForBody(destinationBody);
      if (destinationOuter == null || !destinationBody.hasContentDimensions) {
        continue;
      }
      final destinationTarget =
          (destinationBody.minScrollExtent + bodyOffset)
              .clamp(
                destinationBody.minScrollExtent,
                destinationBody.maxScrollExtent,
              )
              .toDouble();
      if ((destinationBody.pixels - destinationTarget).abs() <= 0.5) {
        continue;
      }
      // NestedScrollView can couple an inner jump with its outer header.
      // Preserve each paired outer position while syncing bodies that share a
      // content controller.
      final sharedOuterOffset = destinationOuter.pixels;
      destinationBody.jumpTo(destinationTarget);
      if ((destinationOuter.pixels - sharedOuterOffset).abs() > 0.5) {
        destinationOuter.jumpTo(sharedOuterOffset);
      }
      AppHeaderScrollView._rememberPositionBackup(destinationOuter);
    }
    AppHeaderScrollView._rememberPositionBackup(outerPosition);
  }

  void _applyPendingHandoff() {
    final progress = _pendingHandoffCollapseProgress;
    final position = _position;
    if (progress == null || position == null || !position.hasContentDimensions) {
      return;
    }

    final minExtent = position.minScrollExtent;
    final maxExtent = position.maxScrollExtent;
    if (!minExtent.isFinite || !maxExtent.isFinite) return;

    final targetOffset =
        (minExtent +
            progress * kAppHeaderTitleCollapseDistance +
            (_pendingHandoffSearchProgress ?? 0.0) *
                (AppHeaderScrollView._searchExtentsByOuterPosition[position] ??
                    0.0))
            .clamp(minExtent, maxExtent)
            .toDouble();
    // Clear before jumpTo because NestedScrollPosition.jumpTo emits
    // ScrollNotifications synchronously. A notification listener can re-enter
    // bindTo for this same position before jumpTo returns.
    _pendingHandoffCollapseProgress = null;
    _pendingHandoffSearchProgress = null;
    if ((position.pixels - targetOffset).abs() > 0.5) {
      position.jumpTo(targetOffset);
    }
    _cachedContentOffset = AppHeaderScrollBehavior.contentOffset(position);
    _cachedCollapseProgress = _controller.collapseProgress;
  }

  void _notifyIfChanged() {
    if (_isBinding) return;
    final currentContentOffset = contentOffset;
    final currentCollapseProgress = collapseProgress;
    if (currentContentOffset == _lastNotifiedContentOffset &&
        currentCollapseProgress == _lastNotifiedCollapseProgress) {
      return;
    }
    _cachedCollapseProgress = currentCollapseProgress;
    _cachedSearchCollapseProgress = searchBarCollapseProgress;
    _lastNotifiedContentOffset = currentContentOffset;
    _lastNotifiedCollapseProgress = currentCollapseProgress;
    _publishChange();
  }

  void _publishChange() {
    // Settings inherits the header in didUpdateWidget. Geometry must be
    // aligned immediately, but sibling tabs cannot rebuild during that build.
    if (WidgetsBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      if (_notificationScheduled) return;
      _notificationScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _notificationScheduled = false;
        if (!_disposed) notifyListeners();
      });
      return;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    AppHeaderScrollView._positionRegistry.removeListener(
      _handleNestedRegistryChanged,
    );
    _nestedBodyPosition?.removeListener(_handlePositionChanged);
    _controller.removeListener(_forwardControllerChange);
    final position = _position;
    if (position != null) {
      position.removeListener(_handlePositionChanged);
      _controller.scrollController.detach(position);
    }
    _controller.dispose();
    super.dispose();
  }
}

/// Keeps centered placeholders aligned with the center of the usable content
/// area as the large-title slot collapses.
///
/// Lists retain their normal scroll behavior. This adjustment follows the
/// owning scroll position continuously and ignores leading overscroll.
class AppHeaderScrollCentered extends StatelessWidget {
  const AppHeaderScrollCentered({
    super.key,
    required this.child,
    this.enabled = true,
    this.fixedExpandedRegion = false,
  });

  final Widget child;
  final bool enabled;
  /// A fixed Calendar grid document does not relayout its empty region when
  /// the outer header releases viewport space. Its center gains half that
  /// released height. SliverFillRemaining content already relayouts itself.
  final bool fixedExpandedRegion;

  @override
  Widget build(BuildContext context) {
    if (!enabled || MediaQuery.orientationOf(context) != Orientation.portrait) {
      return child;
    }

    final position = Scrollable.maybeOf(context)?.position;
    if (position == null) return child;

    return AnimatedBuilder(
      animation: AppHeaderScrollView._positionRegistry,
      builder: (context, _) {
        final outer = AppHeaderScrollView._outerPositionForBody(position);
        if (outer != null && !fixedExpandedRegion) return child;
        final collapsePosition = outer ?? position;
        return AnimatedBuilder(
          animation: collapsePosition,
          builder: (context, _) {
            if (!collapsePosition.hasContentDimensions) return child;
            final contentOffset = AppHeaderScrollBehavior.contentOffset(
              collapsePosition,
            );
            final collapsedDistance = contentOffset
                .clamp(0.0, kAppHeaderTitleHeight)
                .toDouble();
            if (collapsedDistance == 0.0) return child;
            return Transform.translate(
              offset: Offset(0.0, collapsedDistance * 0.5),
              child: child,
            );
          },
        );
      },
    );
  }
}

/// Keeps a second-level title fixed during leading rubber-band overscroll while
/// leaving its ordinary scroll-away motion unchanged.
///
/// The title remains part of the scrollable content, so it still travels
/// beneath the app header and participates in the shared Liquid Glass edge
/// during normal upward scrolling. Only negative top overscroll is cancelled.
class AppHeaderScrollTitle extends StatelessWidget {
  const AppHeaderScrollTitle({
    super.key,
    required this.controller,
    required this.child,
  });

  final ScrollController? controller;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scrollController = controller;
    final sharedTitleTransition =
        AppHeaderScrollInsetScope.titleTransitionOf(context);

    // Resolve the Scrollable that actually contains this title. Some calendar
    // modes intentionally share one controller with an embedded list, so the
    // controller can have multiple positions even though this title belongs to
    // exactly one of them.
    final owningPosition = Scrollable.maybeOf(context)?.position;
    final positionListenable = owningPosition ?? scrollController;
    final animationSources = <Listenable>[
      if (positionListenable != null) positionListenable,
      if (sharedTitleTransition != null) sharedTitleTransition,
    ];
    if (animationSources.isEmpty) return child;
    final animation = animationSources.length == 1
        ? animationSources.single
        : Listenable.merge(animationSources);
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final positions = scrollController?.positions ?? const <ScrollPosition>[];
        final position =
            owningPosition ?? (positions.length == 1 ? positions.single : null);
        final collapseProgress = sharedTitleTransition?.collapseProgress ??
            (position != null && position.hasContentDimensions
                ? AppHeaderScrollBehavior.titleCollapseProgress(
                    AppHeaderScrollBehavior.contentOffset(position),
                  )
                : null);
        if (collapseProgress == null) return child;
        final fadeProgress =
            AppHeaderScrollBehavior.packageLargeTitleFadeProgress(
              collapseProgress,
            );
        final correction = position != null && position.hasContentDimensions
            ? AppHeaderScrollBehavior.leadingOverscrollCorrection(position)
            : 0.0;
        final title = AppHeaderLargeTitleHandoff(
          progress: fadeProgress,
          child: child,
        );
        if (position == null ||
            !position.hasContentDimensions ||
            correction == 0.0) {
          return title;
        }
        return Transform.translate(
          offset: Offset(0.0, correction),
          child: title,
        );
      },
    );
  }
}

/// Provides the amount of app-shell space between a page's layout origin and
/// the physical top of its scroll viewport.
///
/// The page can keep its existing layout below the fixed header. App-level
/// scroll views use this inset to extend their viewport upward and add the same
/// amount to their scroll extent, so slivers remain alive while passing behind
/// the header instead of being culled at the page's internal top.
class AppHeaderScrollInsetScope extends InheritedWidget {
  const AppHeaderScrollInsetScope({
    super.key,
    required this.leadingInset,
    this.titleCollapseExtent = 0.0,
    this.titleTransition,
    required super.child,
  });

  final double leadingInset;
  /// The measured scroll distance needed to move the expanded title region
  /// out of the usable viewport and reach the compact header.
  final double titleCollapseExtent;
  final AppHeaderTitleTransition? titleTransition;

  static AppHeaderTitleTransition? titleTransitionOf(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<AppHeaderScrollInsetScope>()
          ?.titleTransition;

  static double maybeOf(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<AppHeaderScrollInsetScope>()
          ?.leadingInset ??
      0.0;

  static double titleCollapseExtentOf(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<AppHeaderScrollInsetScope>()
          ?.titleCollapseExtent ??
      0.0;

  @override
  bool updateShouldNotify(AppHeaderScrollInsetScope oldWidget) =>
      leadingInset != oldWidget.leadingInset ||
      titleCollapseExtent != oldWidget.titleCollapseExtent ||
      titleTransition != oldWidget.titleTransition;
}

/// Extends a page scroll viewport upward by the shell inset without moving its
/// parent's layout. The scrollable's own content must include a matching
/// leading inset so its initial on-screen position stays unchanged.
class AppHeaderScrollViewport extends StatelessWidget {
  const AppHeaderScrollViewport({
    super.key,
    required this.leadingInset,
    required this.child,
    this.topExtension = 0.0,
  });

  final double leadingInset;
  final Widget child;
  final double topExtension;

  @override
  Widget build(BuildContext context) {
    final safeLeadingInset = leadingInset.isFinite && leadingInset > 0.0
        ? leadingInset
        : 0.0;
    final safeTopExtension = topExtension.isFinite && topExtension > 0.0
        ? topExtension
        : 0.0;
    if (safeLeadingInset == 0.0 && safeTopExtension == 0.0) return child;

    return LayoutBuilder(
      builder: (context, constraints) {
        if (!constraints.hasBoundedHeight) return child;
        final totalTopExtension = safeLeadingInset + safeTopExtension;
        final viewportHeight = constraints.maxHeight + totalTopExtension;
        return OverflowBox(
          alignment: Alignment.topCenter,
          minHeight: viewportHeight,
          maxHeight: viewportHeight,
          child: Transform.translate(
            offset: Offset(0.0, -totalTopExtension),
            child: SizedBox(height: viewportHeight, child: child),
          ),
        );
      },
    );
  }
}

/// A [SingleChildScrollView] whose viewport reaches behind the persistent
/// first-level header while retaining the normal scrollable lifecycle.
class AppHeaderSingleChildScrollView extends SingleChildScrollView {
  const AppHeaderSingleChildScrollView({
    super.key,
    required this.leadingInset,
    super.controller,
    super.physics,
    super.padding,
    super.child,
  });

  final double leadingInset;

  @override
  Widget build(BuildContext context) => AppHeaderScrollViewport(
    leadingInset: leadingInset,
    child: super.build(context),
  );
}

/// Keeps pane and page clips aligned with the physical viewport when their
/// children scroll beneath the fixed app header. The clip still constrains the
/// horizontal pane and bottom edge; only its top reaches through the shell
/// inset.
class AppHeaderScrollClip extends StatelessWidget {
  const AppHeaderScrollClip({
    super.key,
    required this.child,
    this.clipBehavior = Clip.hardEdge,
  });

  final Widget child;
  final Clip clipBehavior;

  @override
  Widget build(BuildContext context) {
    final leadingInset = AppHeaderScrollInsetScope.maybeOf(context);
    return ClipRect(
      clipBehavior: clipBehavior,
      clipper: leadingInset > 0.0 && leadingInset.isFinite
          ? _AppHeaderScrollClipper(leadingInset)
          : null,
      child: child,
    );
  }
}

class _AppHeaderScrollClipper extends CustomClipper<Rect> {
  const _AppHeaderScrollClipper(this.leadingInset);

  final double leadingInset;

  @override
  Rect getClip(Size size) =>
      Rect.fromLTWH(0.0, -leadingInset, size.width, size.height + leadingInset);

  @override
  bool shouldReclip(_AppHeaderScrollClipper oldClipper) =>
      leadingInset != oldClipper.leadingInset;
}

class _AppHeaderScrollBackup {
  double? expandedBodyOffset;
  double? scrolledBodyOffset;
}

/// A scroll viewport whose physical extent reaches behind the pinned
/// first-level header, where [AppHeaderScrollEdge] applies its visual treatment.
/// The scroll extent grows by the same amount as the viewport so initial layout
/// and normal scroll metrics remain stable.
class AppHeaderScrollView extends StatelessWidget {
  const AppHeaderScrollView({
    Key? key,
    this.scrollDirection = Axis.vertical,
    this.reverse = false,
    this.controller,
    this.primary,
    this.physics,
    this.scrollBehavior,
    this.shrinkWrap = false,
    this.center,
    this.anchor = 0.0,
    this.cacheExtent,
    this.paintOrder = SliverPaintOrder.firstIsTop,
    this.slivers = const <Widget>[],
    this.semanticChildCount,
    this.dragStartBehavior = DragStartBehavior.start,
    this.keyboardDismissBehavior,
    this.restorationId,
    this.hitTestBehavior = HitTestBehavior.opaque,
    this.clipBehavior = Clip.none,
    this.topExtension = 0.0,
    this.mirrorSharedHeaderCollapse = false,
  }) : _scrollViewKey = key,
       super(key: null);

  final Key? _scrollViewKey;
  final Axis scrollDirection;
  final bool reverse;
  final ScrollController? controller;
  final bool? primary;
  final ScrollPhysics? physics;
  final ScrollBehavior? scrollBehavior;
  final bool shrinkWrap;
  final Key? center;
  final double anchor;
  final double? cacheExtent;
  final SliverPaintOrder paintOrder;
  final List<Widget> slivers;
  final int? semanticChildCount;
  final DragStartBehavior dragStartBehavior;
  final ScrollViewKeyboardDismissBehavior? keyboardDismissBehavior;
  final String? restorationId;
  final HitTestBehavior hitTestBehavior;
  final Clip clipBehavior;
  final double topExtension;
  /// Keeps an inactive preview panel's outer header at the active shell
  /// title's collapse progress. Its body scroll offset remains independent.
  final bool mirrorSharedHeaderCollapse;

  static final Map<ScrollController, List<ScrollPosition>>
      _outerPositionsByContentController = {};
  static final Expando<_AppHeaderScrollBackup> _scrollBackups =
      Expando<_AppHeaderScrollBackup>('AppHeaderScrollView.backups');
  static final Map<ScrollPosition, ScrollPosition>
      _bodyPositionsByOuterPosition = {};
  static final Map<ScrollPosition, double> _searchExtentsByOuterPosition = {};
  static final _AppHeaderPositionRegistry _positionRegistry =
      _AppHeaderPositionRegistry();

  static bool isHeaderPosition(ScrollPosition? position) =>
      _bodyPositionsByOuterPosition.containsKey(position);

  static double _maxContentTopSpacingOf(
    BuildContext context, {
    required double topExtension,
  }) =>
      AppHeaderScrollInsetScope.titleCollapseExtentOf(context) > 0 &&
              topExtension.isFinite &&
              topExtension > 0
          ? topExtension
          : 0.0;

  /// Additional body spacing needed to keep [desiredGap] below the expanded
  /// title baseline or text bottom, while preserving compact-state spacing.
  ///
  /// [existingSpacing] is the first body's authored top gap.
  /// [baselineDescent] converts the title-slot bottom inset to a baseline
  /// anchor. Body content passes its viewport extension to compensate for the
  /// raised scroll body; the pinned search-header call leaves it at zero.
  static double expandedTitleContentGapAdjustment({
    required double desiredGap,
    required double existingSpacing,
    required double collapseProgress,
    double topExtension = 0.0,
    double baselineDescent = 0.0,
  }) {
    if (!desiredGap.isFinite ||
        desiredGap <= 0 ||
        !existingSpacing.isFinite ||
        !topExtension.isFinite ||
        !baselineDescent.isFinite) {
      return 0.0;
    }
    final progress = collapseProgress.isFinite
        ? collapseProgress.clamp(0.0, 1.0).toDouble()
        : 0.0;
    final targetFromSlotBottom =
        desiredGap -
        existingSpacing +
        topExtension -
        kAppHeaderTitleTextBottomInset -
        baselineDescent;
    return targetFromSlotBottom * (1.0 - progress);
  }

  /// Restores authored first-content spacing as the search header collapses.
  static double compactContentTopSpacingForProgress({
    required double compactSpacing,
    required double collapseProgress,
  }) {
    if (!compactSpacing.isFinite || compactSpacing <= 0.0) return 0.0;
    final progress = collapseProgress.isFinite
        ? collapseProgress.clamp(0.0, 1.0).toDouble()
        : 0.0;
    return compactSpacing * progress;
  }

  /// Baseline-to-line-bottom distance for the default 34pt bold Large Header.
  /// It converts the shared line-box inset into a baseline anchor.
  static final double titleBaselineDescent = _measureTitleBaselineDescent();

  static double _measureTitleBaselineDescent() {
    final painter = TextPainter(
      text: TextSpan(
        text: 'Ag',
          style: TextStyle(
            fontFamily: kSFProText,
            fontSize: 34,
            fontWeight: FontWeight.bold,
          ),
      ),
      textDirection: TextDirection.ltr,
      textScaler: TextScaler.noScaling,
    )..layout();
    final metrics = painter.computeLineMetrics();
    final descent = metrics.isEmpty ? 0.0 : metrics.first.descent;
    painter.dispose();
    return descent.isFinite && descent > 0.0 ? descent : 0.0;
  }

  /// Remaining clearance for fixed Calendar layouts without a search region.
  /// It follows title collapse, rather than shifting the expanded layout.
  static double contentTopSpacingOf(
    BuildContext context, {
    required double topExtension,
  }) {
    final orientation = MediaQuery.orientationOf(context);
    if (orientation == Orientation.landscape) {
      // Landscape is already at the compact header endpoint and its viewport
      // stays raised by topExtension, so restore that raise plus the
      // toolbar-to-content clearance in the fixed Calendar chrome.
      return topExtension.isFinite && topExtension > 0.0
          ? appHeaderCompactContentSpacingForOrientation(orientation)
          : 0.0;
    }

    if (AppHeaderScrollInsetScope.titleCollapseExtentOf(context) <= 0.0) {
      return 0.0;
    }
    final collapseProgress =
        AppHeaderScrollInsetScope.titleTransitionOf(context)?.collapseProgress ??
        0.0;
    final compactClearance =
        appHeaderCompactContentSpacingForOrientation(orientation) -
        kAppHeaderContentTopSpacing;
    return (_maxContentTopSpacingOf(context, topExtension: topExtension) +
            compactClearance) *
        (collapseProgress.isFinite
            ? collapseProgress.clamp(0.0, 1.0).toDouble()
            : 0.0);
  }

  static ScrollPosition? _outerPositionForBody(ScrollPosition bodyPosition) {
    for (final entry in _bodyPositionsByOuterPosition.entries) {
      if (identical(entry.value, bodyPosition)) return entry.key;
    }
    return null;
  }

  static ScrollController? _contentControllerForOuterPosition(
    ScrollPosition outerPosition,
  ) {
    for (final entry in _outerPositionsByContentController.entries) {
      if (entry.value.contains(outerPosition)) return entry.key;
    }
    return null;
  }

  static void _rememberPositionBackup(ScrollPosition outerPosition) {
    if (!outerPosition.hasContentDimensions) return;
    final controller = _contentControllerForOuterPosition(outerPosition);
    final bodyPosition = _bodyPositionsByOuterPosition[outerPosition];
    if (controller == null ||
        bodyPosition == null ||
        !bodyPosition.hasContentDimensions) {
      return;
    }

    final backup = _scrollBackups[controller] ??= _AppHeaderScrollBackup();
    final bodyOffset = AppHeaderScrollBehavior.contentOffset(bodyPosition);
    if (bodyOffset > 0.5) {
      backup.scrolledBodyOffset = bodyOffset;
    } else {
      backup.expandedBodyOffset = 0.0;
    }
  }

  static double? _bodyOffsetForHandoff(
    ScrollPosition outerPosition, {
    required bool expanded,
  }) {
    final controller = _contentControllerForOuterPosition(outerPosition);
    // A few pushed Settings screens intentionally have no page controller.
    // They still inherit the shared header and start with a zero body backup.
    if (controller == null) return 0.0;
    final backup = _scrollBackups[controller];
    if (expanded) return backup?.expandedBodyOffset ?? 0.0;
    return backup?.scrolledBodyOffset ?? backup?.expandedBodyOffset ?? 0.0;
  }

  static ScrollPosition? _bodyPositionForOuterPosition(
    ScrollPosition outerPosition,
  ) => _bodyPositionsByOuterPosition[outerPosition];

  /// Returns the outer header position paired with an existing page controller.
  ///
  /// Each page retains its own body controller; NestedScrollView supplies the
  /// independent collapse range for the large-title sliver.
  static ScrollPosition? headerPositionFor(
    ScrollController? contentController,
  ) {
    if (contentController == null) return null;
    final positions = _outerPositionsByContentController[contentController];
    if (positions == null) return null;
    for (final position in positions.reversed) {
      if (position.hasContentDimensions) return position;
    }
    return null;
  }

  /// Moves the body in body coordinates while preserving its paired outer
  /// header position.
  ///
  /// NestedScrollView can couple an inner jump to the outer header, including
  /// a jump to the inner minimum. Search/layout restoration means "move only
  /// this body"; it must never change the active header state.
  static void jumpBodyTo(ScrollController controller, double offset) {
    for (final position in controller.positions.toList()) {
      jumpBodyPositionTo(position, offset);
    }
  }

  /// Moves one nested body position without allowing NestedScrollView to
  /// reinterpret the body offset as a request to collapse its outer header.
  static void jumpBodyPositionTo(ScrollPosition position, double offset) {
    final target = position.hasContentDimensions
        ? offset
              .clamp(position.minScrollExtent, position.maxScrollExtent)
              .toDouble()
        : offset;
    if ((position.pixels - target).abs() <= 0.01) return;

    final outer = _outerPositionForBody(position);
    if (outer == null || !outer.hasContentDimensions) {
      position.jumpTo(target);
      return;
    }

    final outerOffset = outer.pixels;
    position.jumpTo(target);
    if ((outer.pixels - outerOffset).abs() > 0.5) {
      outer.jumpTo(outerOffset);
    }
    _rememberPositionBackup(outer);
  }

  static void _registerOuterPosition(
    ScrollController? contentController,
    ScrollPosition position, {
    required ScrollPosition bodyPosition,
    double searchBarExtent = 0,
  }
  ) {
    var changed = _bodyPositionsByOuterPosition[position] != bodyPosition ||
        _searchExtentsByOuterPosition[position] != searchBarExtent;
    _bodyPositionsByOuterPosition[position] = bodyPosition;
    _searchExtentsByOuterPosition[position] = searchBarExtent;
    if (contentController != null) {
      final positions = _outerPositionsByContentController.putIfAbsent(
        contentController,
        () => <ScrollPosition>[],
      );
      if (!positions.contains(position)) {
        positions.add(position);
        changed = true;
      }
    }
    if (changed) _positionRegistry.changed();
  }

  static void _unregisterOuterPosition(
    ScrollController? contentController,
    ScrollPosition? position,
  ) {
    if (position == null) return;
    final changed = _bodyPositionsByOuterPosition.remove(position) != null;
    _searchExtentsByOuterPosition.remove(position);
    final positions = _outerPositionsByContentController[contentController];
    positions?.remove(position);
    if (positions?.isEmpty ?? false) {
      _outerPositionsByContentController.remove(contentController);
    }
    if (changed) _positionRegistry.changed();
  }

  @override
  Widget build(BuildContext context) {
    final sharedTitleTransition =
        AppHeaderScrollInsetScope.titleTransitionOf(context);
    final leadingInset =
        scrollDirection == Axis.vertical && !reverse && !shrinkWrap
        ? AppHeaderScrollInsetScope.maybeOf(context)
        : 0.0;
    final configuredTitleCollapseExtent =
        scrollDirection == Axis.vertical &&
            !reverse &&
            !shrinkWrap &&
            center == null
        ? AppHeaderScrollInsetScope.titleCollapseExtentOf(context)
        : 0.0;
    final titleCollapseExtent =
        configuredTitleCollapseExtent.isFinite &&
            configuredTitleCollapseExtent > 0.0
        ? configuredTitleCollapseExtent
        : 0.0;
    final scrollSlivers = <Widget>[
      if (leadingInset > 0.0)
        SliverToBoxAdapter(child: SizedBox(height: leadingInset)),
      ...slivers,
    ];
    final scrollView = CustomScrollView(
      key: _scrollViewKey,
      scrollDirection: scrollDirection,
      reverse: reverse,
      controller: controller,
      primary: primary,
      physics: physics,
      scrollBehavior: scrollBehavior,
      shrinkWrap: shrinkWrap,
      center: center,
      anchor: anchor,
      cacheExtent: cacheExtent,
      paintOrder: paintOrder,
      slivers: scrollSlivers,
      semanticChildCount: semanticChildCount,
      dragStartBehavior: dragStartBehavior,
      keyboardDismissBehavior: keyboardDismissBehavior,
      restorationId: restorationId,
      hitTestBehavior: hitTestBehavior,
      clipBehavior: clipBehavior,
    );

    final titleInsetIndex = slivers.indexWhere(
      (sliver) =>
          sliver is SliverToBoxAdapter &&
          sliver.child is AppHeaderScrollInset,
    );
    final titleInset = titleInsetIndex < 0
        ? null
        : (slivers[titleInsetIndex] as SliverToBoxAdapter).child
              as AppHeaderScrollInset;
    if (titleInset != null &&
        titleInset.enabled &&
        titleCollapseExtent > 0.0 &&
        scrollDirection == Axis.vertical &&
        !reverse &&
        !shrinkWrap &&
        center == null &&
        anchor == 0.0) {
      final innerSlivers = [...slivers]..removeAt(titleInsetIndex);
      final maxContentTopSpacing = _maxContentTopSpacingOf(
        context,
        topExtension: topExtension,
      );
      var minimumContentTopSpacing = 0.0;
      var hasAuthoredContentSpacing = false;
      // Preserve Settings' authored expanded inset in the shared slot. This
      // baseline is separate from the additional compact-state clearance.
      if (maxContentTopSpacing > 0 &&
          innerSlivers.isNotEmpty &&
          innerSlivers.first is SliverToBoxAdapter &&
          (innerSlivers.first as SliverToBoxAdapter).child
              is AppHeaderContentSpacing) {
        minimumContentTopSpacing = kAppHeaderContentTopSpacing;
        hasAuthoredContentSpacing = true;
        innerSlivers.removeAt(0);
      }
      final authoredCompactClearance = hasAuthoredContentSpacing
          ? appHeaderCompactContentSpacingForOrientation(
                  MediaQuery.orientationOf(context),
                ) -
                kAppHeaderContentTopSpacing
          : 0.0;
      return AppHeaderScrollViewport(
        leadingInset: leadingInset,
        topExtension: topExtension,
        child: _AppHeaderNestedScrollView(
          contentController: controller,
          physics: physics,
          scrollBehavior: scrollBehavior,
          bodyBuilder: (nestedContext, phaseController) => CustomScrollView(
            key: _scrollViewKey,
            primary: true,
            physics: physics,
            scrollBehavior: scrollBehavior,
            cacheExtent: cacheExtent,
            paintOrder: paintOrder,
            slivers: [
              SliverOverlapInjector(
                handle: NestedScrollView.sliverOverlapAbsorberHandleFor(
                  nestedContext,
                ),
              ),
              if (maxContentTopSpacing > 0)
                SliverToBoxAdapter(
                  child: ListenableBuilder(
                    listenable: phaseController,
                    builder: (context, _) {
                      // Preserve the original expanded layout. Introduce the
                      // compact clearance as the final collapsible region
                      // closes: search when present, otherwise the title.
                      final progress = titleInset.searchBarExtent > 0
                          ? phaseController.searchBarCollapseProgress
                          : phaseController.collapseProgress;
                      final expandedTitleDownshift = titleCollapseExtent > 0
                          ? appHeaderExpandedTitleDownshiftForProgress(
                              phaseController.collapseProgress,
                            )
                          : 0.0;
                      final expandedTitleContentGapAdjustment =
                          !titleInset.pinSearchBar
                          ? AppHeaderScrollView
                                .expandedTitleContentGapAdjustment(
                                  desiredGap:
                                      titleInset.expandedTitleContentGap,
                                  existingSpacing: minimumContentTopSpacing,
                                  collapseProgress:
                                      phaseController.collapseProgress,
                                  topExtension: topExtension,
                                  baselineDescent:
                                      titleInset
                                              .expandedTitleContentGapFromBaseline
                                          ? AppHeaderScrollView
                                                .titleBaselineDescent
                                          : 0.0,
                                ) -
                                titleInset.expandedTitleContentGapContentInset *
                                    (1.0 -
                                        phaseController.collapseProgress)
                          : 0.0;
                      final compactContentTopSpacing =
                          titleInset.pinSearchBar
                          ? 0.0
                          : AppHeaderScrollView
                                .compactContentTopSpacingForProgress(
                                  compactSpacing:
                                      titleInset.compactContentTopSpacing +
                                      authoredCompactClearance,
                                  collapseProgress: progress,
                                );
                      return SizedBox(
                        height:
                            (minimumContentTopSpacing +
                                    maxContentTopSpacing * progress +
                                    compactContentTopSpacing +
                                    expandedTitleDownshift +
                                    expandedTitleContentGapAdjustment)
                                .clamp(0.0, double.infinity),
                      );
                    },
                  ),
                ),
              ...innerSlivers,
            ],
            semanticChildCount: semanticChildCount,
            dragStartBehavior: dragStartBehavior,
            keyboardDismissBehavior: keyboardDismissBehavior,
            restorationId: restorationId,
            hitTestBehavior: hitTestBehavior,
            clipBehavior: clipBehavior,
          ),
          leadingInset: leadingInset,
          titleCollapseExtent: titleCollapseExtent,
          titleInset: titleInset,
          expandedTitleContentGap:
              topExtension > 0 && !titleInset.pinSearchBar
              ? titleInset.expandedTitleContentGap
              : 0.0,
          topExtension: topExtension,
          sharedTitleTransition: sharedTitleTransition,
          mirrorSharedHeaderCollapse: mirrorSharedHeaderCollapse,
          initialHeaderOffset:
              (sharedTitleTransition?.collapseProgress ?? 0.0) *
              titleCollapseExtent,
          initialSearchOffset:
              (sharedTitleTransition?.searchBarCollapseProgress ?? 0.0) *
              titleInset.searchBarExtent,
        ),
      );
    }

    return AppHeaderScrollViewport(
      leadingInset: leadingInset,
      topExtension: topExtension,
      child: scrollView,
    );
  }
}

class _AppHeaderPositionRegistry extends ChangeNotifier {
  bool _notificationScheduled = false;

  void changed() {
    // Scroll positions can disappear during a Calendar morph's element
    // teardown. Publish the new registry after that locked layout phase.
    if (WidgetsBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      if (_notificationScheduled) return;
      _notificationScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _notificationScheduled = false;
        notifyListeners();
      });
      return;
    }
    notifyListeners();
  }
}

class _AppHeaderNestedScrollView extends StatefulWidget {
  const _AppHeaderNestedScrollView({
    required this.contentController,
    required this.physics,
    required this.scrollBehavior,
    required this.bodyBuilder,
    required this.leadingInset,
    required this.titleCollapseExtent,
    required this.titleInset,
    required this.expandedTitleContentGap,
    required this.topExtension,
    required this.sharedTitleTransition,
    required this.mirrorSharedHeaderCollapse,
    required this.initialHeaderOffset,
    required this.initialSearchOffset,
  });

  final ScrollController? contentController;
  final ScrollPhysics? physics;
  final ScrollBehavior? scrollBehavior;
  final Widget Function(BuildContext, GlassLargeTitleController) bodyBuilder;
  final double leadingInset;
  final double titleCollapseExtent;
  final AppHeaderScrollInset titleInset;
  final double expandedTitleContentGap;
  final double topExtension;
  final AppHeaderTitleTransition? sharedTitleTransition;
  final bool mirrorSharedHeaderCollapse;
  final double initialHeaderOffset;
  final double initialSearchOffset;

  @override
  State<_AppHeaderNestedScrollView> createState() =>
      _AppHeaderNestedScrollViewState();
}

class _AppHeaderNestedScrollViewState
    extends State<_AppHeaderNestedScrollView> {
  late final ScrollController _outerController;
  late final GlassLargeTitleController _searchPhaseController;
  final GlobalKey<NestedScrollViewState> _nestedKey = GlobalKey();
  ScrollPosition? _registeredPosition;
  final Set<ScrollPosition> _observedBodyPositions = {};
  final ValueNotifier<double> _bodyLeadingOverscroll = ValueNotifier(0.0);
  bool _initialBodyOffsetApplied = false;

  double get _titleExtent {
    final animation = widget.titleInset.collapseAnimation;
    final progress = animation?.value.clamp(0.0, 1.0) ?? 0.0;
    return widget.titleCollapseExtent * (1.0 - progress);
  }

  @override
  void initState() {
    super.initState();
    _searchPhaseController = GlassLargeTitleController();
    _outerController = ScrollController(
      initialScrollOffset:
          widget.initialHeaderOffset + widget.initialSearchOffset,
      onAttach: (position) {
        _searchPhaseController.scrollController.attach(position);
        _searchPhaseController.reportSearchBarHeight(
          widget.titleInset.searchBarExtent,
        );
        _searchPhaseController.reportMeasuredHeight(widget.titleCollapseExtent);
      },
      onDetach: (position) {
        if (_searchPhaseController.scrollController.positions.contains(position)) {
          _searchPhaseController.scrollController.detach(position);
        }
      },
    );
    widget.titleInset.collapseAnimation?.addListener(_handleTitleAnimation);
    if (widget.mirrorSharedHeaderCollapse) {
      widget.sharedTitleTransition?.addListener(
        _handleSharedTitleTransitionChange,
      );
    }
    _outerController.addListener(_syncRegisteredPosition);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _syncRegisteredPosition();
      _handleSharedTitleTransitionChange();
    });
  }

  @override
  void didUpdateWidget(_AppHeaderNestedScrollView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _searchPhaseController.reportSearchBarHeight(
      widget.titleInset.searchBarExtent,
    );
    if (oldWidget.contentController != widget.contentController) {
      _detachBodyObserver(oldWidget.contentController);
      AppHeaderScrollView._unregisterOuterPosition(
        oldWidget.contentController,
        _registeredPosition,
      );
      _registeredPosition = null;
    }
    if (oldWidget.titleInset.collapseAnimation !=
        widget.titleInset.collapseAnimation) {
      oldWidget.titleInset.collapseAnimation?.removeListener(
        _handleTitleAnimation,
      );
      widget.titleInset.collapseAnimation?.addListener(
        _handleTitleAnimation,
      );
    }
    if (oldWidget.mirrorSharedHeaderCollapse !=
            widget.mirrorSharedHeaderCollapse ||
        oldWidget.sharedTitleTransition != widget.sharedTitleTransition) {
      oldWidget.sharedTitleTransition?.removeListener(
        _handleSharedTitleTransitionChange,
      );
      if (widget.mirrorSharedHeaderCollapse) {
        widget.sharedTitleTransition?.addListener(
          _handleSharedTitleTransitionChange,
        );
      }
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _syncRegisteredPosition();
      _handleSharedTitleTransitionChange();
    });
  }

  void _handleTitleAnimation() {
    if (mounted) setState(() {});
  }

  void _handleSharedTitleTransitionChange() {
    if (!widget.mirrorSharedHeaderCollapse ||
        !_outerController.hasClients ||
        widget.titleCollapseExtent <= 0.0 ||
        !widget.titleCollapseExtent.isFinite) {
      return;
    }
    final transition = widget.sharedTitleTransition;
    if (transition == null) return;
    final position = _outerController.position;
    if (!position.hasContentDimensions) return;
    final progress = transition.collapseProgress;
    if (!progress.isFinite) return;
    final targetOffset = (progress.clamp(0.0, 1.0) *
            widget.titleCollapseExtent)
        .clamp(position.minScrollExtent, position.maxScrollExtent)
        .toDouble();
    if ((position.pixels - targetOffset).abs() <= 0.5) return;
    _outerController.jumpTo(targetOffset);
  }

  void _syncRegisteredPosition() {
    if (!_outerController.hasClients) return;
    final bodyController = widget.contentController;
    final nested = _nestedKey.currentState;
    if (nested != null) {
      final livePositions = nested.innerController.positions.toSet();
      for (final position in _observedBodyPositions.difference(livePositions)) {
        position.removeListener(_syncBodyLeadingOverscroll);
        if (bodyController?.positions.contains(position) ?? false) {
          bodyController!.detach(position);
        }
      }
      for (final position in livePositions.difference(_observedBodyPositions)) {
        bodyController?.attach(position);
        position.addListener(_syncBodyLeadingOverscroll);
      }
      _observedBodyPositions
        ..clear()
        ..addAll(livePositions);
      _syncBodyLeadingOverscroll();
    }
    final position = _outerController.position;
    if (!identical(position, _registeredPosition)) {
      AppHeaderScrollView._unregisterOuterPosition(
        widget.contentController,
        _registeredPosition,
      );
    }
    _registeredPosition = position;
    if (nested != null && nested.innerController.hasClients) {
      AppHeaderScrollView._registerOuterPosition(
        widget.contentController,
        position,
        bodyPosition: nested.innerController.position,
        searchBarExtent: widget.titleInset.searchBarExtent,
      );
      if (!_initialBodyOffsetApplied) {
        _initialBodyOffsetApplied = true;
        final savedOffset = widget.contentController?.initialScrollOffset ?? 0;
        final body = nested.innerController.position;
        if (widget.initialHeaderOffset >= widget.titleCollapseExtent &&
            savedOffset > 0 &&
            body.hasContentDimensions &&
            body.pixels == body.minScrollExtent) {
          body.jumpTo(savedOffset.clamp(
            body.minScrollExtent,
            body.maxScrollExtent,
          ).toDouble());
        }
      }
    }
  }

  void _detachBodyObserver(ScrollController? controller) {
    for (final position in _observedBodyPositions) {
      position.removeListener(_syncBodyLeadingOverscroll);
      if (controller?.positions.contains(position) ?? false) {
        controller!.detach(position);
      }
    }
    _observedBodyPositions.clear();
    _bodyLeadingOverscroll.value = 0.0;
  }

  void _syncBodyLeadingOverscroll() {
    var overscroll = 0.0;
    for (final position in _observedBodyPositions) {
      if (!position.hasContentDimensions) continue;
      final leadingOffset = position.pixels - position.minScrollExtent;
      if (leadingOffset < 0.0 && -leadingOffset > overscroll) {
        overscroll = -leadingOffset;
      }
    }
    if (_bodyLeadingOverscroll.value != overscroll) {
      _bodyLeadingOverscroll.value = overscroll;
    }
  }

  @override
  void dispose() {
    widget.titleInset.collapseAnimation?.removeListener(
      _handleTitleAnimation,
    );
    if (widget.mirrorSharedHeaderCollapse) {
      widget.sharedTitleTransition?.removeListener(
        _handleSharedTitleTransitionChange,
      );
    }
    AppHeaderScrollView._unregisterOuterPosition(
      widget.contentController,
      _registeredPosition,
    );
    _detachBodyObserver(widget.contentController);
    _outerController.removeListener(_syncRegisteredPosition);
    for (final position
        in _searchPhaseController.scrollController.positions.toList()) {
      _searchPhaseController.scrollController.detach(position);
    }
    _searchPhaseController.dispose();
    _outerController.dispose();
    _bodyLeadingOverscroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final extent = _titleExtent;
    final nestedView = NestedScrollView(
      key: _nestedKey,
      controller: _outerController,
      physics: widget.physics,
      headerSliverBuilder: (context, innerBoxIsScrolled) => [
        SliverOverlapAbsorber(
          handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
          sliver: SliverPersistentHeader(
            pinned: true,
            delegate: _AppHeaderCollapseSliverDelegate(
              extent: widget.leadingInset +
                  extent +
                  widget.titleInset.searchBarExtent,
              collapsedExtent: widget.leadingInset,
              largeTitle: widget.titleInset.child,
              titleExtent: extent,
              searchBar: widget.titleInset.searchBar,
              searchBarExtent: widget.titleInset.searchBarExtent,
              pinSearchBar: widget.titleInset.pinSearchBar,
              expandedTitleContentGap: widget.expandedTitleContentGap,
              expandedTitleContentGapFromBaseline:
                  widget.titleInset.expandedTitleContentGapFromBaseline,
              topExtension: widget.topExtension,
              bodyLeadingOverscroll: _bodyLeadingOverscroll,
              controller: _searchPhaseController,
            ),
          ),
        ),
      ],
      body: Builder(
        builder: (context) => widget.bodyBuilder(context, _searchPhaseController),
      ),
    );
    final behavior = widget.scrollBehavior;
    return behavior == null
        ? nestedView
        : ScrollConfiguration(behavior: behavior, child: nestedView);
  }
}

class _AppHeaderCollapseSliverDelegate extends SliverPersistentHeaderDelegate {
  const _AppHeaderCollapseSliverDelegate({
    required this.extent,
    this.collapsedExtent = 0,
    this.largeTitle,
    required this.titleExtent,
    required this.controller,
    required this.bodyLeadingOverscroll,
    this.searchBar,
    this.searchBarExtent = 0,
    this.pinSearchBar = false,
    this.expandedTitleContentGap = 0,
    this.expandedTitleContentGapFromBaseline = false,
    this.topExtension = 0,
  });

  final double extent;
  final double collapsedExtent;
  final Widget? largeTitle;
  final double titleExtent;
  final GlassLargeTitleController controller;
  final ValueNotifier<double> bodyLeadingOverscroll;
  final Widget? searchBar;
  final double searchBarExtent;
  final bool pinSearchBar;
  final double expandedTitleContentGap;
  final bool expandedTitleContentGapFromBaseline;
  final double topExtension;

  @override
  double get minExtent =>
      collapsedExtent + (pinSearchBar ? searchBarExtent : 0.0);

  @override
  double get maxExtent => extent;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) => ListenableBuilder(
      listenable: Listenable.merge([controller, bodyLeadingOverscroll]),
      builder: (context, _) {
        final rawOffset = controller.rawScrollOffset;
        final outerOverscroll = rawOffset.isFinite && rawOffset < 0.0
            ? -rawOffset
            : 0.0;
        final bodyOverscroll = bodyLeadingOverscroll.value;
        final searchBarStretchOffset = pinSearchBar
            ? 0.0
            : (bodyOverscroll > outerOverscroll
                  ? bodyOverscroll
                  : outerOverscroll);
        final searchBarCollapseProgress =
            controller.searchBarCollapseProgress;
        final searchBarSlot = Align(
          alignment: Alignment.topCenter,
          // Use GlassLargeTitle's package-controlled second phase.
          heightFactor: pinSearchBar
              ? 1.0
              : 1.0 - searchBarCollapseProgress,
          child: Opacity(
            opacity: pinSearchBar
                ? 1.0
                : Curves.easeIn.transform(1.0 - searchBarCollapseProgress),
            child: SizedBox(height: searchBarExtent, child: searchBar),
          ),
        );
        final searchBarViewport = pinSearchBar ||
                searchBarCollapseProgress > 0.0001
            ? ClipRect(child: searchBarSlot)
            : searchBarSlot;
        final expandedTitleDownshift = titleExtent > 0
            ? appHeaderExpandedTitleDownshiftForProgress(
                controller.collapseProgress,
              )
            : 0.0;
        final expandedTitleContentGapOffset = pinSearchBar
            ? 0.0
            : AppHeaderScrollView.expandedTitleContentGapAdjustment(
                desiredGap: expandedTitleContentGap,
                existingSpacing: 0.0,
                collapseProgress: controller.collapseProgress,
                baselineDescent: expandedTitleContentGapFromBaseline
                    ? AppHeaderScrollView.titleBaselineDescent
                    : 0.0,
              );
        return Stack(
          clipBehavior: Clip.none,
          children: [
            if (largeTitle != null) Positioned(
              top: collapsedExtent -
                  shrinkOffset.clamp(0.0, titleExtent) +
                  expandedTitleDownshift,
              left: 0,
              right: 0,
              height: titleExtent,
              child: largeTitle!,
            ),
            if (searchBar != null) Positioned(
              top: collapsedExtent +
                  (titleExtent - shrinkOffset).clamp(0.0, titleExtent) +
                  expandedTitleDownshift +
                  expandedTitleContentGapOffset,
              left: 0,
              right: 0,
              child: Transform.translate(
                // The search bar is painted in the pinned outer header, while
                // the content below rubber-bands with the inner body scroll
                // position. Follow that top pull (or the package controller's
                // outer pull) without changing any collapse geometry.
                offset: Offset(0.0, searchBarStretchOffset),
                child: searchBarViewport,
              ),
            ),
          ],
        );
      },
    );

  @override
  bool shouldRebuild(_AppHeaderCollapseSliverDelegate oldDelegate) =>
      extent != oldDelegate.extent ||
      collapsedExtent != oldDelegate.collapsedExtent ||
      largeTitle != oldDelegate.largeTitle ||
      titleExtent != oldDelegate.titleExtent ||
      searchBar != oldDelegate.searchBar ||
      searchBarExtent != oldDelegate.searchBarExtent ||
      pinSearchBar != oldDelegate.pinSearchBar ||
      expandedTitleContentGap != oldDelegate.expandedTitleContentGap ||
      expandedTitleContentGapFromBaseline !=
          oldDelegate.expandedTitleContentGapFromBaseline ||
      topExtension != oldDelegate.topExtension ||
      controller != oldDelegate.controller;
}

/// A page-level stack that lets scroll content paint up behind the app header.
///
/// The full-screen AppShell remains the physical viewport clip. Do not put a
/// hard clip around a page-sized stack below the header, or it will cut off
/// scrolling content at that internal boundary before the glass overlay.
class AppHeaderScrollStack extends Stack {
  const AppHeaderScrollStack({
    super.key,
    super.alignment = AlignmentDirectional.topStart,
    super.textDirection,
    super.fit = StackFit.loose,
    super.children,
  }) : super(clipBehavior: Clip.none);
}

/// Declares existing leading content spacing, reused by the shared boundary.
/// Outside that boundary (for example landscape), retain the authored inset.
class AppHeaderContentSpacing extends StatelessWidget {
  const AppHeaderContentSpacing({
    super.key,
    this.visibleContentTopInset = 0.0,
  }) : assert(visibleContentTopInset >= 0.0);

  /// Removes the line-box space above a first element's visible glyphs when
  /// the requested gap is measured to the glyph rather than its row box.
  final double visibleContentTopInset;

  @override
  Widget build(BuildContext context) {
    final hasSharedHeader =
        AppHeaderScrollInsetScope.maybeOf(context) > 0.0;
    final spacing = hasSharedHeader
        ? appHeaderCompactContentSpacingForOrientation(
            MediaQuery.orientationOf(context),
          )
        : kAppHeaderContentTopSpacing;
    return SizedBox(
      height: (spacing - visibleContentTopInset)
          .clamp(0.0, double.infinity)
          .toDouble(),
    );
  }
}

/// Declares the page's collapsible title region.
///
/// AppHeaderScrollView lifts this declaration into its outer persistent-header
/// sliver. It is not retained as hidden body padding after collapse. A plain
/// scroll view without the shared header scope can still lay out this widget.
class AppHeaderScrollInset extends StatelessWidget {
  const AppHeaderScrollInset({
    super.key,
    this.collapseAnimation,
    this.enabled = true,
    this.child,
    this.searchBar,
    this.searchBarExtent = 0,
    this.pinSearchBar = false,
    this.expandedTitleContentGap = 0,
    this.expandedTitleContentGapFromBaseline = false,
    this.expandedTitleContentGapContentInset = 0.0,
    this.compactContentTopSpacing = 0.0,
  }) : assert(searchBarExtent >= 0),
       assert(expandedTitleContentGap >= 0),
       assert(expandedTitleContentGapContentInset >= 0),
       assert(compactContentTopSpacing >= 0),
       assert(searchBar != null || searchBarExtent == 0);

  final Animation<double>? collapseAnimation;
  final bool enabled;
  final Widget? child;
  /// Optional third header level; the package collapses it after the title.
  final Widget? searchBar;
  final double searchBarExtent;
  /// Keeps the search row pinned and stationary during inline search.
  final bool pinSearchBar;
  /// Desired expanded-state distance between the large title baseline (when
  /// [expandedTitleContentGapFromBaseline] is true) or text bottom and the
  /// first content item. Zero preserves legacy layout.
  final double expandedTitleContentGap;
  /// Measure the desired gap from the title baseline instead of its text box.
  final bool expandedTitleContentGapFromBaseline;
  /// Distance from the first content box's top to the visible edge being
  /// aligned (for example, a text line's top inside a fixed-height row).
  final double expandedTitleContentGapContentInset;
  /// Extra content inset restored only as the search header reaches compact.
  final double compactContentTopSpacing;

  @override
  Widget build(BuildContext context) {
    final animation = collapseAnimation;
    if (!enabled) return const SizedBox.shrink();
    if (animation == null) {
      return Column(mainAxisSize: MainAxisSize.min, children: [
        SizedBox(height: kAppHeaderTitleHeight, child: child),
        if (searchBar != null)
          SizedBox(height: searchBarExtent, child: searchBar),
      ]);
    }

    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final searchExpanded = (1 - animation.value.clamp(0.0, 1.0)).toDouble();
        return Column(mainAxisSize: MainAxisSize.min, children: [
          SizedBox(
            height: kAppHeaderTitleHeight * searchExpanded,
            child: child,
          ),
          if (searchBar != null)
            SizedBox(height: searchBarExtent, child: searchBar),
        ]);
      },
    );
  }
}

/// Keeps the compact title in the first-level toolbar. In portrait it begins
/// fading in only after its large-title counterpart is fully invisible.
class AppHeaderCompactTitle extends StatelessWidget {
  const AppHeaderCompactTitle({
    super.key,
    required this.progress,
    required this.isLandscape,
    required this.child,
  });

  final double progress;
  final bool isLandscape;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final visibleProgress = isLandscape
        ? 1.0
        : (progress.isFinite ? progress.clamp(0.0, 1.0).toDouble() : 0.0);
    return IgnorePointer(
      // Keep the compact title's controls from intercepting taps while they
      // are still mostly transparent during the scroll handoff.
      ignoring: !isLandscape && visibleProgress < 0.5,
      child: Opacity(opacity: visibleProgress, child: child),
    );
  }
}

/// Fades the outgoing large title before [AppHeaderCompactTitle] begins to
/// appear and hands pointer interaction away once the large title is mostly
/// faded.
class AppHeaderLargeTitleHandoff extends StatelessWidget {
  const AppHeaderLargeTitleHandoff({
    super.key,
    required this.progress,
    required this.child,
    this.expandedDownshift = 0.0,
  });

  final double progress;
  final Widget child;
  /// Moves the title within an equally enlarged hit-test box. This avoids
  /// painting an interactive title outside the fixed handoff bounds.
  final double expandedDownshift;

  @override
  Widget build(BuildContext context) {
    final visibleProgress = progress.isFinite
        ? progress.clamp(0.0, 1.0).toDouble()
        : 0.0;
    final downshift = expandedDownshift.isFinite && expandedDownshift > 0.0
        ? expandedDownshift
        : 0.0;
    final handedOffChild = downshift == 0.0
        ? child
        : Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                top: downshift,
                left: 0,
                right: 0,
                bottom: 0,
                child: child,
              ),
            ],
          );
    return IgnorePointer(
      ignoring: visibleProgress >= 0.5,
      child: Opacity(
        opacity: 1.0 - visibleProgress,
        child: handedOffChild,
      ),
    );
  }
}

/// The shared Liquid Glass treatment for the first, pinned header level only.
/// Its height is the physical top inset plus the toolbar; title and page
/// content are blurred only while they pass through that bounded region. A
/// persistent background gradient keeps the physical top edge covered. This
/// is a visual sibling overlay: its local filter clip bounds only the glass
/// effect, never the scrollable content.
class AppHeaderScrollEdge extends StatelessWidget {
  const AppHeaderScrollEdge({
    super.key,
    required this.progress,
    required this.surfaceColor,
    required this.headerHeight,
    required this.backgroundGradientHeight,
  });

  final double progress;
  final Color surfaceColor;
  final double headerHeight;
  final double backgroundGradientHeight;

  @override
  Widget build(BuildContext context) {
    final normalizedProgress = progress.clamp(0.0, 1.0).toDouble();
    final effectProgress = Curves.easeOutCubic.transform(normalizedProgress);
    if (headerHeight <= 0) {
      return const SizedBox.shrink();
    }

    final gradientHeight = backgroundGradientHeight
        .clamp(0.0, headerHeight)
        .toDouble();

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      // Start at the physical top of the screen and extend 16pt past the
      // bottom of the complete first-level header.
      height: headerHeight + kAppHeaderScrollEdgeHeaderBottomExtension,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Offstage(
            offstage: normalizedProgress <= 0.01,
            child: IgnorePointer(
              child: LiquidGlassScrollEdge(
                edge: LiquidGlassEdge.top,
                color: surfaceColor.withValues(
                  // Keep the shared app-level edge translucent while applying
                  // blur as content passes beneath the pinned header.
                  // The edge remains a compositing treatment, never a
                  // visibility threshold.
                  alpha:
                      (_kAppHeaderScrollEdgeMaxTintOpacity *
                              effectProgress *
                              surfaceColor.a)
                          .clamp(0.0, 1.0)
                          .toDouble(),
                ),
                // Hold most of the glass strength across the scroll interval,
                // then ease it away near the end instead of fading linearly.
                blur: effectProgress > 0
                    ? _kAppHeaderScrollEdgeMaxBlurSigma * effectProgress
                    : 0.001,
              ),
            ),
          ),
          if (gradientHeight > 0)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: gradientHeight,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        surfaceColor.withValues(alpha: 1.0),
                        surfaceColor.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

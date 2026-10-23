import 'package:flutter/gestures.dart' show DragStartBehavior;
import 'package:flutter/widgets.dart';
import 'package:flutter_liquid_glass_widgets/liquid_glass_widgets.dart'
    show GlassLargeTitleController;
import 'package:liquid_glass_easy/liquid_glass_easy.dart'
    show LiquidGlassEdge, LiquidGlassScrollEdge;

const double kAppHeaderToolbarHeight = 44;
const double kAppHeaderTitleHeight = 57;
const double kAppHeaderTitleCollapseDistance = kAppHeaderTitleHeight;
const double kAppHeaderScrollEdgeHeaderBottomExtension = 16;
const double _kAppHeaderScrollEdgeMaxTintOpacity = 0.24;
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

/// Bridges the package's established large-title collapse controller to the
/// app's existing ScrollPosition.
///
/// The package controller normally owns the ScrollController attached to its
/// GlassLargeTitle sliver. SKEDDO already has persistent, screen-specific
/// scrollables, so this adapter attaches the package's controller to the active
/// existing position instead of introducing another scroll view or offset.
class AppHeaderTitleTransition extends ChangeNotifier {
  AppHeaderTitleTransition() : _controller = GlassLargeTitleController() {
    _controller.addListener(_forwardControllerChange);
  }

  GlassLargeTitleController _controller;
  ScrollPosition? _position;
  double _cachedContentOffset = 0.0;
  double _lastNotifiedContentOffset = 0.0;
  double _lastNotifiedCollapseProgress = 0.0;
  bool _isBinding = false;

  ScrollPosition? get position => _position;
  double get collapseProgress => _controller.collapseProgress;
  double get rawScrollOffset => _controller.rawScrollOffset;

  double get contentOffset {
    final currentPosition = _position;
    if (currentPosition == null || !currentPosition.hasContentDimensions) {
      return _cachedContentOffset;
    }
    _cachedContentOffset = AppHeaderScrollBehavior.contentOffset(
      currentPosition,
    );
    return _cachedContentOffset;
  }

  /// Binds to the single active scroll position. Recreating the package
  /// controller on handoff makes it recalculate from that position immediately.
  void bindTo(ScrollPosition? position) {
    if (identical(position, _position)) return;

    if (_position != null) contentOffset;
    final oldPosition = _position;
    _isBinding = true;
    _controller.removeListener(_forwardControllerChange);
    if (oldPosition != null) {
      oldPosition.removeListener(_handlePositionChanged);
      _controller.scrollController.detach(oldPosition);
    }
    _controller.dispose();

    _position = position;
    if (position == null) _cachedContentOffset = 0.0;
    _controller = GlassLargeTitleController()
      ..addListener(_forwardControllerChange);
    if (position != null) {
      _controller.scrollController.attach(position);
      position.addListener(_handlePositionChanged);
      // GlassLargeTitle reports the measured title row from layout. The
      // existing shell reserves a fixed title slot, so use that exact geometry.
      _controller.reportMeasuredHeight(kAppHeaderTitleCollapseDistance);
    }
    _lastNotifiedContentOffset = contentOffset;
    _lastNotifiedCollapseProgress = collapseProgress;
    _isBinding = false;
    notifyListeners();
  }

  /// Stops observing scroll changes while a search transition owns the header,
  /// without changing the current visual state.
  void suspend() {
    final position = _position;
    if (position == null) return;
    contentOffset;
    position.removeListener(_handlePositionChanged);
    _controller.scrollController.detach(position);
    _position = null;
  }

  void _forwardControllerChange() {
    _notifyIfChanged();
  }

  /// The package controller intentionally stops notifying once its normalized
  /// collapse progress reaches 1.0. The shell still needs the same position's
  /// full offset for title travel and LiquidGlassScrollEdge progress, so listen
  /// to the active ScrollPosition as well. This is not a second scroll source:
  /// both values are read from the exact position attached to the package
  /// controller.
  void _handlePositionChanged() {
    _notifyIfChanged();
  }

  void _notifyIfChanged() {
    if (_isBinding) return;
    final currentContentOffset = contentOffset;
    final currentCollapseProgress = collapseProgress;
    if (currentContentOffset == _lastNotifiedContentOffset &&
        currentCollapseProgress == _lastNotifiedCollapseProgress) {
      return;
    }
    _lastNotifiedContentOffset = currentContentOffset;
    _lastNotifiedCollapseProgress = currentCollapseProgress;
    notifyListeners();
  }

  @override
  void dispose() {
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
  });

  final Widget child;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    if (!enabled || MediaQuery.orientationOf(context) != Orientation.portrait) {
      return child;
    }

    final position = Scrollable.maybeOf(context)?.position;
    if (position == null) return child;

    return AnimatedBuilder(
      animation: position,
      builder: (context, _) {
        if (!position.hasContentDimensions) return child;
        final contentOffset = AppHeaderScrollBehavior.contentOffset(position);
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
    if (scrollController == null) return child;

    // Resolve the Scrollable that actually contains this title. Some calendar
    // modes intentionally share one controller with an embedded list, so the
    // controller can have multiple positions even though this title belongs to
    // exactly one of them.
    final owningPosition = Scrollable.maybeOf(context)?.position;
    final positionListenable = owningPosition ?? scrollController;
    return AnimatedBuilder(
      animation: positionListenable,
      builder: (context, _) {
        final positions = scrollController.positions;
        final position =
            owningPosition ?? (positions.length == 1 ? positions.single : null);
        if (position == null) return child;
        if (!position.hasContentDimensions) return child;
        final positionOffset = AppHeaderScrollBehavior.contentOffset(position);
        final collapseProgress = AppHeaderScrollBehavior.titleCollapseProgress(
          positionOffset,
        );
        final fadeProgress =
            AppHeaderScrollBehavior.packageLargeTitleFadeProgress(
              collapseProgress,
            );
        final correction = AppHeaderScrollBehavior.leadingOverscrollCorrection(
          position,
        );
        final title = AppHeaderLargeTitleHandoff(
          progress: fadeProgress,
          child: child,
        );
        if (correction == 0.0) return title;
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
    required super.child,
  });

  final double leadingInset;
  /// The measured scroll distance needed to move the expanded title region
  /// out of the usable viewport and reach the compact header.
  final double titleCollapseExtent;

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
      titleCollapseExtent != oldWidget.titleCollapseExtent;
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

  @override
  Widget build(BuildContext context) {
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
      if (titleCollapseExtent > 0.0)
        // A short page still needs enough real scroll extent to move the
        // expanded title slot out of the viewport. Fill only the measured
        // deficit after laying out the page; long content receives no extra
        // trailing space.
        SliverLayoutBuilder(
          builder: (context, constraints) {
            final requiredScrollExtent =
                constraints.viewportMainAxisExtent + titleCollapseExtent;
            final missingExtent =
                requiredScrollExtent - constraints.precedingScrollExtent;
            final trailingExtent =
                missingExtent.isFinite && missingExtent > 0.0
                ? missingExtent
                : 0.0;
            return SliverToBoxAdapter(
              child: SizedBox(height: trailingExtent),
            );
          },
        ),
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

    return AppHeaderScrollViewport(
      leadingInset: leadingInset,
      topExtension: topExtension,
      child: scrollView,
    );
  }
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

/// Keeps a fixed large-title slot in the page's scroll extent while the title
/// itself is painted in the AppShell header above the scrolling content. The
/// content's own scroll position—not the shell title's settle animation—
/// determines when that content moves behind the first-level header.
class AppHeaderScrollInset extends StatelessWidget {
  const AppHeaderScrollInset({
    super.key,
    this.collapseAnimation,
    this.enabled = true,
  });

  final Animation<double>? collapseAnimation;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final animation = collapseAnimation;
    if (!enabled) return const SizedBox.shrink();
    if (animation == null) {
      return const SizedBox(height: kAppHeaderTitleHeight);
    }

    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final searchExpanded = (1 - animation.value.clamp(0.0, 1.0)).toDouble();
        return SizedBox(height: kAppHeaderTitleHeight * searchExpanded);
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
  });

  final double progress;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final visibleProgress = progress.isFinite
        ? progress.clamp(0.0, 1.0).toDouble()
        : 0.0;
    return IgnorePointer(
      ignoring: visibleProgress >= 0.5,
      child: Opacity(opacity: 1.0 - visibleProgress, child: child),
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

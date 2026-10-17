import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/rendering.dart';

import '../app_theme.dart';
import '../services/window_geometry_diagnostics.dart';

const double kAppWindowMasterDetailDividerWidth = 0.75;
const double kAppWindowMasterDetailMinimumDetailWidth = 320.0;

/// Publishes the app-wide content rectangle inside the physical window.
///
/// This widget intentionally does not add visual surfaces or constrain the
/// Navigator itself. Full-width app surfaces must be allowed to paint through
/// the system area; widgets that contain actual UI elements use
/// [AppWindowContentPadding] below to apply the positioning constraint.
class AppWindowContentBoundary extends StatelessWidget {
  const AppWindowContentBoundary({super.key, required this.child});

  final Widget child;

  /// Returns the symmetric landscape reservation from the persistent platform
  /// safe area.
  ///
  /// This intentionally uses only [MediaQueryData.viewPadding]. It represents
  /// the platform safe area for the physical window and is independent of the
  /// keyboard. Gesture, tappable-element, and descendant [padding] insets are
  /// separate concepts and must not widen this app-wide reservation.
  static double landscapeSystemInsetFor(MediaQueryData mediaQuery) {
    if (mediaQuery.size.width <= mediaQuery.size.height) return 0.0;

    return math.max(mediaQuery.viewPadding.left, mediaQuery.viewPadding.right);
  }

  @override
  Widget build(BuildContext context) {
    WindowGeometryDiagnostics.report(context);
    final mediaQuery = MediaQuery.of(context);
    // Read the persistent platform inset from MediaQuery.viewPadding. Do not
    // use padding (which can be rewritten by a route or affected by the IME),
    // viewInsets (keyboard), or gesture insets for this reservation.
    final viewPadding = MediaQuery.viewPaddingOf(context);
    final horizontalInset = landscapeSystemInsetFor(
      mediaQuery.copyWith(viewPadding: viewPadding),
    );

    final contentMediaQuery = horizontalInset <= 0.0
        ? mediaQuery
        : mediaQuery.copyWith(
            size: Size(
              math.max(0.0, mediaQuery.size.width - horizontalInset * 2.0),
              mediaQuery.size.height,
            ),
            // The shared boundary owns the horizontal system space. Clearing
            // these fields prevents SafeArea or a nested route from adding the
            // same inset a second time inside the reserved content rectangle.
            padding: mediaQuery.padding.copyWith(left: 0.0, right: 0.0),
            viewPadding: mediaQuery.viewPadding.copyWith(left: 0.0, right: 0.0),
            systemGestureInsets: mediaQuery.systemGestureInsets.copyWith(
              left: 0.0,
              right: 0.0,
            ),
          );

    // Keep the Navigator subtree at the same element-tree depth in portrait
    // and landscape. Conditionally adding/removing MediaQuery here reparents
    // the whole app and disposes active routes, including unsaved sheet forms.
    return AppWindowContentScope(
      horizontalInset: horizontalInset,
      physicalWidth: mediaQuery.size.width,
      child: MediaQuery(data: contentMediaQuery, child: child),
    );
  }
}

/// Applies the centralized horizontal content positioning constraint without
/// constraining a full-width surface that sits above or below it.
class AppWindowContentPadding extends StatelessWidget {
  const AppWindowContentPadding({
    super.key,
    required this.child,
    this.includeLeft = true,
    this.includeRight = true,
  });

  final Widget child;
  final bool includeLeft;
  final bool includeRight;

  @override
  Widget build(BuildContext context) {
    final inset = AppWindowContentScope.of(context).horizontalInset;
    final mediaQuery = MediaQuery.of(context);
    final contentMediaQuery = inset <= 0.0
        ? mediaQuery
        : mediaQuery.copyWith(
            // This child is already positioned inside the app-wide symmetric
            // landscape boundary. Do not let a nested SafeArea re-apply the
            // platform's original one-sided horizontal inset.
            padding: mediaQuery.padding.copyWith(left: 0.0, right: 0.0),
            viewPadding: mediaQuery.viewPadding.copyWith(left: 0.0, right: 0.0),
            systemGestureInsets: mediaQuery.systemGestureInsets.copyWith(
              left: 0.0,
              right: 0.0,
            ),
          );

    // Keep the child in the same position in the element tree as the inset
    // changes. In particular, modal form state must survive portrait/landscape
    // transitions even when the platform reports a landscape safe-area inset.
    return Padding(
      padding: EdgeInsets.only(
        left: includeLeft ? inset : 0.0,
        right: includeRight ? inset : 0.0,
      ),
      child: MediaQuery(data: contentMediaQuery, child: child),
    );
  }
}

/// Applies the shared landscape system inset inside a width-constrained pane
/// and gives descendants a MediaQuery size that reflects that pane's usable
/// width rather than the full app window.
///
/// Use this around responsive content inside a split pane. The normal
/// [AppWindowContentPadding] positions content against the app-wide safe area,
/// but intentionally leaves MediaQuery.size describing the app window for
/// full-window transitions and overlays.
class AppWindowPaneContent extends StatelessWidget {
  const AppWindowPaneContent({
    super.key,
    required this.child,
    this.includeLeft = true,
    this.includeRight = true,
    this.additionalRightInset = 0.0,
  });

  final Widget child;
  final bool includeLeft;
  final bool includeRight;

  /// Extra temporary space on the pane's right edge, such as the safe-area
  /// clearance that shrinks during a split transition.
  final double additionalRightInset;

  @override
  Widget build(BuildContext context) {
    final scope = AppWindowContentScope.of(context);
    final inset = scope.horizontalInset;
    final mediaQuery = MediaQuery.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final paneWidth =
            constraints.hasBoundedWidth
                ? constraints.maxWidth
                : mediaQuery.size.width;
        final leftInset = includeLeft ? inset : 0.0;
        final rightInset = (includeRight ? inset : 0.0) + additionalRightInset;
        final contentWidth = math.max(
          0.0,
          paneWidth - leftInset - rightInset,
        );

        final paneMediaQuery = inset <= 0.0
            ? mediaQuery.copyWith(
                size: Size(contentWidth, mediaQuery.size.height),
              )
            : mediaQuery.copyWith(
                size: Size(contentWidth, mediaQuery.size.height),
                padding: mediaQuery.padding.copyWith(left: 0.0, right: 0.0),
                viewPadding: mediaQuery.viewPadding.copyWith(
                  left: 0.0,
                  right: 0.0,
                ),
                systemGestureInsets: mediaQuery.systemGestureInsets.copyWith(
                  left: 0.0,
                  right: 0.0,
                ),
              );

        return Padding(
          padding: EdgeInsets.only(
            left: leftInset,
            right: rightInset,
          ),
          child: MediaQuery(data: paneMediaQuery, child: child),
        );
      },
    );
  }
}

/// Shared portrait-width master and remaining-width detail geometry for
/// landscape split layouts.
class AppWindowMasterDetailGeometry {
  const AppWindowMasterDetailGeometry({
    required this.isLandscape,
    required this.physicalWidth,
    required this.horizontalInset,
    required this.portraitShortEdgeWidth,
    required this.masterPaneWidth,
    required this.masterContentWidth,
    required this.detailPaneWidth,
    required this.detailContentWidth,
  });

  final bool isLandscape;
  final double physicalWidth;
  final double horizontalInset;
  final double portraitShortEdgeWidth;
  final double masterPaneWidth;
  final double masterContentWidth;
  final double detailPaneWidth;
  final double detailContentWidth;

  /// Horizontal offset from the full-window center to the center of the
  /// portrait-width master content, for centered overlays such as the tab bar.
  ///
  /// The inset is only the content's physical origin. It is not part of the
  /// portrait content width used to find its center.
  double get masterContentCenterOffset =>
      horizontalInset + (masterContentWidth - physicalWidth) / 2;

  double masterPaneWidthAt(double progress) {
    final t = progress.clamp(0.0, 1.0).toDouble();
    return physicalWidth + (masterPaneWidth - physicalWidth) * t;
  }

  double dividerWidthAt(double progress) =>
      kAppWindowMasterDetailDividerWidth *
      progress.clamp(0.0, 1.0).toDouble();

  double detailPaneWidthAt(double progress) =>
      math.max(0.0, physicalWidth - masterPaneWidthAt(progress) - dividerWidthAt(progress));

  double masterContentWidthAt(double progress) {
    final t = progress.clamp(0.0, 1.0).toDouble();
    return math.max(
      0.0,
      masterPaneWidthAt(t) - horizontalInset - horizontalInset * (1.0 - t),
    );
  }

  double detailContentWidthAt(double progress) =>
      math.max(0.0, detailPaneWidthAt(progress) - horizontalInset);

  static AppWindowMasterDetailGeometry of(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final scope = AppWindowContentScope.of(context);
    final display = View.maybeOf(context)?.display;
    final pixelRatio =
        display?.devicePixelRatio ?? mediaQuery.devicePixelRatio;
    final portraitShortEdgeWidth = display == null
        ? math.min(scope.physicalWidth, mediaQuery.size.height)
        : display.size.shortestSide / pixelRatio;
    final masterPaneWidth = math.min(
      scope.physicalWidth,
      portraitShortEdgeWidth + scope.horizontalInset,
    );
    final masterContentWidth = math.max(
      0.0,
      masterPaneWidth - scope.horizontalInset,
    );
    final detailPaneWidth = math.max(
      0.0,
      scope.physicalWidth -
          masterPaneWidth -
          kAppWindowMasterDetailDividerWidth,
    );
    final detailContentWidth = math.max(
      0.0,
      detailPaneWidth - scope.horizontalInset,
    );

    return AppWindowMasterDetailGeometry(
      isLandscape: scope.physicalWidth > mediaQuery.size.height,
      physicalWidth: scope.physicalWidth,
      horizontalInset: scope.horizontalInset,
      portraitShortEdgeWidth: portraitShortEdgeWidth,
      masterPaneWidth: masterPaneWidth,
      masterContentWidth: masterContentWidth,
      detailPaneWidth: detailPaneWidth,
      detailContentWidth: detailContentWidth,
    );
  }
}

/// Exposes the pane transition's live eased progress to master-pane content.
///
/// Layouts that change shape while the master narrows can interpolate their
/// own measurements against these same endpoints instead of starting a second
/// implicit animation that lags behind the pane.
class AppWindowMasterDetailProgressScope
    extends InheritedNotifier<Animation<double>> {
  const AppWindowMasterDetailProgressScope({
    super.key,
    required this.geometry,
    required Animation<double> progress,
    required super.child,
  }) : super(notifier: progress);

  final AppWindowMasterDetailGeometry geometry;

  double get value => notifier?.value.clamp(0.0, 1.0).toDouble() ?? 0.0;

  bool get isAnimating {
    final status = notifier?.status;
    return status == AnimationStatus.forward ||
        status == AnimationStatus.reverse;
  }

  double get fullMasterContentWidth => geometry.masterContentWidthAt(0.0);

  double get compactMasterContentWidth => geometry.masterContentWidthAt(1.0);

  /// Maps a width measured in the current master pane to either endpoint while
  /// preserving any fixed child insets (for example a card's 16px margins).
  double widthAtEndpoint(double currentWidth, {required bool compact}) {
    final endpoint = compact
        ? compactMasterContentWidth
        : fullMasterContentWidth;
    return math.max(
      0.0,
      currentWidth + endpoint - geometry.masterContentWidthAt(value),
    );
  }

  static AppWindowMasterDetailProgressScope? maybeOf(
    BuildContext context,
  ) => context.dependOnInheritedWidgetOfExactType<
    AppWindowMasterDetailProgressScope
  >();

  @override
  bool updateShouldNotify(
    covariant AppWindowMasterDetailProgressScope oldWidget,
  ) {
    final geometryChanged =
        geometry.isLandscape != oldWidget.geometry.isLandscape ||
        geometry.physicalWidth != oldWidget.geometry.physicalWidth ||
        geometry.horizontalInset != oldWidget.geometry.horizontalInset ||
        geometry.portraitShortEdgeWidth !=
            oldWidget.geometry.portraitShortEdgeWidth ||
        geometry.masterPaneWidth != oldWidget.geometry.masterPaneWidth ||
        geometry.masterContentWidth != oldWidget.geometry.masterContentWidth ||
        geometry.detailPaneWidth != oldWidget.geometry.detailPaneWidth ||
        geometry.detailContentWidth != oldWidget.geometry.detailContentWidth;
    return geometryChanged || super.updateShouldNotify(oldWidget);
  }
}

/// Reusable full-width-to-master/detail transition for landscape navigation.
///
/// The master shrinks to the shared portrait-width target while the detail
/// enters from the physical right edge. Safe-area-aware callers can use the
/// default pane insets; callers that already inset their contents can disable
/// them. [focusAnchorContext] or [focusAnchorKey] keeps the item that opened
/// the detail pane visible if the master changes width would otherwise obscure it.
class AppWindowMasterDetailTransition extends StatefulWidget {
  const AppWindowMasterDetailTransition({
    super.key,
    required this.geometry,
    required this.progress,
    required this.master,
    required this.detail,
    required this.dividerColor,
    this.applyPaneInsets = true,
    this.applyDetailPaneInsets = true,
    this.drawDivider = true,
    this.focusAnchorContext,
    this.focusAnchorKey,
    this.scrollAnchorKeys = const [],
    this.focusRevealDuration = const Duration(milliseconds: 180),
    this.focusAvoidTabBar = true,
  });

  final AppWindowMasterDetailGeometry geometry;
  final Animation<double> progress;
  final Widget master;
  final Widget detail;
  final Color dividerColor;
  final bool applyPaneInsets;
  final bool applyDetailPaneInsets;
  final bool drawDivider;
  final BuildContext? focusAnchorContext;
  final GlobalKey? focusAnchorKey;
  final List<GlobalKey> scrollAnchorKeys;
  final Duration focusRevealDuration;
  final bool focusAvoidTabBar;

  @override
  State<AppWindowMasterDetailTransition> createState() =>
      _AppWindowMasterDetailTransitionState();
}

class AppWindowFocusAnchorScrollTarget {
  const AppWindowFocusAnchorScrollTarget({
    required this.position,
    required this.offset,
  });

  final ScrollPosition position;
  final double offset;
}

/// Returns the smallest vertical scroll adjustment needed to keep an anchor
/// inside its actual viewport and, optionally, above the floating tab bar.
AppWindowFocusAnchorScrollTarget? appWindowFocusAnchorScrollTarget({
  required BuildContext anchorContext,
  required BuildContext viewportContext,
  required bool avoidTabBar,
}) {
  if (!anchorContext.mounted || !viewportContext.mounted) return null;
  final scrollable = Scrollable.maybeOf(anchorContext);
  if (scrollable == null) return null;
  final position = scrollable.position;
  if (!position.hasPixels || !position.hasContentDimensions) return null;
  if (position.axisDirection != AxisDirection.down &&
      position.axisDirection != AxisDirection.up) {
    return null;
  }

  final anchorRenderObject = anchorContext.findRenderObject();
  if (anchorRenderObject is! RenderBox || !anchorRenderObject.attached) {
    return null;
  }
  final viewport = RenderAbstractViewport.maybeOf(anchorRenderObject);
  if (viewport == null || viewport is! RenderBox) return null;
  final viewportBox = viewport as RenderBox;
  if (!viewportBox.attached) return null;

  final anchorRect =
      anchorRenderObject.localToGlobal(Offset.zero) & anchorRenderObject.size;
  final viewportRect =
      viewportBox.localToGlobal(Offset.zero) & viewportBox.size;
  final visibleBottom = avoidTabBar
      ? math.min(
          viewportRect.bottom,
          MediaQuery.sizeOf(viewportContext).height -
              floatingTabBarContentBottomClearance(viewportContext),
        )
      : viewportRect.bottom;
  final visibleHeight = visibleBottom - viewportRect.top;
  if (visibleHeight <= 0) return null;

  final topOverflow = math.max(0.0, viewportRect.top - anchorRect.top);
  final bottomOverflow = math.max(0.0, anchorRect.bottom - visibleBottom);
  if (topOverflow <= 1.0 && bottomOverflow <= 1.0) return null;

  final isDown = position.axisDirection == AxisDirection.down;
  final offsetDelta = anchorRect.height > visibleHeight
      // An unusually tall item cannot fit in the available region. Align its
      // leading edge when needed so the greatest possible portion stays visible.
      ? (isDown ? -topOverflow : topOverflow)
      : (isDown
            ? bottomOverflow - topOverflow
            : topOverflow - bottomOverflow);
  final targetOffset = (position.pixels + offsetDelta)
      .clamp(position.minScrollExtent, position.maxScrollExtent)
      .toDouble();
  if ((targetOffset - position.pixels).abs() <= 0.5) return null;

  return AppWindowFocusAnchorScrollTarget(
    position: position,
    offset: targetOffset,
  );
}

class _AppWindowMasterDetailTransitionState
    extends State<AppWindowMasterDetailTransition> {
  bool _focusAnchorSyncScheduled = false;
  bool _focusAnchorSyncSuppressed = false;
  bool _focusAnchorCorrectionInFlight = false;
  bool _focusPaneTransitionInProgress = false;
  GlobalKey? _visualScrollAnchorKey;
  ScrollPosition? _visualScrollAnchorPosition;
  double? _visualScrollAnchorTop;
  double? _focusPaneTransitionEndProgress;
  double? _focusCorrectionSegmentStartOffset;
  double? _focusCorrectionSegmentStartProgress;
  int _focusCorrectionGeneration = 0;

  @override
  void initState() {
    super.initState();
    widget.progress.addStatusListener(_onProgressStatus);
    widget.progress.addListener(_onProgressChanged);
    final status = widget.progress.status;
    if (status == AnimationStatus.forward ||
        status == AnimationStatus.reverse) {
      _beginFocusPaneTransition(status);
    } else {
      _scheduleFocusAnchorSync();
    }
  }

  @override
  void didUpdateWidget(AppWindowMasterDetailTransition oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.progress != widget.progress) {
      oldWidget.progress.removeStatusListener(_onProgressStatus);
      oldWidget.progress.removeListener(_onProgressChanged);
      widget.progress.addStatusListener(_onProgressStatus);
      widget.progress.addListener(_onProgressChanged);
      final status = widget.progress.status;
      if (status == AnimationStatus.forward ||
          status == AnimationStatus.reverse) {
        _beginFocusPaneTransition(status);
      } else {
        _scheduleFocusAnchorSync();
      }
    }
    if (oldWidget.focusAnchorContext != widget.focusAnchorContext ||
        oldWidget.focusAnchorKey != widget.focusAnchorKey) {
      _focusAnchorSyncSuppressed = false;
      _clearFocusCorrectionSegment();
      _scheduleFocusAnchorSync();
    }
  }

  void _onProgressStatus(AnimationStatus status) {
    if (status == AnimationStatus.forward ||
        status == AnimationStatus.reverse) {
      _beginFocusPaneTransition(status);
      return;
    }
    if (status == AnimationStatus.completed ||
        status == AnimationStatus.dismissed) {
      if (_focusAnchorSyncSuppressed) {
        _focusPaneTransitionInProgress = false;
        _clearFocusCorrectionSegment();
      } else {
        _scheduleFocusAnchorSync();
      }
    }
  }

  void _beginFocusPaneTransition(AnimationStatus status) {
    _focusAnchorSyncSuppressed = false;
    _focusPaneTransitionInProgress = true;
    _focusPaneTransitionEndProgress =
        status == AnimationStatus.forward ? 1.0 : 0.0;
    _clearFocusCorrectionSegment();
    _captureVisibleScrollAnchor();

    // Cancel any standalone reveal already in progress. From now on, any
    // needed correction is driven by the pane transition's shared progress.
    if (_focusAnchorCorrectionInFlight) {
      final anchor =
          widget.focusAnchorKey?.currentContext ?? widget.focusAnchorContext;
      final scrollable = anchor == null ? null : Scrollable.maybeOf(anchor);
      final position = scrollable?.position;
      if (position != null && position.hasPixels) {
        position.jumpTo(position.pixels);
      }
    }
    _focusCorrectionGeneration++;
    _focusAnchorCorrectionInFlight = false;
    _scheduleFocusAnchorSync();
  }

  void _captureVisibleScrollAnchor() {
    _visualScrollAnchorKey = null;
    _visualScrollAnchorPosition = null;
    _visualScrollAnchorTop = null;
    double? anchorTop;

    for (final key in widget.scrollAnchorKeys) {
      final anchorContext = key.currentContext;
      if (anchorContext == null || !anchorContext.mounted) continue;
      final renderObject = anchorContext.findRenderObject();
      if (renderObject is! RenderBox || !renderObject.attached) continue;
      final viewport = RenderAbstractViewport.maybeOf(renderObject);
      if (viewport == null || viewport is! RenderBox) continue;
      final viewportBox = viewport as RenderBox;
      if (!viewportBox.attached) continue;
      final anchorRect =
          renderObject.localToGlobal(Offset.zero) & renderObject.size;
      final viewportRect =
          viewportBox.localToGlobal(Offset.zero) & viewportBox.size;
      if (anchorRect.bottom <= viewportRect.top + 1 ||
          anchorRect.top >= viewportRect.bottom - 1) {
        continue;
      }
      if (anchorTop == null || anchorRect.top < anchorTop) {
        _visualScrollAnchorKey = key;
        anchorTop = anchorRect.top;
      }
    }

    final anchor = _visualScrollAnchorKey?.currentContext;
    final scrollable =
        anchor == null ? null : Scrollable.maybeOf(anchor);
    final position = scrollable?.position;
    if (position == null ||
        !position.hasPixels ||
        anchorTop == null) {
      _visualScrollAnchorKey = null;
      return;
    }
    _visualScrollAnchorPosition = position;
    _visualScrollAnchorTop = anchorTop;
  }

  void _syncVisibleScrollAnchor() {
    final key = _visualScrollAnchorKey;
    final position = _visualScrollAnchorPosition;
    final targetTop = _visualScrollAnchorTop;
    final anchor = key?.currentContext;
    if (anchor == null ||
        !anchor.mounted ||
        position == null ||
        targetTop == null ||
        !position.hasPixels) {
      return;
    }
    final renderObject = anchor.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.attached) return;
    final currentTop = renderObject.localToGlobal(Offset.zero).dy;
    final delta = currentTop - targetTop;
    if (delta.abs() <= 0.25) return;
    final targetOffset = (position.pixels + delta)
        .clamp(position.minScrollExtent, position.maxScrollExtent)
        .toDouble();
    if ((targetOffset - position.pixels).abs() > 0.1) {
      position.jumpTo(targetOffset);
    }
  }

  void _onProgressChanged() {
    if (_focusPaneTransitionInProgress &&
        !_focusAnchorSyncSuppressed &&
        (widget.progress.status == AnimationStatus.forward ||
            widget.progress.status == AnimationStatus.reverse)) {
      _scheduleFocusAnchorSync();
    }
  }

  void _clearFocusCorrectionSegment() {
    _focusCorrectionSegmentStartOffset = null;
    _focusCorrectionSegmentStartProgress = null;
  }

  void _syncFocusAnchorWithPane({required bool finalFrame}) {
    // Keep the first visible content item at its original screen coordinate
    // while width-dependent rows above it grow or shrink.
    _syncVisibleScrollAnchor();

    final anchor =
        widget.focusAnchorKey?.currentContext ?? widget.focusAnchorContext;
    if (anchor == null || !anchor.mounted) return;
    final scrollable = Scrollable.maybeOf(anchor);
    if (scrollable == null) return;
    final position = scrollable.position;
    if (!position.hasPixels || !position.hasContentDimensions) return;

    final target = appWindowFocusAnchorScrollTarget(
      anchorContext: anchor,
      viewportContext: context,
      avoidTabBar: widget.focusAvoidTabBar,
    );
    if (target == null) {
      // If it is already visible, preserve its position rather than centering
      // it or continuing an adjustment that is no longer needed.
      _clearFocusCorrectionSegment();
      return;
    }

    final progress = widget.progress.value.clamp(0.0, 1.0).toDouble();
    _focusCorrectionSegmentStartOffset ??= position.pixels;
    _focusCorrectionSegmentStartProgress ??= progress;
    final startOffset = _focusCorrectionSegmentStartOffset!;
    final startProgress = _focusCorrectionSegmentStartProgress!;
    final endProgress = _focusPaneTransitionEndProgress ?? progress;
    final progressRange = endProgress - startProgress;
    final segmentProgress = finalFrame || progressRange.abs() < 0.0001
        ? 1.0
        : ((progress - startProgress) / progressRange)
              .clamp(0.0, 1.0)
              .toDouble();
    final easedProgress = Curves.easeInOutCubic.transform(segmentProgress);
    final desiredOffset = finalFrame
        ? target.offset
        : startOffset + (target.offset - startOffset) * easedProgress;
    final clampedOffset = desiredOffset
        .clamp(position.minScrollExtent, position.maxScrollExtent)
        .toDouble();
    if ((clampedOffset - position.pixels).abs() > 0.1) {
      position.jumpTo(clampedOffset);
    }
  }

  bool _isSettled(AnimationStatus status) =>
      status == AnimationStatus.completed ||
      status == AnimationStatus.dismissed;

  bool _onMasterScroll(ScrollNotification notification) {
    final isUserDrag =
        (notification is ScrollStartNotification &&
            notification.dragDetails != null) ||
        (notification is ScrollUpdateNotification &&
            notification.dragDetails != null);
    if (isUserDrag && _focusPaneTransitionInProgress) {
      // A deliberate scroll takes precedence over automatic anchor correction.
      _focusAnchorSyncSuppressed = true;
      _clearFocusCorrectionSegment();
      _visualScrollAnchorKey = null;
      _visualScrollAnchorPosition = null;
      _visualScrollAnchorTop = null;
    }
    return false;
  }

  void _scheduleFocusAnchorSync() {
    if (_focusAnchorSyncSuppressed) return;
    if (_focusAnchorSyncScheduled) return;
    _focusAnchorSyncScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusAnchorSyncScheduled = false;
      if (!mounted || _focusAnchorSyncSuppressed) return;
      final status = widget.progress.status;
      if (_focusPaneTransitionInProgress) {
        if (status != AnimationStatus.forward &&
            status != AnimationStatus.reverse &&
            !_isSettled(status)) {
          return;
        }
        _syncFocusAnchorWithPane(finalFrame: _isSettled(status));
        if (_isSettled(status)) {
          _focusPaneTransitionInProgress = false;
          _clearFocusCorrectionSegment();
        }
        return;
      }
      if (_focusAnchorCorrectionInFlight || !_isSettled(status)) return;

      final anchor =
          widget.focusAnchorKey?.currentContext ?? widget.focusAnchorContext;
      if (anchor == null || !anchor.mounted) return;
      final target = appWindowFocusAnchorScrollTarget(
        anchorContext: anchor,
        viewportContext: context,
        avoidTabBar: widget.focusAvoidTabBar,
      );
      if (target == null) return;

      _focusAnchorCorrectionInFlight = true;
      final generation = ++_focusCorrectionGeneration;
      unawaited(
        _animateFocusAnchor(
          target,
          widget.focusRevealDuration,
          generation,
        ),
      );
    });
  }

  Future<void> _animateFocusAnchor(
    AppWindowFocusAnchorScrollTarget target,
    Duration duration,
    int generation,
  ) async {
    try {
      await target.position.animateTo(
        target.offset,
        duration: duration,
        curve: Curves.easeInOutCubic,
      );
    } finally {
      if (mounted && generation == _focusCorrectionGeneration) {
        _focusAnchorCorrectionInFlight = false;
        if (!_focusAnchorSyncSuppressed) {
          _scheduleFocusAnchorSync();
        }
      }
    }
  }

  @override
  void dispose() {
    widget.progress.removeStatusListener(_onProgressStatus);
    widget.progress.removeListener(_onProgressChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.progress,
      builder: (context, _) {
        final progress = widget.progress.value.clamp(0.0, 1.0).toDouble();
        final masterWidth = widget.geometry.masterPaneWidthAt(progress);
        final dividerWidth = widget.geometry.dividerWidthAt(progress);
        final rightInset = widget.geometry.horizontalInset * (1.0 - progress);
        final master = widget.applyPaneInsets
            ? AppWindowPaneContent(
                includeRight: false,
                additionalRightInset: rightInset,
                child: widget.master,
              )
            : widget.master;
        final masterWithProgress = AppWindowMasterDetailProgressScope(
          geometry: widget.geometry,
          progress: widget.progress,
          child: master,
        );
        final detail =
            widget.applyPaneInsets && widget.applyDetailPaneInsets
            ? AppWindowPaneContent(
                includeLeft: false,
                child: widget.detail,
              )
            : widget.detail;

        return SizedBox(
          width: widget.geometry.physicalWidth,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: masterWidth,
                child: NotificationListener<ScrollNotification>(
                  onNotification: _onMasterScroll,
                  child: ClipRect(child: masterWithProgress),
                ),
              ),
              SizedBox(
                width: dividerWidth,
                child: widget.drawDivider
                    ? ColoredBox(color: widget.dividerColor)
                    : const SizedBox.expand(),
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) => ClipRect(
                    child: Transform.translate(
                      offset: Offset(
                        constraints.maxWidth * (1.0 - progress),
                        0,
                      ),
                      child: detail,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class AppWindowContentScope extends InheritedWidget {
  const AppWindowContentScope({
    super.key,
    required this.horizontalInset,
    required this.physicalWidth,
    required super.child,
  });

  final double horizontalInset;
  final double physicalWidth;

  static AppWindowContentScope of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<AppWindowContentScope>();
    assert(scope != null, 'AppWindowContentScope is missing above this widget');
    return scope!;
  }

  @override
  bool updateShouldNotify(AppWindowContentScope oldWidget) =>
      horizontalInset != oldWidget.horizontalInset ||
      physicalWidth != oldWidget.physicalWidth;
}

/// Gives a transition layer the full physical window width while its child
/// applies [AppWindowContentPadding] to the actual UI elements.
class AppWindowPhysicalWidth extends StatelessWidget {
  const AppWindowPhysicalWidth({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: AppWindowContentScope.of(context).physicalWidth,
      child: child,
    );
  }
}

/// Lets a child paint across the full physical window when its normal layout
/// viewport is inside [AppWindowContentPadding].
///
/// Search headers use this so their background and separator remain edge to
/// edge while their controls apply [AppWindowContentPadding] independently.
class AppWindowFullBleedWidth extends StatelessWidget {
  const AppWindowFullBleedWidth({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final width = AppWindowContentScope.of(context).physicalWidth;
    return OverflowBox(
      alignment: Alignment.center,
      minWidth: width,
      maxWidth: width,
      child: SizedBox(width: width, child: child),
    );
  }
}

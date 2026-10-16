import 'dart:math' as math;

import 'package:flutter/cupertino.dart';

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

/// Reusable full-width-to-master/detail transition for landscape navigation.
///
/// The master shrinks to the shared portrait-width target while the detail
/// enters from the physical right edge. Safe-area-aware callers can use the
/// default pane insets; callers that already inset their contents can disable
/// them. [focusAnchorContext] or [focusAnchorKey] keeps the item that opened
/// the detail pane centered in the master when the transition settles.
class AppWindowMasterDetailTransition extends StatefulWidget {
  const AppWindowMasterDetailTransition({
    super.key,
    required this.geometry,
    required this.progress,
    required this.master,
    required this.detail,
    required this.dividerColor,
    this.applyPaneInsets = true,
    this.drawDivider = true,
    this.focusAnchorContext,
    this.focusAnchorKey,
  });

  final AppWindowMasterDetailGeometry geometry;
  final Animation<double> progress;
  final Widget master;
  final Widget detail;
  final Color dividerColor;
  final bool applyPaneInsets;
  final bool drawDivider;
  final BuildContext? focusAnchorContext;
  final GlobalKey? focusAnchorKey;

  @override
  State<AppWindowMasterDetailTransition> createState() =>
      _AppWindowMasterDetailTransitionState();
}

class _AppWindowMasterDetailTransitionState
    extends State<AppWindowMasterDetailTransition> {
  @override
  void initState() {
    super.initState();
    widget.progress.addStatusListener(_onProgressStatus);
  }

  @override
  void didUpdateWidget(AppWindowMasterDetailTransition oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.progress != widget.progress) {
      oldWidget.progress.removeStatusListener(_onProgressStatus);
      widget.progress.addStatusListener(_onProgressStatus);
    }
    if (oldWidget.focusAnchorContext != widget.focusAnchorContext ||
        oldWidget.focusAnchorKey != widget.focusAnchorKey) {
      _centerFocusAnchor(Duration.zero);
    }
  }

  void _onProgressStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed ||
        status == AnimationStatus.dismissed) {
      _centerFocusAnchor(const Duration(milliseconds: 180));
    }
  }

  void _centerFocusAnchor(Duration duration) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final anchor =
          widget.focusAnchorKey?.currentContext ?? widget.focusAnchorContext;
      if (anchor == null || !anchor.mounted) return;
      Scrollable.ensureVisible(
        anchor,
        alignment: 0.5,
        duration: duration,
        curve: Curves.easeInOutCubic,
      );
    });
  }

  @override
  void dispose() {
    widget.progress.removeStatusListener(_onProgressStatus);
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
        final detail = widget.applyPaneInsets
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
                child: ClipRect(child: master),
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

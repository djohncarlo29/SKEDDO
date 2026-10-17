import 'package:flutter/widgets.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart'
    show LiquidGlassEdge, LiquidGlassScrollEdge;

const double kAppHeaderToolbarHeight = 44;
const double kAppHeaderTitleHeight = 57;
const double _kAppHeaderScrollEdgeMaxTintOpacity = 0.24;
const double _kAppHeaderScrollEdgeMaxBlurSigma = 8;

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
    required super.child,
  });

  final double leadingInset;

  static double maybeOf(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<AppHeaderScrollInsetScope>()
          ?.leadingInset ??
      0.0;

  @override
  bool updateShouldNotify(AppHeaderScrollInsetScope oldWidget) =>
      leadingInset != oldWidget.leadingInset;
}

/// Extends a page scroll viewport upward by the shell inset without moving its
/// parent's layout. The scrollable's own content must include a matching
/// leading inset so its initial on-screen position stays unchanged.
class AppHeaderScrollViewport extends StatelessWidget {
  const AppHeaderScrollViewport({
    super.key,
    required this.leadingInset,
    required this.child,
  });

  final double leadingInset;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (leadingInset <= 0.0 || !leadingInset.isFinite) return child;

    return LayoutBuilder(
      builder: (context, constraints) {
        if (!constraints.hasBoundedHeight) return child;
        final viewportHeight = constraints.maxHeight + leadingInset;
        return OverflowBox(
          alignment: Alignment.topCenter,
          minHeight: viewportHeight,
          maxHeight: viewportHeight,
          child: Transform.translate(
            offset: Offset(0.0, -leadingInset),
            child: SizedBox(height: viewportHeight, child: child),
          ),
        );
      },
    );
  }
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
    this.paintOrder = SliverPaintOrder.forward,
    this.slivers = const <Widget>[],
    this.semanticChildCount,
    this.dragStartBehavior = DragStartBehavior.start,
    this.keyboardDismissBehavior = ScrollViewKeyboardDismissBehavior.manual,
    this.restorationId,
    this.hitTestBehavior,
    this.clipBehavior = Clip.none,
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
  final ScrollViewKeyboardDismissBehavior keyboardDismissBehavior;
  final String? restorationId;
  final HitTestBehavior? hitTestBehavior;
  final Clip clipBehavior;

  @override
  Widget build(BuildContext context) {
    final leadingInset = AppHeaderScrollInsetScope.maybeOf(context);
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

    return AppHeaderScrollViewport(
      leadingInset: leadingInset,
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
/// itself is painted in the AppShell header above the scrolling content.
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
        final expanded = (1 - animation.value.clamp(0.0, 1.0)).toDouble();
        return SizedBox(height: kAppHeaderTitleHeight * expanded);
      },
    );
  }
}

/// The shared Liquid Glass treatment used beneath the first, pinned header
/// level. This is a visual sibling overlay: its local filter clip bounds only
/// the glass effect, never the scrollable content. The caller supplies progress
/// from the live page scroll gesture.
class AppHeaderScrollEdge extends StatelessWidget {
  const AppHeaderScrollEdge({
    super.key,
    required this.progress,
    required this.surfaceColor,
    required this.height,
  });

  final double progress;
  final Color surfaceColor;
  final double height;

  @override
  Widget build(BuildContext context) {
    final normalizedProgress = progress.clamp(0.0, 1.0).toDouble();
    if (height <= 0) {
      return const SizedBox.shrink();
    }

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      height: height,
      child: Offstage(
        offstage: normalizedProgress <= 0.01,
        child: IgnorePointer(
          child: LiquidGlassScrollEdge(
            edge: LiquidGlassEdge.top,
            color: surfaceColor.withValues(
              // Keep the shared app-level edge translucent enough that content
              // passing behind it remains visibly present. The edge is a
              // compositing treatment, never a visibility threshold.
              alpha:
                  (_kAppHeaderScrollEdgeMaxTintOpacity *
                          normalizedProgress *
                          surfaceColor.a)
                  .clamp(0.0, 1.0)
                  .toDouble(),
            ),
            // Keep the same overlay subtree at rest while limiting blur so
            // text and controls remain perceptible as they pass through.
            blur: normalizedProgress > 0
                ? _kAppHeaderScrollEdgeMaxBlurSigma * normalizedProgress
                : 0.001,
          ),
        ),
      ),
    );
  }
}

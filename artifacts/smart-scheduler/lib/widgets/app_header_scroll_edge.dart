import 'package:flutter/gestures.dart' show DragStartBehavior;
import 'package:flutter/widgets.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart'
    show LiquidGlassEdge, LiquidGlassScrollEdge;

const double kAppHeaderToolbarHeight = 44;
const double kAppHeaderTitleHeight = 57;
const double kAppHeaderScrollEdgeTitleCapExtension = 10;
const double _kAppHeaderScrollEdgeMaxTintOpacity = 0.3;
const double _kAppHeaderScrollEdgeMaxBlurSigma = 18;

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
    final offset = metrics.pixels - metrics.minScrollExtent;
    if (!offset.isFinite || offset <= 0.0) return 0.0;
    return offset;
  }

  /// Returns the translation that cancels leading overscroll for a title
  /// which is otherwise laid out inside the scrollable content.
  static double leadingOverscrollCorrection(ScrollMetrics metrics) {
    final offset = metrics.pixels - metrics.minScrollExtent;
    if (!offset.isFinite || offset >= 0.0) return 0.0;
    return offset;
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
    final Listenable animation = owningPosition ?? scrollController;
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final positions = scrollController.positions;
        final position =
            owningPosition ??
            (positions.length == 1 ? positions.single : null);
        if (position == null) return child;
        if (!position.hasContentDimensions) return child;
        final correction =
            AppHeaderScrollBehavior.leadingOverscrollCorrection(position);
        if (correction == 0.0) return child;
        return Transform.translate(
          offset: Offset(0.0, correction),
          child: child,
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
    this.topExtension = 0.0,
  });

  final double leadingInset;
  final Widget child;
  final double topExtension;

  @override
  Widget build(BuildContext context) {
    final safeLeadingInset =
        leadingInset.isFinite && leadingInset > 0.0 ? leadingInset : 0.0;
    final safeTopExtension =
        topExtension.isFinite && topExtension > 0.0 ? topExtension : 0.0;
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
              // Keep the shared app-level edge translucent while applying a
              // stronger blur as content passes beneath the pinned header.
              // The edge remains a compositing treatment, never a visibility
              // threshold.
              alpha:
                  (_kAppHeaderScrollEdgeMaxTintOpacity *
                          normalizedProgress *
                          surfaceColor.a)
                      .clamp(0.0, 1.0)
                      .toDouble(),
            ),
            // Keep the same overlay subtree at rest; the stronger blur matches
            // the depth of the glass treatment shown in the reference.
            blur: normalizedProgress > 0
                ? _kAppHeaderScrollEdgeMaxBlurSigma * normalizedProgress
                : 0.001,
          ),
        ),
      ),
    );
  }
}

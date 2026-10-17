import 'package:flutter/widgets.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart'
    show LiquidGlassEdge, LiquidGlassScrollEdge;

const double kAppHeaderToolbarHeight = 44;
const double kAppHeaderTitleHeight = 57;

/// A scroll viewport whose content is allowed to paint beneath the pinned
/// first-level header, where [AppHeaderScrollEdge] can apply its glass effect.
/// Its page-level ancestors must also allow that paint overflow; use
/// [AppHeaderScrollStack] for page stacks that contain one of these viewports.
class AppHeaderScrollView extends CustomScrollView {
  const AppHeaderScrollView({
    super.key,
    super.scrollDirection,
    super.reverse,
    super.controller,
    super.primary,
    super.physics,
    super.scrollBehavior,
    super.shrinkWrap,
    super.center,
    super.anchor,
    super.cacheExtent,
    super.paintOrder,
    super.slivers,
    super.semanticChildCount,
    super.dragStartBehavior,
    super.keyboardDismissBehavior,
    super.restorationId,
    super.hitTestBehavior,
    Clip clipBehavior = Clip.none,
  }) : super(clipBehavior: clipBehavior);
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
              alpha: (0.78 * normalizedProgress * surfaceColor.a)
                  .clamp(0.0, 1.0)
                  .toDouble(),
            ),
            // Match the modal sheet's inactive sigma while keeping this
            // overlay's render-tree shape stable at rest.
            blur: normalizedProgress > 0 ? 12 * normalizedProgress : 0.001,
          ),
        ),
      ),
    );
  }
}

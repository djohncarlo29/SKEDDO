import 'dart:ui' show ImageFilter;

import 'package:flutter/widgets.dart';

/// Which screen edge a [LiquidGlassScrollEdge] fades in from.
enum LiquidGlassEdge { top, bottom }

/// How the scroll-edge backdrop blur meets the content.
enum LiquidGlassScrollEdgeStyle {
  /// Feather the blur toward the content for a smooth transition.
  soft,

  /// Keep the blur uniform across the band.
  hard,
}

/// A tinted, blurred band pinned to the edge of scrolling content.
///
/// The color and blur values are peak strengths at [edge]. Both effects fade
/// toward the content. The band ignores pointer input unless [child] is set.
///
/// This widget keeps the scroll-edge API used by liquid_glass_easy 4.3 while
/// remaining compatible with this app's customized 4.0 package fork.
class LiquidGlassScrollEdge extends StatelessWidget {
  /// The curve used for the tint fade.
  static const Curve defaultBlurCurve = Curves.easeInQuart;

  /// Which edge the band hugs.
  final LiquidGlassEdge edge;

  /// Optional fixed height. When omitted, the parent constraints determine it.
  final double? height;

  /// Peak tint opacity at the hugged edge.
  final Color color;

  /// Peak backdrop blur sigma in logical pixels.
  final double blur;

  /// Shape of the tint fade.
  final Curve curve;

  /// Shape of the blur fade when [style] is [LiquidGlassScrollEdgeStyle.soft].
  final Curve blurCurve;

  /// Whether the blur fades softly or stays uniform across the band.
  final LiquidGlassScrollEdgeStyle style;

  /// Optional hit-testable content above the tint and blur.
  final Widget? child;

  const LiquidGlassScrollEdge({
    super.key,
    this.edge = LiquidGlassEdge.bottom,
    this.height,
    this.color = const Color(0x8A000000),
    this.blur = 5,
    this.curve = Curves.easeInOut,
    this.blurCurve = defaultBlurCurve,
    this.style = LiquidGlassScrollEdgeStyle.soft,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    final isTop = edge == LiquidGlassEdge.top;
    final tint = DecoratedBox(
      decoration: BoxDecoration(
        gradient: _rampGradient(color, isTop, curve),
      ),
    );
    final Widget band;
    if (blur <= 0) {
      band = tint;
    } else {
      final blurChild = style == LiquidGlassScrollEdgeStyle.soft
          ? DecoratedBox(
              decoration: BoxDecoration(
                gradient: _rampGradient(
                  const Color(0xFF000000),
                  isTop,
                  blurCurve,
                ),
                backgroundBlendMode: BlendMode.dstIn,
              ),
              child: const SizedBox.expand(),
            )
          : const SizedBox.expand();
      band = Stack(
        fit: StackFit.expand,
        children: [
          ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
              child: blurChild,
            ),
          ),
          tint,
        ],
      );
    }

    return SizedBox(
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          IgnorePointer(child: band),
          if (child != null) child!,
        ],
      ),
    );
  }

  LinearGradient _rampGradient(Color tint, bool isTop, Curve falloff) {
    const stopsCount = 8;
    final stops = <double>[];
    final colors = <Color>[];
    for (var i = 0; i < stopsCount; i++) {
      final t = i / (stopsCount - 1);
      stops.add(t);
      colors.add(tint.withValues(alpha: tint.a * (1 - falloff.transform(t))));
    }
    return LinearGradient(
      begin: isTop ? Alignment.topCenter : Alignment.bottomCenter,
      end: isTop ? Alignment.bottomCenter : Alignment.topCenter,
      colors: colors,
      stops: stops,
    );
  }
}
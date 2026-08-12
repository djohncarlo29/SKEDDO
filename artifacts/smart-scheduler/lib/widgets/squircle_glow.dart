// ── SquircleGlowBorder ────────────────────────────────────────────────────────
// Animated rainbow glow that follows ContinuousRectangleBorder (squircle)
// exactly via CustomPainter + getOuterPath(), eliminating the corner gaps that
// appear when InnerAiGlowing uses a standard circular-arc RRect.
//
// [outer] = false → inner glow  (blur bleeds inward;  for input cards).
// [outer] = true  → outer glow  (blur bleeds outward; for search bars).
//
// Usage – inner (notes card):
//   Positioned.fill(child: IgnorePointer(child: SquircleGlowBorder(
//     cornerRadius: kSbCornerRadius, outer: false,
//     child: const SizedBox.expand())))
//
// Usage – outer (search bar, Stack must have clipBehavior: Clip.none):
//   Positioned.fill(child: IgnorePointer(child: SquircleGlowBorder(
//     cornerRadius: kSearchBarCornerRadius, stadium: true, outer: true,
//     child: const SizedBox.expand())))

import 'dart:math' as math;
import 'package:flutter/widgets.dart';
import '../app_theme.dart';

/// Shared AI-glow colour palette (purple → pink → orange → teal rainbow).
const List<Color> kAIGlowPalette = [
  Color(0xFFD166D3),
  Color(0xFFF7BF69),
  Color(0xFFE2A0CB),
  Color(0xFFC982F7),
  Color(0xFFC580F3),
  Color(0xFFF1BFEB),
  Color(0xFF939AF9),
  Color(0xFFA97DF5),
];

class SquircleGlowBorder extends StatefulWidget {
  final double cornerRadius;
  final bool stadium;
  final List<Color> colors;
  final double glowWidth;
  final double blurSigma;

  /// false → inner glow (cards), true → outer glow (search bars).
  final bool outer;
  final Widget child;

  const SquircleGlowBorder({
    super.key,
    required this.cornerRadius,
    this.stadium = false,
    this.colors = kAIGlowPalette,
    this.glowWidth = 6.0,
    this.blurSigma = 7.0,
    this.outer = false,
    required this.child,
  });

  @override
  State<SquircleGlowBorder> createState() => _SquircleGlowBorderState();
}

class _SquircleGlowBorderState extends State<SquircleGlowBorder>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, child) => CustomPaint(
        painter: _SquircleGlowPainter(
          colors: widget.colors,
          glowWidth: widget.glowWidth,
          blurSigma: widget.blurSigma,
          cornerRadius: widget.cornerRadius,
          stadium: widget.stadium,
          outer: widget.outer,
          sweep: _ctrl.value,
        ),
        child: child,
      ),
      child: widget.child,
    );
  }
}

// ── Painter ───────────────────────────────────────────────────────────────────

class _SquircleGlowPainter extends CustomPainter {
  final List<Color> colors;
  final double glowWidth;
  final double blurSigma;
  final double cornerRadius;
  final bool stadium;
  final bool outer;
  final double sweep; // 0..1 animation progress

  const _SquircleGlowPainter({
    required this.colors,
    required this.glowWidth,
    required this.blurSigma,
    required this.cornerRadius,
    required this.stadium,
    required this.outer,
    required this.sweep,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Build the squircle path that exactly matches ContinuousRectangleBorder.
    final path =
        (stadium
                ? SquircleStadiumBorder(radius: cornerRadius)
                : BoundedContinuousRectangleBorder(
                    borderRadius: BorderRadius.circular(cornerRadius),
                  ))
            .getOuterPath(Offset.zero & size);

    // Rotating sweep gradient — wrap first colour at end so it loops cleanly.
    final angle = sweep * 2 * math.pi;
    final dim = math.max(size.width, size.height);
    final shaderRect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: dim * 2,
      height: dim * 2,
    );

    final paint = Paint()
      ..shader = SweepGradient(
        startAngle: angle,
        endAngle: angle + 2 * math.pi,
        colors: [...colors, colors[0]],
      ).createShader(shaderRect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = glowWidth
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, blurSigma);

    if (!outer) {
      // ── Inner glow ─────────────────────────────────────────────────────
      // Clip to inside the squircle path so the blur only bleeds inward.
      canvas.save();
      canvas.clipPath(path);
      canvas.drawPath(path, paint);
      canvas.restore();
    } else {
      // ── Outer glow ─────────────────────────────────────────────────────
      // Clip to the region OUTSIDE the squircle path so the blur only bleeds
      // outward.  The outer rect must exceed the blur spread so the gradient
      // has room to paint.
      final spread = blurSigma * 4 + glowWidth;
      final outerClip = Path()
        ..addRect(
          Rect.fromLTWH(
            -spread,
            -spread,
            size.width + spread * 2,
            size.height + spread * 2,
          ),
        )
        ..addPath(path, Offset.zero)
        ..fillType = PathFillType.evenOdd;
      canvas.save();
      canvas.clipPath(outerClip);
      canvas.drawPath(path, paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_SquircleGlowPainter old) =>
      old.sweep != sweep ||
      old.colors != colors ||
      old.glowWidth != glowWidth ||
      old.blurSigma != blurSigma ||
      old.cornerRadius != cornerRadius ||
      old.stadium != stadium ||
      old.outer != outer;
}

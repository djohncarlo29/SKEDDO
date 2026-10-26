import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Paints the slider track and its optional discrete ticks.
///
/// Kept in an internal source file so the endpoint geometry can be tested
/// without exposing the painter through the package's public barrel.
class LiquidGlassSliderTrackPainter extends CustomPainter {
  const LiquidGlassSliderTrackPainter({
    required this.inactiveColor,
    required this.activeColor,
    required this.fillEndX,
    required this.trackWidth,
    required this.trackHeight,
    required this.divisions,
  });

  final Color inactiveColor;
  final Color activeColor;
  final double fillEndX;
  final double trackWidth;
  final double trackHeight;
  final int divisions;

  @override
  void paint(Canvas canvas, Size size) {
    const tickHalfWidth = 1.0;
    // Preserve the original tick-to-track proportion (10 px ticks over a
    // 6 px line) as the line is made thinner.
    final tickHalfHeight = trackHeight * (5 / 6);
    final tickTop = trackHeight / 2 - tickHalfHeight;
    final tickBottom = trackHeight / 2 + tickHalfHeight;
    final tickInset = math.min(tickHalfWidth, trackWidth / 2).toDouble();
    final tickRange = math.max(0.0, trackWidth - tickInset * 2).toDouble();

    // The painted track reaches the resting thumb's outer edges. Its end
    // points are covered by the thumb when it settles at either extreme.
    final lineStartX = 0.0;
    final lineEndX = trackWidth;
    final clampedFill = fillEndX.clamp(lineStartX, lineEndX).toDouble();
    final trackRect = Rect.fromLTRB(lineStartX, 0, lineEndX, trackHeight);

    if (divisions <= 0) {
      // A free-moving slider has one continuous capsule, not an endpoint tick
      // that reads like a step. Clip the active fill to preserve the same
      // rounded silhouette at both ends.
      final trackRRect = RRect.fromRectAndRadius(
        trackRect,
        Radius.circular(trackHeight / 2),
      );
      canvas.drawRRect(trackRRect, Paint()..color = inactiveColor);
      if (clampedFill > lineStartX) {
        canvas
          ..save()
          ..clipRRect(trackRRect)
          ..drawRect(
            Rect.fromLTRB(lineStartX, 0, clampedFill, trackHeight),
            Paint()..color = activeColor,
          )
          ..restore();
      }
      return;
    }

    // Discrete tick bars span the full painted track: their outer edges meet
    // the line endpoints, with the remaining marks evenly distributed inside.
    final inactivePath = Path()..addRect(trackRect);
    final tickXs = <double>[];
    for (var i = 0; i <= divisions; i++) {
      final x = lineStartX + tickInset + tickRange * i / divisions;
      tickXs.add(x);
      inactivePath.addRect(
        Rect.fromLTRB(
          x - tickHalfWidth,
          tickTop,
          x + tickHalfWidth,
          tickBottom,
        ),
      );
    }
    canvas.drawPath(inactivePath, Paint()..color = inactiveColor);

    // Keep the active/inactive boundary square beneath the thumb; endpoint
    // ticks and the extended track are each painted as one coherent path.
    final activePath = Path();
    if (clampedFill > lineStartX) {
      activePath.addRect(
        Rect.fromLTRB(lineStartX, 0, clampedFill, trackHeight),
      );
    }
    for (final x in tickXs) {
      if (x - tickHalfWidth <= clampedFill) {
        activePath.addRect(
          Rect.fromLTRB(
            x - tickHalfWidth,
            tickTop,
            x + tickHalfWidth,
            tickBottom,
          ),
        );
      }
    }
    if (!activePath.getBounds().isEmpty) {
      canvas.drawPath(activePath, Paint()..color = activeColor);
    }
  }

  @override
  bool shouldRepaint(LiquidGlassSliderTrackPainter oldDelegate) =>
      oldDelegate.inactiveColor != inactiveColor ||
      oldDelegate.activeColor != activeColor ||
      oldDelegate.fillEndX != fillEndX ||
      oldDelegate.trackWidth != trackWidth ||
      oldDelegate.trackHeight != trackHeight ||
      oldDelegate.divisions != divisions;
}

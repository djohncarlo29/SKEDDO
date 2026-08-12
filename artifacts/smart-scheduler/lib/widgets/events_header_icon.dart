import 'package:flutter/cupertino.dart';

/// Composite header glyph matching the Events quick-add reference:
/// a list/card outline with a filled circular plus badge overlapping it.
class EventsHeaderAddIcon extends StatelessWidget {
  const EventsHeaderAddIcon({super.key, required this.color, this.size = 27});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _EventsHeaderAddPainter(color),
    );
  }
}

/// Local vector version of Framework7's `today_fill` icon.
///
/// The Framework7 web endpoint is not available in the app's runtime
/// environment, so this keeps the canonical Framework7 path local and avoids
/// the broken placeholder SVG state.
class TodayFillIcon extends StatelessWidget {
  const TodayFillIcon({super.key, required this.color, this.size = 26});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _TodayFillPainter(color),
    );
  }
}

class _EventsHeaderAddPainter extends CustomPainter {
  const _EventsHeaderAddPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide / 28.0;
    final stroke = 2.6 * s;
    final body = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final card = RRect.fromRectAndRadius(
      Rect.fromLTWH(2.5 * s, 2.5 * s, 19.5 * s, 21.0 * s),
      Radius.circular(4.3 * s),
    );
    canvas.drawRRect(card, body);

    final bulletRadius = 1.35 * s;
    canvas.drawCircle(Offset(7.4 * s, 9.2 * s), bulletRadius, body);
    canvas.drawCircle(Offset(7.4 * s, 17.0 * s), bulletRadius, body);
    canvas.drawLine(Offset(11.3 * s, 9.2 * s), Offset(18.0 * s, 9.2 * s), body);
    canvas.drawLine(
      Offset(11.3 * s, 17.0 * s),
      Offset(16.1 * s, 17.0 * s),
      body,
    );

    final badgeSize = 12.2 * s;
    final badgeCenter = Offset(21.2 * s, 21.0 * s);
    final badge = Paint()..color = color;
    canvas.drawCircle(badgeCenter, badgeSize / 2, badge);

    final plus = Paint()
      ..color = CupertinoColors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8 * s
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      badgeCenter.translate(-3.0 * s, 0),
      badgeCenter.translate(3.0 * s, 0),
      plus,
    );
    canvas.drawLine(
      badgeCenter.translate(0, -3.0 * s),
      badgeCenter.translate(0, 3.0 * s),
      plus,
    );
  }

  @override
  bool shouldRepaint(_EventsHeaderAddPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _TodayFillPainter extends CustomPainter {
  const _TodayFillPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.shortestSide / 56.0;
    final path = Path()..fillType = PathFillType.evenOdd;

    // Framework7 src/f7/today_fill.svg, including its translate(10 6).
    path
      ..moveTo(14 * scale, 6 * scale)
      ..lineTo(42 * scale, 6 * scale)
      ..cubicTo(
        44.209139 * scale,
        6 * scale,
        46 * scale,
        7.790861 * scale,
        46 * scale,
        10 * scale,
      )
      ..lineTo(46 * scale, 46 * scale)
      ..cubicTo(
        46 * scale,
        48.209139 * scale,
        44.209139 * scale,
        50 * scale,
        42 * scale,
        50 * scale,
      )
      ..lineTo(14 * scale, 50 * scale)
      ..cubicTo(
        11.790861 * scale,
        50 * scale,
        10 * scale,
        48.209139 * scale,
        10 * scale,
        46 * scale,
      )
      ..lineTo(10 * scale, 10 * scale)
      ..cubicTo(
        10 * scale,
        7.790861 * scale,
        11.790861 * scale,
        6 * scale,
        14 * scale,
        6 * scale,
      )
      ..close()
      ..moveTo(18 * scale, 20 * scale)
      ..cubicTo(
        16.895431 * scale,
        20 * scale,
        16 * scale,
        20.895431 * scale,
        16 * scale,
        22 * scale,
      )
      ..lineTo(16 * scale, 42 * scale)
      ..cubicTo(
        16 * scale,
        43.104569 * scale,
        16.895431 * scale,
        44 * scale,
        18 * scale,
        44 * scale,
      )
      ..lineTo(38 * scale, 44 * scale)
      ..cubicTo(
        39.104569 * scale,
        44 * scale,
        40 * scale,
        43.104569 * scale,
        40 * scale,
        42 * scale,
      )
      ..lineTo(40 * scale, 22 * scale)
      ..cubicTo(
        40 * scale,
        20.895431 * scale,
        39.104569 * scale,
        20 * scale,
        38 * scale,
        20 * scale,
      )
      ..close()
      ..moveTo(18 * scale, 12 * scale)
      ..cubicTo(
        16.895431 * scale,
        12 * scale,
        16 * scale,
        12.895431 * scale,
        16 * scale,
        14 * scale,
      )
      ..cubicTo(
        16 * scale,
        15.104569 * scale,
        16.895431 * scale,
        16 * scale,
        18 * scale,
        16 * scale,
      )
      ..lineTo(26 * scale, 16 * scale)
      ..cubicTo(
        27.104569 * scale,
        16 * scale,
        28 * scale,
        15.104569 * scale,
        28 * scale,
        14 * scale,
      )
      ..cubicTo(
        28 * scale,
        12.895431 * scale,
        27.104569 * scale,
        12 * scale,
        26 * scale,
        12 * scale,
      )
      ..close();

    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_TodayFillPainter oldDelegate) =>
      oldDelegate.color != color;
}

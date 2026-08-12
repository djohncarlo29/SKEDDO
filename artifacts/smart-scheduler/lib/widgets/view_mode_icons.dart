import 'package:flutter/cupertino.dart';

// ══════════════════════════════════════════════════════════════════════════════
// Day-view sub-mode enum — used by AppShell to track the active Day View layout.
// ══════════════════════════════════════════════════════════════════════════════
enum DayViewSubMode { singleDay, multiDay, list }

// ══════════════════════════════════════════════════════════════════════════════
// Columns — rounded-rect outer border + 3×3 grid of filled cells
//           only some cells rendered (staircase pattern):
//             row 0: cols 0 1 2   (all three)
//             row 1: cols   1 2   (skip col 0)
//             row 2: col    1     (middle only)
// ══════════════════════════════════════════════════════════════════════════════
class ColumnsViewIcon extends StatelessWidget {
  final Color color;
  final double size;
  const ColumnsViewIcon({super.key, required this.color, this.size = 28});

  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size,
    child: Center(
      child: CustomPaint(
        size: Size(size * 0.86, size * 0.68),
        painter: _ColumnsPainter(color),
      ),
    ),
  );
}

class _ColumnsPainter extends CustomPainter {
  final Color color;
  const _ColumnsPainter(this.color);

  // (row, col) pairs that should be drawn
  static const _visible = [(0, 0), (0, 1), (0, 2), (1, 1), (1, 2), (2, 1)];

  @override
  void paint(Canvas canvas, Size s) {
    const sw = 1.6;
    const r = 2.5; // outer corner radius
    const inset = 2.8; // gap between outer border and cell grid
    const gap = 1.0; // gap between cells

    final border = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = sw
      ..strokeJoin = StrokeJoin.round;

    final fill = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // Outer rounded rectangle
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(sw / 2, sw / 2, s.width - sw, s.height - sw),
        const Radius.circular(r),
      ),
      border,
    );

    // Inner cell grid
    final x0 = sw / 2 + inset;
    final y0 = sw / 2 + inset;
    final x1 = s.width - sw / 2 - inset;
    final y1 = s.height - sw / 2 - inset;
    final cw = (x1 - x0 - 2 * gap) / 3;
    final ch = (y1 - y0 - 2 * gap) / 3;

    for (final (row, col) in _visible) {
      final cx = x0 + col * (cw + gap);
      final cy = y0 + row * (ch + gap);
      canvas.drawRect(Rect.fromLTWH(cx, cy, cw, ch), fill);
    }
  }

  @override
  bool shouldRepaint(_ColumnsPainter o) => o.color != color;
}

// ══════════════════════════════════════════════════════════════════════════════
// Compact — very elongated horizontal capsule + 3 internal vertical dividers
// ══════════════════════════════════════════════════════════════════════════════
class CompactViewIcon extends StatelessWidget {
  final Color color;
  final double size;
  const CompactViewIcon({super.key, required this.color, this.size = 28});

  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size,
    child: Center(
      child: CustomPaint(
        size: Size(size * 0.92, size * 0.38), // ~3:1 elongated capsule
        painter: _CompactPainter(color),
      ),
    ),
  );
}

class _CompactPainter extends CustomPainter {
  final Color color;
  const _CompactPainter(this.color);

  @override
  void paint(Canvas canvas, Size s) {
    const sw = 1.8;
    final st = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = sw
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // True pill: radius = height / 2
    final r = s.height / 2;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(sw / 2, sw / 2, s.width - sw, s.height - sw),
        Radius.circular(r),
      ),
      st,
    );

    // 3 vertical dividers producing 4 visually equal segments.
    // The rounded end-caps have less visual area than a rectangle of the same
    // width, so the outer sections look slightly narrower.  Shift the outer
    // dividers inward by capCorrection (≈ r·(1−π/4)/2) to compensate.
    final topY = sw / 2;
    final botY = s.height - sw / 2;
    final capCorrection = s.height * 0.054; // ≈ (s.height/2)·(1−π/4)/2

    for (var i = 1; i <= 3; i++) {
      double x = s.width * i / 4;
      if (i == 1) x += capCorrection;
      if (i == 3) x -= capCorrection;
      canvas.drawLine(Offset(x, topY), Offset(x, botY), st);
    }
  }

  @override
  bool shouldRepaint(_CompactPainter o) => o.color != color;
}

// ══════════════════════════════════════════════════════════════════════════════
// Stacked — two identical fully-rounded pills (capsules) with a gap
//           Less elongated than Compact; pills are taller / squarer
// ══════════════════════════════════════════════════════════════════════════════
class StackedViewIcon extends StatelessWidget {
  final Color color;
  final double size;
  const StackedViewIcon({super.key, required this.color, this.size = 28});

  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size,
    child: Center(
      child: CustomPaint(
        size: Size(
          size * 0.92,
          size * 0.66,
        ), // same width as Compact; 2 pills + gap
        painter: _StackedPainter(color),
      ),
    ),
  );
}

class _StackedPainter extends CustomPainter {
  final Color color;
  const _StackedPainter(this.color);

  @override
  void paint(Canvas canvas, Size s) {
    const sw = 1.8;
    final st = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = sw
      ..strokeJoin = StrokeJoin.round;

    const gap = 1.0;
    final pillH = (s.height - gap) / 2;
    final r = pillH / 2; // full capsule (radius = height/2)

    void pill(double top) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(sw / 2, top + sw / 2, s.width - sw, pillH - sw),
          Radius.circular(r),
        ),
        st,
      );
    }

    pill(0);
    pill(pillH + gap);
  }

  @override
  bool shouldRepaint(_StackedPainter o) => o.color != color;
}

// ══════════════════════════════════════════════════════════════════════════════
// Details — two outlined rounded rectangles (less round than Stacked)
//            each with an internal horizontal line:
//              top block:    line at ~60 % width
//              bottom block: line at ~38 % width
// ══════════════════════════════════════════════════════════════════════════════
class DetailsViewIcon extends StatelessWidget {
  final Color color;
  final double size;
  const DetailsViewIcon({super.key, required this.color, this.size = 28});

  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size,
    child: Center(
      child: CustomPaint(
        size: Size(size * 0.92, size * 0.745),
        painter: _DetailsPainter(color),
      ),
    ),
  );
}

class _DetailsPainter extends CustomPainter {
  final Color color;
  const _DetailsPainter(this.color);

  @override
  void paint(Canvas canvas, Size s) {
    const sw = 1.8;
    const gap = 1.5;
    const r = 2.2; // more rectangular — less round than Stacked

    final st = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = sw
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Inner lines — same weight as the outline
    final stLine = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = sw
      ..strokeCap = StrokeCap.round;

    // Raise entire drawing by 1 px
    canvas.translate(0, -1.0);

    final blockH = (s.height - gap) / 2;

    // Outer rounded rect for a block
    void block(double top) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(sw / 2, top + sw / 2, s.width - sw, blockH - sw),
          const Radius.circular(r),
        ),
        st,
      );
    }

    // Inner line: starts 1 px from left inner wall, runs widthFraction of interior
    void innerLine(double top, double widthFraction) {
      final cy = top + blockH / 2;
      final lineX0 =
          sw + sw / 2 + 1.0; // 1 px gap: left EDGE of line from inner wall
      final interior = s.width - sw * 2 - 2.0; // usable interior span
      final lineX1 = lineX0 + interior * widthFraction + 1.0;
      canvas.drawLine(Offset(lineX0, cy), Offset(lineX1, cy), stLine);
    }

    block(0);
    innerLine(0, 0.60); // top block: longer inner line

    block(blockH + gap);
    innerLine(blockH + gap, 0.38); // bottom block: shorter inner line
  }

  @override
  bool shouldRepaint(_DetailsPainter o) => o.color != color;
}

// ══════════════════════════════════════════════════════════════════════════════
// List — thick-outlined landscape rounded rect (screen) at top
//         + two rows of [ filled dot ][ solid short bar ] below
// ══════════════════════════════════════════════════════════════════════════════
class ListViewIcon extends StatelessWidget {
  final Color color;
  final double size;
  const ListViewIcon({super.key, required this.color, this.size = 28});

  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size,
    child: Center(
      child: CustomPaint(
        size: Size(size * 0.92, size * 0.80),
        painter: _ListPainter(color),
      ),
    ),
  );
}

class _ListPainter extends CustomPainter {
  final Color color;
  const _ListPainter(this.color);

  @override
  void paint(Canvas canvas, Size s) {
    const sw = 2.0; // slightly thicker for the "thick border" look
    final st = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = sw
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fl = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // ── Screen (top portion, outlined rounded rect, 1 px inset each side) ──
    const screenInset = 1.0; // makes the screen ~1 px smaller all round
    final screenH = s.height * 0.54;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          sw / 2 + screenInset,
          sw / 2,
          s.width - sw - screenInset * 2,
          screenH - sw,
        ),
        const Radius.circular(2.5), // less round than before
      ),
      st,
    );

    // ── Two bullet rows — slightly narrower than screen, centred ────────────
    const vGap = 1.6;
    final rowH = (s.height - screenH - vGap * 3) / 2;
    final thinRowH = rowH * 0.88; // slightly thinner than full height
    final dotR =
        thinRowH *
        0.64; // bullet circle radius — slightly larger than bar height

    // Row content width = 76 % of painter width (narrower than screen)
    // centred horizontally.
    final rowW = s.width * 0.76;
    final rowLeft = (s.width - rowW) / 2;
    final barX0 = rowLeft + dotR * 2 + 1.5;
    final barX1 = rowLeft + rowW;
    final barR = thinRowH / 2;

    for (var i = 0; i < 2; i++) {
      final rowTop = screenH + vGap + i * (rowH + vGap);
      final cy = rowTop + rowH / 2; // vertically centred within original rowH

      // Filled circle bullet
      canvas.drawCircle(Offset(rowLeft + dotR, cy), dotR, fl);

      // Solid filled rounded bar
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(barX0, cy - thinRowH / 2, barX1 - barX0, thinRowH),
          Radius.circular(barR),
        ),
        fl,
      );
    }
  }

  @override
  bool shouldRepaint(_ListPainter o) => o.color != color;
}

// ══════════════════════════════════════════════════════════════════════════════
// SingleDayViewIcon — timeline icon: 5 hour-mark dots on the left + a single
//   full-height rounded-rect "content area" on the right.  A horizontal line
//   extends from the 3rd (middle) dot across and through the rounded-rect
//   border, clipping a visible hole / negative-space slot through the border.
// ══════════════════════════════════════════════════════════════════════════════
class SingleDayViewIcon extends StatelessWidget {
  final Color color;
  final double size;
  const SingleDayViewIcon({super.key, required this.color, this.size = 28});

  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size,
    child: Center(
      child: CustomPaint(
        // Painter is landscape-ish so the frame (width = s.width − fX − sw,
        // height = s.height − sw) comes out slightly wider than tall.
        size: Size(size * 1.0, size * 0.72),
        painter: _SingleDayPainter(color),
      ),
    ),
  );
}

class _SingleDayPainter extends CustomPainter {
  final Color color;
  const _SingleDayPainter(this.color);

  @override
  void paint(Canvas canvas, Size s) {
    const sw = 1.8; // frame border stroke width
    const lineSw = 1.4; // horizontal line stroke width
    const dotR = 1.2; // sidebar dot radius (reverted)
    const dotV = 1.0; // gap between adjacent dot centres beyond 2*dotR
    const r = 2.5; // frame corner radius
    const holeExtra = 0.8; // extra clearance above/below line in the clip hole
    const rightInset =
        1.0; // trims a little width off the rectangle's right side

    final fill = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // ── Sidebar: 5 hour-mark dots ─────────────────────────────────────────
    // The 3rd dot (index 2) is the centre dot and sits at s.height / 2.
    const dotCX = dotR + 0.5;
    final dotStep = dotR * 2 + dotV;
    final totalDotH = 5 * dotR * 2 + 4 * dotV;
    final dotStartY = (s.height - totalDotH) / 2;

    for (var i = 0; i < 5; i++) {
      canvas.drawCircle(
        Offset(dotCX, dotStartY + i * dotStep + dotR),
        dotR,
        fill,
      );
    }

    final lineY = s.height / 2; // centre of painter = centre of 3rd dot

    // ── Frame geometry ────────────────────────────────────────────────────
    // dotColW gap = dotR*2 + 1.0 → frame sits very close to the dot column.
    const dotColW = dotR * 2 + 0.8;
    const fX = dotCX + dotColW;

    final frameRRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        fX + sw / 2,
        sw / 2,
        s.width - fX - sw - rightInset,
        s.height - sw,
      ),
      const Radius.circular(r),
    );

    // ── Frame border with clip-through slot ───────────────────────────────
    // Hole size is based on sw (frame stroke), NOT lineSw, so the negative
    // space stays the same regardless of how thin the line is.
    final holeHalfH = sw / 2 + holeExtra;

    canvas.saveLayer(Rect.fromLTWH(0, 0, s.width, s.height), Paint());

    canvas.drawRRect(
      frameRRect,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = sw
        ..strokeJoin = StrokeJoin.round,
    );

    canvas.drawRect(
      Rect.fromLTWH(
        fX - sw,
        lineY - holeHalfH,
        s.width - fX + sw * 2,
        holeHalfH * 2,
      ),
      Paint()..blendMode = BlendMode.clear,
    );

    canvas.restore();

    // ── Horizontal line ───────────────────────────────────────────────────
    // Uses lineSw (thinner than sw). Right end extends 0.5 past the frame's
    // right border centre so the rounded cap protrudes slightly beyond the rect.
    canvas.drawLine(
      Offset(dotCX, lineY),
      Offset(s.width - rightInset - sw / 2 + 0.75, lineY),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = lineSw
        ..strokeCap = StrokeCap.round,
    );

    // Redraw the 3rd dot on top so it is fully crisp over the line.
    canvas.drawCircle(Offset(dotCX, lineY), dotR, fill);
  }

  @override
  bool shouldRepaint(_SingleDayPainter o) => o.color != color;
}

// ══════════════════════════════════════════════════════════════════════════════
// MultiDayViewIcon — same dot column + line as SingleDayViewIcon, but the
//   frame is split into TWO tall side-by-side closed rounded rectangles.
//   The horizontal line passes through (and clips a hole in) both borders via
//   the same saveLayer + BlendMode.clear technique. All measurements match
//   the finalised SingleDayViewIcon exactly.
// ══════════════════════════════════════════════════════════════════════════════
class MultiDayViewIcon extends StatelessWidget {
  final Color color;
  final double size;
  const MultiDayViewIcon({super.key, required this.color, this.size = 28});

  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size,
    child: Center(
      child: CustomPaint(
        size: Size(size * 1.0, size * 0.72),
        painter: _MultiDayPainter(color),
      ),
    ),
  );
}

class _MultiDayPainter extends CustomPainter {
  final Color color;
  const _MultiDayPainter(this.color);

  @override
  void paint(Canvas canvas, Size s) {
    // ── Identical constants to _SingleDayPainter ──────────────────────────
    const sw = 1.8;
    const lineSw = 1.4;
    const dotR = 1.2;
    const dotV = 1.0;
    const r = 2.0; // slightly smaller corner radius
    const holeExtra = 0.8;
    const rightInset = 1.0;
    const colGap = 3.0;

    final fill = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // ── Sidebar: 5 hour-mark dots ─────────────────────────────────────────
    const dotCX = dotR + 0.5;
    final dotStep = dotR * 2 + dotV;
    final totalDotH = 5 * dotR * 2 + 4 * dotV;
    final dotStartY = (s.height - totalDotH) / 2;

    for (var i = 0; i < 5; i++) {
      canvas.drawCircle(
        Offset(dotCX, dotStartY + i * dotStep + dotR),
        dotR,
        fill,
      );
    }

    final lineY = s.height / 2;

    // ── Frame geometry — two columns ──────────────────────────────────────
    const dotColW = dotR * 2 + 0.8;
    const fX = dotCX + dotColW;
    final totalFrameW = s.width - fX - sw - rightInset;
    // Left column is wider than right — leftExtra shifts width from right to left.
    const leftExtra = 2.0;
    final baseColW = (totalFrameW - colGap) / 2;
    final leftColW = baseColW + leftExtra;
    final rightColW = baseColW - leftExtra;

    // Left rect — full closed rounded rectangle.
    final leftRRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(fX + sw / 2, sw / 2, leftColW, s.height - sw),
      const Radius.circular(r),
    );

    // Right rect — extends past the painter edge so its right wall is naturally
    // clipped by the saveLayer bounds, producing the "[" appearance.
    final rightRectLeft = fX + sw / 2 + leftColW + colGap;
    final rightRRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        rightRectLeft,
        sw / 2,
        s.width - rightRectLeft + 4.0,
        s.height - sw,
      ),
      const Radius.circular(r),
    );

    // ── Both borders with clip-through slot ───────────────────────────────
    final holeHalfH = sw / 2 + holeExtra;

    canvas.saveLayer(Rect.fromLTWH(0, 0, s.width, s.height), Paint());

    final borderPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = sw
      ..strokeJoin = StrokeJoin.round;

    canvas.drawRRect(leftRRect, borderPaint);
    canvas.drawRRect(rightRRect, borderPaint);

    // Punch hole spanning the full grid width — clips through all vertical walls.
    canvas.drawRect(
      Rect.fromLTWH(
        fX - sw,
        lineY - holeHalfH,
        s.width - fX + sw * 2,
        holeHalfH * 2,
      ),
      Paint()..blendMode = BlendMode.clear,
    );

    canvas.restore();

    // ── Horizontal line from 3rd dot through both columns ────────────────
    canvas.drawLine(
      Offset(dotCX, lineY),
      Offset(s.width - lineSw / 2, lineY),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = lineSw
        ..strokeCap = StrokeCap.round,
    );

    // Redraw 3rd dot on top so it is crisp over the line.
    canvas.drawCircle(Offset(dotCX, lineY), dotR, fill);
  }

  @override
  bool shouldRepaint(_MultiDayPainter o) => o.color != color;
}

// ══════════════════════════════════════════════════════════════════════════════
// DayListViewIcon — uses CupertinoIcons.list_bullet.
// ══════════════════════════════════════════════════════════════════════════════
class DayListViewIcon extends StatelessWidget {
  final Color color;
  final double size;
  const DayListViewIcon({super.key, required this.color, this.size = 28});

  @override
  Widget build(BuildContext context) =>
      Icon(CupertinoIcons.list_bullet, color: color, size: size * 0.82);
}

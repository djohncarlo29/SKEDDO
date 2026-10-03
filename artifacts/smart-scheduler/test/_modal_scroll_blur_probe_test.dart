import 'dart:ui' as ui;

import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

class _StripePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (var x = 0; x < size.width; x++) {
      paint.color = (x ~/ 8).isEven ? const Color(0xFF000000) : const Color(0xFFFFFFFF);
      canvas.drawRect(Rect.fromLTWH(x.toDouble(), 0, 1, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _StripePainter oldDelegate) => false;
}

void main() {
  testWidgets('probe masked and direct backdrop-filter output', (tester) async {
    await tester.binding.setSurfaceSize(const Size(64, 80));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    Future<int> sample({required bool masked}) async {
      final key = GlobalKey();
      final blur = ClipRect(
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 4, sigmaY: 4),
          blendMode: BlendMode.src,
          child: const SizedBox.expand(),
        ),
      );
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: RepaintBoundary(
            key: key,
            child: SizedBox(
              width: 64,
              height: 80,
              child: CustomPaint(
                painter: _StripePainter(),
                child: masked
                    ? ShaderMask(
                      blendMode: BlendMode.dstIn,
                      shaderCallback:
                          (bounds) => const LinearGradient(
                            colors: [Color(0xFFFFFFFF), Color(0xFFFFFFFF)],
                          ).createShader(bounds),
                      child: blur,
                    )
                    : blur,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(key),
      );
      final image = await boundary.toImage(pixelRatio: 1);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      final red = bytes!.getUint8((40 * 64 + 8) * 4);
      image.dispose();
      return red;
    }

    final directRed = await sample(masked: false);
    final fullyMaskedRed = await sample(masked: true);
    // At the sharp stripe boundary, an applied blur must produce an
    // intermediate value instead of the original black or white source pixel.
    // ignore: avoid_print
    print('Backdrop probe red channel: direct=$directRed masked=$fullyMaskedRed');
    expect(directRed, greaterThan(0));
    expect(directRed, lessThan(255));
    expect(fullyMaskedRed, greaterThan(0));
    expect(fullyMaskedRed, lessThan(255));
  });
}
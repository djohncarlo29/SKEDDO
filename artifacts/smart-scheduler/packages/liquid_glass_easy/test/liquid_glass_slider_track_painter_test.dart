import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:liquid_glass_easy/src/widgets/components/slider/liquid_glass_slider_track_painter.dart';

void main() {
  testWidgets('continuous track has rounded caps and no endpoint step', (
    tester,
  ) async {
    const painter = LiquidGlassSliderTrackPainter(
      inactiveColor: Colors.black,
      activeColor: Colors.blue,
      fillEndX: 0,
      trackWidth: 40,
      trackHeight: 6,
      tickStartX: 10,
      tickEndX: 30,
      divisions: 0,
    );
    final image = (await tester.runAsync(
      () => _rasterize(painter, width: 40, height: 6),
    ))!;
    final bytes = (await tester.runAsync(
      () => image.toByteData(format: ui.ImageByteFormat.rawRgba),
    ))!;
    int alphaAt(int x, int y) => bytes.getUint8((y * 40 + x) * 4 + 3);
    expect(alphaAt(0, 0), lessThan(alphaAt(0, 3)));
    expect(alphaAt(39, 0), lessThan(alphaAt(39, 3)));
    expect(alphaAt(0, 3), greaterThan(0));
    expect(alphaAt(39, 3), greaterThan(0));
    image.dispose();

    // Give the track two extra pixels above its bounds. A continuous slider
    // must not paint the legacy left endpoint tick into that area.
    final raisedImage = (await tester.runAsync(
      () => _rasterize(
        painter,
        width: 40,
        height: 10,
        verticalOffset: 2,
      ),
    ))!;
    final raisedBytes = (await tester.runAsync(
      () => raisedImage.toByteData(format: ui.ImageByteFormat.rawRgba),
    ))!;
    expect(raisedBytes.getUint8((0 * 40 + 10) * 4 + 3), 0);
    raisedImage.dispose();
  });

  testWidgets('stepped track reaches both thumb-edge endpoints',
      (tester) async {
    const painter = LiquidGlassSliderTrackPainter(
      inactiveColor: Colors.black,
      activeColor: Colors.blue,
      fillEndX: 20,
      trackWidth: 40,
      trackHeight: 6,
      tickStartX: 10,
      tickEndX: 30,
      divisions: 2,
    );
    final image = (await tester.runAsync(
      () => _rasterize(painter, width: 40, height: 6),
    ))!;
    final bytes = (await tester.runAsync(
      () => image.toByteData(format: ui.ImageByteFormat.rawRgba),
    ))!;
    int alphaAt(int x, int y) => bytes.getUint8((y * 40 + x) * 4 + 3);
    expect(alphaAt(0, 3), greaterThan(0));
    expect(alphaAt(39, 3), greaterThan(0));
    image.dispose();
  });
}

Future<ui.Image> _rasterize(
  LiquidGlassSliderTrackPainter painter, {
  required int width,
  required int height,
  double verticalOffset = 0,
}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  if (verticalOffset != 0) canvas.translate(0, verticalOffset);
  painter.paint(canvas, Size(width.toDouble(), 6));
  final picture = recorder.endRecording();
  final image = await picture.toImage(width, height);
  picture.dispose();
  return image;
}

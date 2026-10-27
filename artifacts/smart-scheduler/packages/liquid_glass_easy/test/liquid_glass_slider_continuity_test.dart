import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:liquid_glass_easy/src/widgets/components/slider/liquid_glass_slider.dart';
import 'package:liquid_glass_easy/src/widgets/components/slider/liquid_glass_slider_track_painter.dart';

void main() {
  testWidgets('track progress reaches both outer endpoints', (tester) async {
    for (final divisions in [0, 6]) {
      for (final value in [0.0, 1.0]) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: LiquidGlassSlider(
                  key: ValueKey('$divisions-$value'),
                  value: value,
                  width: 301,
                  divisions: divisions,
                  onChanged: (_) {},
                ),
              ),
            ),
          ),
        );

        final painter = tester
            .widget<CustomPaint>(
              find.byWidgetPredicate(
                (widget) =>
                    widget is CustomPaint &&
                    widget.painter is LiquidGlassSliderTrackPainter,
              ),
            )
            .painter! as LiquidGlassSliderTrackPainter;

        expect(
          painter.fillEndX,
          closeTo(value == 0 ? 0 : painter.trackWidth, 0.001),
          reason: 'divisions=$divisions, value=$value',
        );
      }
    }
  });

  testWidgets('continuous slider reports each drag value without snapping', (
    tester,
  ) async {
    final values = <double>[];
    double? changeEnd;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: LiquidGlassSlider(
              value: 0.5,
              width: 301,
              divisions: 0,
              isContinuous: true,
              onChanged: values.add,
              onChangeEnd: (value) => changeEnd = value,
            ),
          ),
        ),
      ),
    );

    final sliderRect = tester.getRect(find.byType(LiquidGlassSlider));
    final gesture = await tester.startGesture(sliderRect.center);
    await gesture.moveBy(const Offset(37, 0));
    await tester.pump();
    await gesture.moveBy(const Offset(-80, 0));
    await tester.pump();
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 250));

    expect(values, hasLength(greaterThanOrEqualTo(2)));
    expect(values.first, greaterThan(0.5));
    expect(values[1], lessThan(values.first));
    expect(values[1], lessThan(0.5));
    expect(changeEnd, values.last);
    expect(
      changeEnd,
      isNot(closeTo((changeEnd! * 100).round() / 100, 0.0001)),
    );
  });

  testWidgets('edge icons push outward as the thumb reaches either extreme', (
    tester,
  ) async {
    const minimumIconPositionKey = ValueKey(
      'liquid-glass-slider-minimum-icon-position',
    );
    const maximumIconPositionKey = ValueKey(
      'liquid-glass-slider-maximum-icon-position',
    );

    Widget buildSlider(double value) => MaterialApp(
      home: Scaffold(
        body: Center(
          child: LiquidGlassSlider(
            value: value,
            width: 301,
            layout: const LiquidGlassSliderLayout(
              iconSize: 34,
              iconGap: 8,
              horizontalInset: 0,
            ),
            minimumIcon: const SizedBox(width: 34, height: 34),
            maximumIcon: const SizedBox(width: 34, height: 34),
            onChanged: (_) {},
          ),
        ),
      ),
    );

    double iconLeft(Key key) =>
        tester.widget<Positioned>(find.byKey(key)).left!;

    await tester.pumpWidget(buildSlider(0.5));
    expect(iconLeft(minimumIconPositionKey), 0);
    expect(iconLeft(maximumIconPositionKey), 267);

    // The existing end-pressure zone is 5% of the track and reaches a
    // 10px outward push exactly at either extreme.
    await tester.pumpWidget(buildSlider(0.025));
    expect(iconLeft(minimumIconPositionKey), -5);
    await tester.pumpWidget(buildSlider(0));
    expect(iconLeft(minimumIconPositionKey), -10);

    await tester.pumpWidget(buildSlider(0.975));
    expect(iconLeft(maximumIconPositionKey), 272);
    await tester.pumpWidget(buildSlider(1));
    expect(iconLeft(maximumIconPositionKey), 277);
  });
}

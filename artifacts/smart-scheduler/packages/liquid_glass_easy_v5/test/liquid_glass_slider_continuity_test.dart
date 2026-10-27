import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:liquid_glass_easy/src/widgets/components/slider/liquid_glass_slider.dart';
import 'package:liquid_glass_easy/src/widgets/lens/liquid_glass_lens.dart';

void main() {
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

  testWidgets('edge icons follow the lifted thumb through end bounce', (
    tester,
  ) async {
    for (final isMinimum in [true, false]) {
      final iconKey = ValueKey(
        isMinimum ? 'minimum-edge-icon' : 'maximum-edge-icon',
      );
      final startValue = isMinimum ? 0.0 : 1.0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: LiquidGlassSlider(
                key: ValueKey('slider-$isMinimum'),
                value: startValue,
                width: 301,
                layout: const LiquidGlassSliderLayout(
                  iconSize: 34,
                  iconGap: 8,
                  horizontalInset: 0,
                ),
                minimumIcon: SizedBox(
                  key: isMinimum ? iconKey : null,
                  width: 34,
                  height: 34,
                ),
                maximumIcon: SizedBox(
                  key: isMinimum ? null : iconKey,
                  width: 34,
                  height: 34,
                ),
                onChanged: (_) {},
              ),
            ),
          ),
        ),
      );

      final sliderRect = tester.getRect(find.byType(LiquidGlassSlider));
      final thumbCenterX = isMinimum ? 60.5 : 240.5;
      final gesture = await tester.startGesture(
        Offset(sliderRect.left + thumbCenterX, sliderRect.center.dy),
      );
      await tester.pump();
      for (var frame = 0; frame < 32; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
      }

      Rect iconRect() => tester.getRect(find.byKey(iconKey));
      Rect thumbRect() => tester.getRect(find.byType(LiquidGlassLens));
      double edgeGap() {
        final icon = iconRect();
        final thumb = thumbRect();
        return isMinimum ? thumb.left - icon.right : icon.left - thumb.right;
      }

      expect(edgeGap(), closeTo(4, 0.5));

      await gesture.moveBy(Offset(isMinimum ? -30 : 30, 0));
      await tester.pump();
      for (var frame = 0; frame < 4; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(edgeGap(), closeTo(4, 0.5));

      await gesture.up();
      await tester.pump();
      for (var frame = 0; frame < 50; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(
        isMinimum ? iconRect().left : iconRect().right,
        closeTo(isMinimum ? sliderRect.left : sliderRect.right, 0.5),
      );
    }
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:liquid_glass_easy/src/widgets/components/slider/liquid_glass_slider.dart';

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
}

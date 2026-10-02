import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_scheduler/widgets/wheel_option_text.dart';

void main() {
  testWidgets('shrinks long labels for OS scale and wheel magnification', (
    tester,
  ) async {
    const width = 132.0;
    const magnification = 2.35 / 2.1;
    const label = 'weekend day';
    const selectionInsets = EdgeInsetsDirectional.symmetric(horizontal: 6.5);

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: MediaQuery(
          data: MediaQueryData(
            size: const Size(400, 800),
            textScaler: TextScaler.linear(2.0),
          ),
          child: Center(
            child: SizedBox(
              width: width,
              child: const WheelOptionText(
                text: label,
                style: TextStyle(fontSize: 16),
                magnification: magnification,
                selectionInsets: selectionInsets,
              ),
            ),
          ),
        ),
      ),
    );

    final fitBoxWidth = tester.getSize(find.byType(FittedBox)).width;
    final textWidth = tester.getSize(find.text(label)).width;
    final text = tester.widget<Text>(find.text(label));

    expect(fitBoxWidth * magnification, closeTo(width - 13, 0.01));
    expect(textWidth, greaterThan(fitBoxWidth));
    expect(text.maxLines, 1);
    expect(text.softWrap, isFalse);
    expect(text.overflow, isNull);
  });

  testWidgets('keeps short labels at their normal size when they fit', (
    tester,
  ) async {
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: MediaQuery(
          data: const MediaQueryData(
            size: Size(400, 800),
            textScaler: TextScaler.noScaling,
          ),
          child: const Center(
            child: SizedBox(
              width: 200,
              child: WheelOptionText(
                text: 'Wed',
                style: TextStyle(fontSize: 16),
                magnification: 2.35 / 2.1,
                selectionInsets: EdgeInsetsDirectional.symmetric(
                  horizontal: 6.5,
                ),
              ),
            ),
          ),
        ),
      ),
    );

    final fitBoxWidth = tester.getSize(find.byType(FittedBox)).width;
    final textWidth = tester.getSize(find.text('Wed')).width;
    expect(textWidth, lessThan(fitBoxWidth));
  });
}

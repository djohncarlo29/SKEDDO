import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_scheduler/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'calendar indicators keep their circle-to-number ratio at each text size',
    (tester) async {
      const calendarCircle = 36.0;
      const calendarFont = 17.0;
      const pickerCircle = 30.0;
      const pickerFont = 15.0;

      for (final scale in <double>[0.85, 1.0, 1.30, 1.60]) {
        var calendarRatio = 0.0;
        var pickerRatio = 0.0;
        var yearViewScale = 0.0;
        var pickerItemExtent = 0.0;
        var pickerHeight = 0.0;
        var expectedPickerItemExtent = 0.0;
        var expectedPickerHeight = 0.0;
        await tester.pumpWidget(
          MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(scale)),
            child: Builder(
              builder: (context) {
                final scaler = MediaQuery.textScalerOf(context);
                final calendarSize =
                    calendarCircle * textScaleRatioFor(context, calendarFont);
                final pickerSize =
                    pickerCircle * textScaleRatioFor(context, pickerFont);
                final yearViewScaler =
                    scaler.clamp(maxScaleFactor: 1.0);
                calendarRatio =
                    calendarSize / scaler.scale(calendarFont);
                pickerRatio = pickerSize / scaler.scale(pickerFont);
                yearViewScale = yearViewScaler.scale(calendarFont) /
                    calendarFont;
                pickerItemExtent =
                    cupertinoDatePickerItemExtent(context);
                pickerHeight = cupertinoDatePickerHeight(context);
                expectedPickerItemExtent =
                    scaler.scale(kCupertinoDatePickerItemExtent);
                expectedPickerHeight = scaler.scale(kCupertinoDatePickerHeight);
                return const SizedBox.shrink();
              },
            ),
          ),
        );

        expect(calendarRatio, closeTo(calendarCircle / calendarFont, 0.000001));
        expect(pickerRatio, closeTo(pickerCircle / pickerFont, 0.000001));
        expect(yearViewScale, closeTo(scale > 1.0 ? 1.0 : scale, 0.000001));
        expect(
          pickerItemExtent,
          closeTo(expectedPickerItemExtent, 0.000001),
        );
        expect(
          pickerHeight,
          closeTo(expectedPickerHeight, 0.000001),
        );
      }
    },
  );
}
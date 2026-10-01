import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_scheduler/widgets/cupertino_date_picker_with_full_width_selection.dart';

void main() {
  testWidgets('landscape date wheels distribute across the available width', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      CupertinoApp(
        home: Center(
          child: SizedBox(
            width: 900,
            height: 216,
            child: CupertinoDatePickerWithFullWidthSelection(
              itemExtent: 32,
              initialDateTime: DateTime(2026, 10, 1),
              onDateTimeChanged: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final month = tester.getRect(
      find.byKey(const ValueKey('wide-date-month-column')),
    );
    final day = tester.getRect(
      find.byKey(const ValueKey('wide-date-day-column')),
    );
    final year = tester.getRect(
      find.byKey(const ValueKey('wide-date-year-column')),
    );

    expect(month.width, closeTo(300, 1));
    expect(day.width, closeTo(300, 1));
    expect(year.width, closeTo(300, 1));
    expect(day.center.dx - month.center.dx, closeTo(300, 1));
    expect(year.center.dx - day.center.dx, closeTo(300, 1));
  });

  testWidgets('landscape date wheels keep the selected date valid', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    DateTime? changedDate;
    await tester.pumpWidget(
      CupertinoApp(
        home: Center(
          child: SizedBox(
            width: 900,
            height: 216,
            child: CupertinoDatePickerWithFullWidthSelection(
              itemExtent: 32,
              initialDateTime: DateTime(2026, 1, 31),
              minimumDate: DateTime(2026, 1, 1),
              onDateTimeChanged: (date) => changedDate = date,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final monthPicker = tester.widget<CupertinoPicker>(
      find.byKey(const ValueKey('wide-date-month-column')),
    );
    monthPicker.scrollController!.jumpToItem(1);
    await tester.pump();
    await tester.pumpAndSettle();

    expect(changedDate, DateTime(2026, 2, 28));
  });
}

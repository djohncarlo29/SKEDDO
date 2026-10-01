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

  testWidgets('landscape date wheel labels match portrait alignment', (
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

    final monthColumn = tester.getRect(
      find.byKey(const ValueKey('wide-date-month-column')),
    );
    final dayColumn = tester.getRect(
      find.byKey(const ValueKey('wide-date-day-column')),
    );
    final yearColumn = tester.getRect(
      find.byKey(const ValueKey('wide-date-year-column')),
    );
    final monthLabel = tester.getRect(find.text('October'));
    final dayLabel = tester.getRect(find.text('1'));
    final yearLabel = tester.getRect(find.text('2026'));

    expect(monthLabel.left, closeTo(monthColumn.left + 12, 1));
    expect(dayLabel.right, closeTo(dayColumn.right - 12, 1));
    expect(yearLabel.right, closeTo(yearColumn.right - 12, 1));
  });

  testWidgets('landscape date wheels dim and reject dates before the minimum', (
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
              initialDateTime: DateTime(2026, 10, 15),
              minimumDate: DateTime(2026, 10, 15),
              onDateTimeChanged: (date) => changedDate = date,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final invalidDayFinder = find.text('14');
    final invalidMonthFinder = find.text('September');
    final invalidYearFinder = find.text('2025');
    final inactiveGray = CupertinoDynamicColor.resolve(
      CupertinoColors.inactiveGray,
      tester.element(invalidDayFinder),
    );

    expect(tester.widget<Text>(invalidDayFinder).style?.color, inactiveGray);
    expect(
      tester.widget<Text>(invalidMonthFinder).style?.color,
      CupertinoDynamicColor.resolve(
        CupertinoColors.inactiveGray,
        tester.element(invalidMonthFinder),
      ),
    );
    expect(
      tester.widget<Text>(invalidYearFinder).style?.color,
      CupertinoDynamicColor.resolve(
        CupertinoColors.inactiveGray,
        tester.element(invalidYearFinder),
      ),
    );

    final dayPicker = tester.widget<CupertinoPicker>(
      find.byKey(const ValueKey('wide-date-day-column')),
    );
    dayPicker.scrollController!.jumpToItem(13);
    await tester.pump();
    await tester.pumpAndSettle();
    expect(dayPicker.scrollController!.selectedItem, 14);
    expect(changedDate, isNull);

    final monthPicker = tester.widget<CupertinoPicker>(
      find.byKey(const ValueKey('wide-date-month-column')),
    );
    monthPicker.scrollController!.jumpToItem(8);
    await tester.pump();
    await tester.pumpAndSettle();
    expect(monthPicker.scrollController!.selectedItem, 9);
    expect(changedDate, isNull);

    final yearPicker = tester.widget<CupertinoPicker>(
      find.byKey(const ValueKey('wide-date-year-column')),
    );
    yearPicker.scrollController!.jumpToItem(2024);
    await tester.pump();
    await tester.pumpAndSettle();
    expect(yearPicker.scrollController!.selectedItem, 2025);
    expect(changedDate, isNull);
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

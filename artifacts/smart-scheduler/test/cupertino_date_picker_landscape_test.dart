import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_scheduler/widgets/cupertino_date_picker_with_full_width_selection.dart';

void main() {
  testWidgets('landscape date wheels use the full selection-bar width', (
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
    final group = tester.getRect(
      find.byKey(const ValueKey('wide-date-picker-column-group')),
    );

    expect(group.center.dx, closeTo(600, 1));
    expect(group.width, closeTo(900, 1));
    expect(month.width, closeTo(300, 1));
    expect(day.width, closeTo(300, 1));
    expect(year.width, closeTo(300, 1));
    expect(day.left, closeTo(month.right, 1));
    expect(year.left, closeTo(day.right, 1));
  });

  testWidgets(
    'landscape date wheel columns retain full width at larger OS text sizes',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 600);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      Future<List<Rect>> columnRectsAtScale(double scale) async {
        await tester.pumpWidget(
          CupertinoApp(
            home: MediaQuery(
              data: MediaQueryData(
                size: const Size(1200, 600),
                devicePixelRatio: 1,
                textScaler: TextScaler.linear(scale),
              ),
              child: Center(
                child: SizedBox(
                  width: 900,
                  height: 216 * scale,
                  child: CupertinoDatePickerWithFullWidthSelection(
                    itemExtent: 32 * scale,
                    initialDateTime: DateTime(2026, 10, 1),
                    onDateTimeChanged: (_) {},
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final group = tester.getRect(
          find.byKey(const ValueKey('wide-date-picker-column-group')),
        );
        expect(group.center.dx, closeTo(600, 1));
        expect(group.width, closeTo(900, 1));
        return [
          tester.getRect(find.byKey(const ValueKey('wide-date-month-column'))),
          tester.getRect(find.byKey(const ValueKey('wide-date-day-column'))),
          tester.getRect(find.byKey(const ValueKey('wide-date-year-column'))),
        ];
      }

      final defaultRects = await columnRectsAtScale(1);
      final largerTextRects = await columnRectsAtScale(1.8);

      for (var index = 0; index < 3; index++) {
        expect(defaultRects[index].width, closeTo(300, 1));
        expect(largerTextRects[index].width, closeTo(300, 1));
      }
    },
  );

  testWidgets('portrait keeps the native Cupertino date picker layout', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(600, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      CupertinoApp(
        home: Center(
          child: SizedBox(
            width: 390,
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

    expect(find.byType(CupertinoDatePicker), findsOneWidget);
    expect(
      find.byKey(const ValueKey('wide-date-picker-column-group')),
      findsNothing,
    );
  });

  testWidgets('landscape date wheel labels stay inside their columns', (
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

    expect(monthLabel.left, greaterThanOrEqualTo(monthColumn.left + 7));
    expect(monthLabel.right, lessThanOrEqualTo(monthColumn.right - 7));
    expect(dayLabel.left, greaterThanOrEqualTo(dayColumn.left + 7));
    expect(dayLabel.right, lessThanOrEqualTo(dayColumn.right - 7));
    expect(yearLabel.left, greaterThanOrEqualTo(yearColumn.left + 7));
    expect(yearLabel.right, lessThanOrEqualTo(yearColumn.right - 7));
  });

  testWidgets('landscape date labels shrink to fit narrow columns', (
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
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(1200, 600),
            devicePixelRatio: 1,
            textScaler: TextScaler.linear(2),
          ),
          child: Center(
            child: SizedBox(
              width: 240,
              height: 216,
              child: CupertinoDatePickerWithFullWidthSelection(
                itemExtent: 32,
                initialDateTime: DateTime(2026, 10, 1),
                onDateTimeChanged: (_) {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final monthColumn = tester.getRect(
      find.byKey(const ValueKey('wide-date-month-column')),
    );
    final monthLabel = tester.getRect(find.text('October'));

    expect(monthColumn.width, closeTo(80, 1));
    expect(monthLabel.left, greaterThanOrEqualTo(monthColumn.left + 7));
    expect(monthLabel.right, lessThanOrEqualTo(monthColumn.right - 7));
  });

  testWidgets('disabled values pass through, then return', (tester) async {
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
    expect(dayPicker.scrollController!.selectedItem, 13);
    expect(changedDate, isNull);
    await tester.pumpAndSettle();
    expect(dayPicker.scrollController!.selectedItem, 14);
    expect(changedDate, DateTime(2026, 10, 15));

    changedDate = null;
    final monthPicker = tester.widget<CupertinoPicker>(
      find.byKey(const ValueKey('wide-date-month-column')),
    );
    monthPicker.scrollController!.jumpToItem(8);
    await tester.pump();
    expect(monthPicker.scrollController!.selectedItem, 8);
    expect(changedDate, isNull);
    await tester.pumpAndSettle();
    expect(monthPicker.scrollController!.selectedItem, 9);
    expect(changedDate, DateTime(2026, 10, 15));

    changedDate = null;
    final yearPicker = tester.widget<CupertinoPicker>(
      find.byKey(const ValueKey('wide-date-year-column')),
    );
    yearPicker.scrollController!.jumpToItem(2024);
    await tester.pump();
    expect(yearPicker.scrollController!.selectedItem, 2024);
    expect(changedDate, isNull);
    await tester.pumpAndSettle();
    expect(yearPicker.scrollController!.selectedItem, 2025);
    expect(changedDate, DateTime(2026, 10, 15));
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

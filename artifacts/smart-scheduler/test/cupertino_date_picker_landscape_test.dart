import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_scheduler/widgets/cupertino_date_picker_with_full_width_selection.dart';

void main() {
  testWidgets('landscape date wheels stay grouped and centered', (
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
    expect(group.width, greaterThan(0));
    expect(group.width, lessThan(600));
    expect(day.center.dx - month.center.dx, lessThan(180));
    expect(year.center.dx - day.center.dx, lessThan(180));
    expect(month.width, lessThan(260));
    expect(day.width, lessThan(260));
    expect(year.width, lessThan(260));
  });

  testWidgets(
    'landscape wheel group scales with OS text size without filling the screen',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 600);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      Future<double> groupWidthAtScale(double scale) async {
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
        expect(group.width, lessThan(900));
        return group.width;
      }

      final defaultWidth = await groupWidthAtScale(1);
      final largerTextWidth = await groupWidthAtScale(1.8);

      expect(largerTextWidth, greaterThan(defaultWidth));
      expect(largerTextWidth, lessThan(700));
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

  testWidgets('portrait native date labels apply text scaling exactly once', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(600, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    Future<double> monthFontSizeAtScale(double scale) async {
      await tester.pumpWidget(
        CupertinoApp(
          home: MediaQuery(
            data: MediaQueryData(
              size: const Size(600, 1200),
              devicePixelRatio: 1,
              textScaler: TextScaler.linear(scale),
            ),
            child: Builder(
              builder: (context) {
                final theme = CupertinoTheme.of(context);
                return CupertinoTheme(
                  data: theme.copyWith(
                    textTheme: theme.textTheme.copyWith(
                      dateTimePickerTextStyle: const TextStyle(
                        inherit: false,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  child: Center(
                    child: SizedBox(
                      width: 390,
                      height: 216 * scale,
                      child: CupertinoDatePickerWithFullWidthSelection(
                        itemExtent: 32 * scale,
                        initialDateTime: DateTime(2026, 10, 1),
                        onDateTimeChanged: (_) {},
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final month = tester.widget<Text>(find.text('October').first);
      return month.style!.fontSize!;
    }

    expect(await monthFontSizeAtScale(1), closeTo(16, 0.01));
    expect(await monthFontSizeAtScale(1.8), closeTo(16 * 1.8, 0.01));
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

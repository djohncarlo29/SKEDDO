import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_scheduler/app_theme.dart';
import 'package:smart_scheduler/tabs/calendar_tab.dart';
import 'package:smart_scheduler/widgets/app_window_content_boundary.dart';
import 'package:smart_scheduler/widgets/app_header_scroll_edge.dart';
import 'package:smart_scheduler/widgets/view_mode_icons.dart';

void main() {
  testWidgets(
    'portrait Day View places DOW, week strip, banner, and timeline in order',
    (tester) async {
      const screenSize = Size(402, 874);
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = screenSize;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        CupertinoApp(
          builder: (context, child) {
            final mediaQuery = MediaQuery.of(context).copyWith(
              size: screenSize,
            );
            return MediaQuery(
              data: mediaQuery,
              child: AppWindowContentBoundary(
                child: child ?? const SizedBox.shrink(),
              ),
            );
          },
          home: CupertinoPageScaffold(
                 child: CalendarTab(onViewChanged: (_, _, _, _, _, _) {}),
          ),
        ),
      );
      await tester.pumpAndSettle();

      tester
          .state<CalendarTabState>(find.byType(CalendarTab))
          .jumpToTodayDay();
      await tester.pumpAndSettle();

      final dowMask = find.byWidgetPredicate(
        (widget) => widget.runtimeType.toString() == '_DayViewDowMask',
      );
      final banners = find.byWidgetPredicate(
        (widget) => widget.runtimeType.toString() == '_DayBanner',
      );
      final timelines = find.byWidgetPredicate(
        (widget) => widget.runtimeType.toString() == '_DayTimeline',
      );
      expect(dowMask, findsOneWidget);
      expect(banners, findsNWidgets(3));
      expect(timelines, findsNWidgets(3));

      final dowRect = tester.getRect(dowMask);
      final selectedWeek = _selectedWeekRow(DateTime.now());
      final centerBannerRect = tester.getRect(banners.at(1));
      final centerTimelineRect = tester.getRect(timelines.at(1));
      expect(selectedWeek, findsOneWidget);
      final selectedWeekRect = tester.getRect(selectedWeek);
      const weekStripHeight = 52.0;

      expect(
        dowRect.top,
        closeTo(kAppHeaderTitleHeight - kContentAreaTopRaise, 0.5),
      );
      expect(selectedWeekRect.top, closeTo(dowRect.bottom, 0.5));
      expect(selectedWeekRect.bottom, closeTo(centerBannerRect.top, 0.5));
      expect(
        centerBannerRect.top,
        closeTo(dowRect.bottom + weekStripHeight, 0.5),
      );
      expect(centerTimelineRect.top, closeTo(centerBannerRect.bottom, 0.5));
    },
  );

  testWidgets('portrait Multi Day header uses the raised content edge', (
    tester,
  ) async {
    const screenSize = Size(402, 874);
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = screenSize;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      CupertinoApp(
        builder: (context, child) {
          final mediaQuery = MediaQuery.of(context).copyWith(size: screenSize);
          return MediaQuery(
            data: mediaQuery,
            child: AppWindowContentBoundary(
              child: child ?? const SizedBox.shrink(),
            ),
          );
        },
        home: CupertinoPageScaffold(
          child: CalendarTab(
            daySubMode: DayViewSubMode.multiDay,
            onViewChanged: (_, _, _, _, _, _) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    tester.state<CalendarTabState>(find.byType(CalendarTab)).jumpToTodayDay();
    await tester.pumpAndSettle();

    final dowMask = find.byWidgetPredicate(
      (widget) => widget.runtimeType.toString() == '_DayViewDowMask',
    );
    final banners = find.byWidgetPredicate(
      (widget) => widget.runtimeType.toString() == '_DayBanner',
    );
    expect(banners, findsOneWidget);
    final centerBanner = banners.first;
    final dowRect = tester.getRect(dowMask);
    final selectedWeek = _selectedWeekRow(DateTime.now());
    expect(selectedWeek, findsOneWidget);
    final selectedWeekRect = tester.getRect(selectedWeek);
    expect(
      dowRect.top,
      closeTo(kAppHeaderTitleHeight - kContentAreaTopRaise, 0.5),
    );
    expect(selectedWeekRect.top, closeTo(dowRect.bottom, 0.5));
    expect(
      selectedWeekRect.bottom,
      closeTo(tester.getRect(centerBanner).top, 0.5),
    );
    expect(
      tester.getRect(centerBanner).top,
      greaterThan(dowRect.bottom),
    );
  });

  testWidgets(
    'Multi Day timeline separator reverses with its Day Banner separator',
    (tester) async {
      const screenSize = Size(402, 874);
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = screenSize;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      var daySubMode = DayViewSubMode.singleDay;
      late StateSetter setParentState;
      await tester.pumpWidget(
        CupertinoApp(
          builder: (context, child) {
            final mediaQuery = MediaQuery.of(context).copyWith(
              size: screenSize,
            );
            return MediaQuery(
              data: mediaQuery,
              child: AppWindowContentBoundary(
                child: child ?? const SizedBox.shrink(),
              ),
            );
          },
          home: StatefulBuilder(
            builder: (context, setState) {
              setParentState = setState;
              return CupertinoPageScaffold(
                child: CalendarTab(
                  daySubMode: daySubMode,
                  onViewChanged: (_, _, _, _, _, _) {},
                ),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      final calendarState = tester.state<CalendarTabState>(
        find.byType(CalendarTab),
      );
      calendarState.jumpToTodayDay();
      await tester.pumpAndSettle();

      setParentState(() {
        daySubMode = DayViewSubMode.multiDay;
      });
      await tester.pumpAndSettle();

      final timelineSeparator = find.byKey(
        const Key('calendar-multiday-left-separator'),
      );
      Finder centerBannerSeparator() {
        final banners = find.byWidgetPredicate(
          (widget) => widget.runtimeType.toString() == '_DayBanner',
        );
        final centerIndex = banners.evaluate().length == 1 ? 0 : 1;
        return find.descendant(
          of: banners.at(centerIndex),
          matching: find.byKey(
            const Key('calendar-multiday-banner-left-separator'),
          ),
        );
      }
      expect(timelineSeparator, findsOneWidget);
      expect(centerBannerSeparator(), findsOneWidget);
      final settledX = tester.getRect(timelineSeparator).left;

      setParentState(() {
        daySubMode = DayViewSubMode.singleDay;
      });
      await tester.pump();
      expect(timelineSeparator, findsOneWidget);
      expect(centerBannerSeparator(), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 160));
      final timelineX = tester.getRect(timelineSeparator).left;
      final bannerX = tester.getRect(centerBannerSeparator()).left;
      expect(timelineX, lessThan(settledX));
      expect(timelineX, closeTo(bannerX, 1.0));

      await tester.pumpAndSettle();
      expect(timelineSeparator, findsNothing);
    },
  );

  testWidgets(
    'List Day View moves the selected week strip above the physical viewport',
    (tester) async {
      const screenSize = Size(402, 874);
      const headerInset = 68.0;
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = screenSize;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        CupertinoApp(
          builder: (context, child) {
            final mediaQuery = MediaQuery.of(context).copyWith(
              size: screenSize,
            );
            return MediaQuery(
              data: mediaQuery,
              child: AppHeaderScrollInsetScope(
                leadingInset: headerInset,
                child: AppWindowContentBoundary(
                  child: Padding(
                    padding: const EdgeInsets.only(top: headerInset),
                    child: child ?? const SizedBox.shrink(),
                  ),
                ),
              ),
            );
          },
          home: CupertinoPageScaffold(
            child: CalendarTab(
              daySubMode: DayViewSubMode.list,
              onViewChanged: (_, _, _, _, _, _) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      tester.state<CalendarTabState>(find.byType(CalendarTab)).jumpToTodayDay();
      await tester.pumpAndSettle();

      final today = DateTime.now();
      final firstWeekday = DateTime(today.year, today.month, 1).weekday - 1;
      final selectedWeekRow = (today.day + firstWeekday - 1) ~/ 7;
      final weekRows = find.byWidgetPredicate(
        (widget) => widget.runtimeType.toString() == '_WeekRow',
      );
      expect(weekRows, findsWidgets);
      final selectedWeekIndex = weekRows.evaluate().toList().indexWhere((
        element,
      ) {
        final dynamic row = element.widget;
        return row.year == today.year &&
            row.month == today.month &&
            row.selectedDate.year == today.year &&
            row.selectedDate.month == today.month &&
            row.selectedDate.day == today.day &&
            row.row == selectedWeekRow;
      });
      expect(selectedWeekIndex, greaterThanOrEqualTo(0));
      final selectedWeek = weekRows.at(selectedWeekIndex);
      expect(
        tester.getRect(selectedWeek).bottom,
        lessThanOrEqualTo(0.5),
        reason: 'List Day View must not leave dates peeking into the status bar.',
      );
    },
  );
}

Finder _selectedWeekRow(DateTime date) {
  final firstWeekday = DateTime(date.year, date.month, 1).weekday - 1;
  final selectedRow = (date.day + firstWeekday - 1) ~/ 7;
  return find.byWidgetPredicate((widget) {
    if (widget.runtimeType.toString() != '_WeekRow') return false;
    final dynamic row = widget;
    final DateTime selectedDate = row.selectedDate;
    return row.year == date.year &&
        row.month == date.month &&
        selectedDate.year == date.year &&
        selectedDate.month == date.month &&
        selectedDate.day == date.day &&
        row.row == selectedRow;
  });
}

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_scheduler/app_theme.dart';
import 'package:smart_scheduler/tabs/calendar_tab.dart';
import 'package:smart_scheduler/widgets/app_window_content_boundary.dart';
import 'package:smart_scheduler/widgets/view_mode_icons.dart';

Widget _landscapeCalendarHarness({
  required Size screenSize,
  required double horizontalSafeInset,
  DayViewSubMode daySubMode = DayViewSubMode.singleDay,
}) {
  return CupertinoApp(
    builder: (context, child) {
      final mediaQuery = MediaQuery.of(context).copyWith(
        size: screenSize,
        padding: EdgeInsets.only(left: horizontalSafeInset),
        viewPadding: EdgeInsets.only(left: horizontalSafeInset),
      );
      return MediaQuery(
        data: mediaQuery,
        child: AppWindowContentBoundary(
          child: child ?? const SizedBox.shrink(),
        ),
      );
    },
    home: CupertinoPageScaffold(
      child: CalendarTab(
        daySubMode: daySubMode,
        onViewChanged: (view, _, _, _, _) {},
      ),
    ),
  );
}

void _expectCurrentTimeCenteredAboveFloatingBar(
  WidgetTester tester,
  Finder timeline,
) {
  final timelineRect = tester.getRect(timeline);
  final bottomClearance = floatingTabBarContentBottomClearance(
    tester.element(timeline),
  );
  final visibleHeight = timelineRect.height - bottomClearance;
  final indicator = find.descendant(
    of: timeline,
    matching: find.byKey(const Key('calendar-current-time-indicator')),
  );
  expect(indicator, findsOneWidget);
  expect(
    tester.getCenter(indicator).dy,
    closeTo(timelineRect.top + visibleHeight / 2, 4),
  );
}

Future<void> _beginMultiDayEntrance(
  WidgetTester tester, {
  required Size screenSize,
  required bool todayOnRight,
}) async {
  const horizontalSafeInset = 28.0;
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = screenSize;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    _landscapeCalendarHarness(
      screenSize: screenSize,
      horizontalSafeInset: horizontalSafeInset,
    ),
  );
  await tester.pumpAndSettle();
  final calendar = tester.state<CalendarTabState>(find.byType(CalendarTab));
  calendar.navigateUp();
  await tester.pumpAndSettle();
  if (todayOnRight) {
    calendar.navigatePrev();
    await tester.pumpAndSettle();
  }

  await tester.pumpWidget(
    _landscapeCalendarHarness(
      screenSize: screenSize,
      horizontalSafeInset: horizontalSafeInset,
      daySubMode: DayViewSubMode.multiDay,
    ),
  );
}

void main() {
  testWidgets(
    'landscape Year View keeps full-width panels and insets month grids',
    (tester) async {
      const screenSize = Size(844, 390);
      const horizontalSafeInset = 28.0;
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = screenSize;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      CalendarView? visibleView;
      await tester.pumpWidget(
        CupertinoApp(
          builder: (context, child) {
            final mediaQuery = MediaQuery.of(context).copyWith(
              size: screenSize,
              padding: const EdgeInsets.only(left: horizontalSafeInset),
              viewPadding: const EdgeInsets.only(left: horizontalSafeInset),
            );
            return MediaQuery(
              data: mediaQuery,
              child: AppWindowContentBoundary(
                child: child ?? const SizedBox.shrink(),
              ),
            );
          },
          home: CupertinoPageScaffold(
            child: CalendarTab(
              onViewChanged:
                  (view, displayYear, previousTitle, title, nextTitle) {
                    visibleView = view;
                  },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      tester.state<CalendarTabState>(find.byType(CalendarTab)).navigateDown();
      await tester.pumpAndSettle();
      expect(visibleView, CalendarView.year);

      final monthGrids = find.byWidgetPredicate(
        (widget) => widget.runtimeType.toString() == '_MiniMonthGrid',
      );
      expect(monthGrids, findsWidgets);

      final visibleGridRects = <Rect>[];
      for (var index = 0; index < monthGrids.evaluate().length; index++) {
        final rect = tester.getRect(monthGrids.at(index));
        if (rect.right > 0 && rect.left < screenSize.width) {
          visibleGridRects.add(rect);
        }
      }
      expect(visibleGridRects, hasLength(12));
      for (final rect in visibleGridRects) {
        expect(rect.left, greaterThanOrEqualTo(horizontalSafeInset + 15.5));
        expect(
          rect.right,
          lessThanOrEqualTo(screenSize.width - horizontalSafeInset - 15.5),
        );
      }

      final yearViewports = find.byType(SingleChildScrollView);
      var foundFullWidthYearViewport = false;
      for (var index = 0; index < yearViewports.evaluate().length; index++) {
        final rect = tester.getRect(yearViewports.at(index));
        if (rect.left.abs() < 1.0 &&
            (rect.width - screenSize.width).abs() < 1.0) {
          foundFullWidthYearViewport = true;
          break;
        }
      }
      expect(foundFullWidthYearViewport, isTrue);
    },
  );

  testWidgets(
    'landscape Day View keeps full-width panels and lines through Month transition',
    (tester) async {
      const screenSize = Size(844, 390);
      const horizontalSafeInset = 28.0;
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = screenSize;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        _landscapeCalendarHarness(
          screenSize: screenSize,
          horizontalSafeInset: horizontalSafeInset,
        ),
      );
      await tester.pumpAndSettle();

      tester.state<CalendarTabState>(find.byType(CalendarTab)).navigateUp();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final timelines = find.byWidgetPredicate(
        (widget) => widget.runtimeType.toString() == '_DayTimeline',
      );
      expect(timelines, findsNWidgets(3));
      final centerTimeline = timelines.at(1);
      final timelineRect = tester.getRect(centerTimeline);
      expect(timelineRect.left, closeTo(0, 0.5));
      expect(timelineRect.width, closeTo(screenSize.width, 0.5));

      final hourRows = find.descendant(
        of: centerTimeline,
        matching: find.byWidgetPredicate(
          (widget) => widget.runtimeType.toString() == '_HourSlot',
        ),
      );
      expect(hourRows, findsNWidgets(24));
      final hourRowRect = tester.getRect(hourRows.first);
      expect(hourRowRect.left, closeTo(horizontalSafeInset, 0.5));
      expect(hourRowRect.right, closeTo(screenSize.width, 0.5));

      final midnightLine = find.descendant(
        of: centerTimeline,
        matching: find.byKey(const Key('calendar-midnight-separator')),
      );
      expect(midnightLine, findsOneWidget);
      final midnightLineRect = tester.getRect(midnightLine);
      expect(midnightLineRect.left, closeTo(0, 0.5));
      expect(midnightLineRect.right, closeTo(screenSize.width, 0.5));

      final currentTimeLine = find.descendant(
        of: centerTimeline,
        matching: find.byKey(const Key('calendar-current-time-indicator')),
      );
      expect(currentTimeLine, findsOneWidget);
      final currentTimeLineRect = tester.getRect(currentTimeLine);
      expect(currentTimeLineRect.left, closeTo(horizontalSafeInset, 0.5));
      expect(currentTimeLineRect.right, closeTo(screenSize.width, 0.5));

      final dowMask = find.byWidgetPredicate(
        (widget) => widget.runtimeType.toString() == '_DayViewDowMask',
      );
      expect(dowMask, findsOneWidget);
      final dayLetters = find.descendant(
        of: dowMask,
        matching: find.byType(Text),
      );
      expect(dayLetters, findsNWidgets(7));
      final firstDayLetterX = tester.getCenter(dayLetters.first).dx;
      expect(firstDayLetterX, greaterThan(horizontalSafeInset));
      expect(
        tester.getCenter(dayLetters.last).dx,
        lessThan(screenSize.width - horizontalSafeInset),
      );

      await tester.pumpAndSettle();
      expect(
        tester.getCenter(dayLetters.first).dx,
        closeTo(firstDayLetterX, 0.5),
      );
    },
  );

  testWidgets(
    'landscape Single-Day current-time indicator stays centered above tab bar',
    (tester) async {
      const screenSize = Size(1024, 450);
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = screenSize;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        _landscapeCalendarHarness(
          screenSize: screenSize,
          horizontalSafeInset: 0,
        ),
      );
      await tester.pumpAndSettle();
      final calendar = tester.state<CalendarTabState>(
        find.byType(CalendarTab),
      );
      calendar.navigateUp();
      await tester.pumpAndSettle();
      calendar.jumpToTodayDay();
      await tester.pumpAndSettle();

      final timelines = find.byWidgetPredicate(
        (widget) => widget.runtimeType.toString() == '_DayTimeline',
      );
      expect(timelines, findsNWidgets(3));
      _expectCurrentTimeCenteredAboveFloatingBar(tester, timelines.at(1));
    },
  );

  testWidgets(
    'landscape Multi-Day timeline keeps inset columns and full-width rules',
    (tester) async {
      const screenSize = Size(844, 390);
      const horizontalSafeInset = 28.0;
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = screenSize;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        _landscapeCalendarHarness(
          screenSize: screenSize,
          horizontalSafeInset: horizontalSafeInset,
          daySubMode: DayViewSubMode.multiDay,
        ),
      );
      await tester.pumpAndSettle();
      tester.state<CalendarTabState>(find.byType(CalendarTab)).jumpToTodayDay();
      await tester.pumpAndSettle();

      final timeline = find.byKey(const Key('multi-timeline'));
      expect(timeline, findsOneWidget);
      final timelineRect = tester.getRect(timeline);
      expect(timelineRect.left, closeTo(0, 0.5));
      expect(timelineRect.width, closeTo(screenSize.width, 0.5));

      final hourRows = find.descendant(
        of: timeline,
        matching: find.byWidgetPredicate(
          (widget) => widget.runtimeType.toString() == '_HourSlot',
        ),
      );
      expect(hourRows, findsNWidgets(24));
      final hourRowRect = tester.getRect(hourRows.first);
      expect(hourRowRect.left, closeTo(horizontalSafeInset, 0.5));
      expect(hourRowRect.right, closeTo(screenSize.width, 0.5));

      final midnightLine = find.descendant(
        of: timeline,
        matching: find.byKey(const Key('calendar-midnight-separator')),
      );
      expect(midnightLine, findsOneWidget);
      final midnightLineRect = tester.getRect(midnightLine);
      expect(midnightLineRect.left, closeTo(0, 0.5));
      expect(midnightLineRect.right, closeTo(screenSize.width, 0.5));

      final currentTimeLine = find.descendant(
        of: timeline,
        matching: find.byKey(const Key('calendar-current-time-indicator')),
      );
      expect(currentTimeLine, findsOneWidget);
      _expectCurrentTimeCenteredAboveFloatingBar(tester, timeline);
      final currentTimeLineRect = tester.getRect(currentTimeLine);
      expect(currentTimeLineRect.left, closeTo(horizontalSafeInset, 0.5));
      expect(currentTimeLineRect.right, closeTo(screenSize.width, 0.5));

      final currentTimeLineSegment = find.descendant(
        of: timeline,
        matching: find.byKey(const Key('calendar-current-time-line')),
      );
      expect(currentTimeLineSegment, findsOneWidget);
      final currentTimeLineSegmentRect = tester.getRect(currentTimeLineSegment);
      final centerSeparator = find.descendant(
        of: timeline,
        matching: find.byKey(
          const Key('calendar-multiday-center-separator'),
        ),
      );
      expect(centerSeparator, findsOneWidget);
      expect(
        currentTimeLineSegmentRect.right,
        closeTo(tester.getRect(centerSeparator).center.dx, 0.5),
      );
    },
  );

  testWidgets(
    'portrait Multi-Day current-time line stops at today column boundary',
    (tester) async {
      const screenSize = Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = screenSize;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        _landscapeCalendarHarness(
          screenSize: screenSize,
          horizontalSafeInset: 0,
          daySubMode: DayViewSubMode.multiDay,
        ),
      );
      await tester.pumpAndSettle();
      tester.state<CalendarTabState>(find.byType(CalendarTab)).jumpToTodayDay();
      await tester.pumpAndSettle();

      final timeline = find.byKey(const Key('multi-timeline'));
      final currentTimeLineSegment = find.descendant(
        of: timeline,
        matching: find.byKey(const Key('calendar-current-time-line')),
      );
      final centerSeparator = find.descendant(
        of: timeline,
        matching: find.byKey(
          const Key('calendar-multiday-center-separator'),
        ),
      );
      expect(currentTimeLineSegment, findsOneWidget);
      expect(centerSeparator, findsOneWidget);
      expect(
        tester.getRect(currentTimeLineSegment).right,
        closeTo(tester.getRect(centerSeparator).center.dx, 0.5),
      );
    },
  );

  testWidgets(
    'Multi-Day entrance animates left-day line with the center divider',
    (tester) async {
      const screenSize = Size(844, 390);
      await _beginMultiDayEntrance(
        tester,
        screenSize: screenSize,
        todayOnRight: false,
      );

      final timeline = find.byKey(const Key('multi-timeline'));
      final line = find.descendant(
        of: timeline,
        matching: find.byKey(const Key('calendar-current-time-line')),
      );
      final centerSeparator = find.descendant(
        of: timeline,
        matching: find.byKey(
          const Key('calendar-multiday-center-separator'),
        ),
      );
      expect(line, findsOneWidget);
      expect(tester.getRect(line).right, closeTo(screenSize.width, 0.5));

      await tester.pump(const Duration(milliseconds: 100));
      expect(centerSeparator, findsOneWidget);
      expect(
        tester.getRect(line).right,
        closeTo(tester.getRect(centerSeparator).center.dx, 0.5),
      );
    },
  );

  testWidgets(
    'Multi-Day entrance moves right-day indicator with the center divider',
    (tester) async {
      const screenSize = Size(844, 390);
      const horizontalSafeInset = 28.0;
      await _beginMultiDayEntrance(
        tester,
        screenSize: screenSize,
        todayOnRight: true,
      );
      await tester.pump(const Duration(milliseconds: 100));

      final timeline = find.byKey(const Key('multi-timeline'));
      final indicator = find.descendant(
        of: timeline,
        matching: find.byKey(const Key('calendar-current-time-indicator')),
      );
      final line = find.descendant(
        of: timeline,
        matching: find.byKey(const Key('calendar-current-time-line')),
      );
      final dot = find.descendant(
        of: indicator,
        matching: find.byWidgetPredicate(
          (widget) => widget.runtimeType.toString() == '_CurrentTimeDot',
        ),
      );
      final centerSeparator = find.descendant(
        of: timeline,
        matching: find.byKey(
          const Key('calendar-multiday-center-separator'),
        ),
      );
      expect(indicator, findsOneWidget);
      expect(line, findsOneWidget);
      expect(dot, findsOneWidget);
      expect(centerSeparator, findsOneWidget);
      expect(
        tester.getCenter(dot).dx,
        closeTo(tester.getRect(centerSeparator).center.dx, 0.5),
      );
      expect(
        tester.getRect(line).right,
        closeTo(screenSize.width - horizontalSafeInset, 0.5),
      );
    },
  );
}

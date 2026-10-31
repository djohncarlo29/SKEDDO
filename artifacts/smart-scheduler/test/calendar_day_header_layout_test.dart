import 'package:flutter/cupertino.dart';
import 'package:flutter/painting.dart' show TextPainter;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_scheduler/app_settings.dart';
import 'package:smart_scheduler/app_theme.dart';
import 'package:smart_scheduler/tabs/calendar_tab.dart';
import 'package:smart_scheduler/widgets/app_window_content_boundary.dart';
import 'package:smart_scheduler/widgets/app_header_scroll_edge.dart';
import 'package:smart_scheduler/widgets/view_mode_icons.dart';

void _expectDowBaselineAtHeaderBottom(WidgetTester tester, Finder header) {
  final baseline = find.descendant(
    of: header,
    matching: find.byType(Baseline),
  ).first;
  expect(tester.widget<Baseline>(baseline).baseline, closeTo(28.0, 0.5));
}

double _calendarDowTextTopInset(WidgetTester tester) {
  final label = find.text('S').first;
  final text = tester.widget<Text>(label);
  final context = tester.element(label);
  final baseline = tester.widget<Baseline>(
    find.ancestor(of: label, matching: find.byType(Baseline)).first,
  );
  final painter = TextPainter(
    text: text.textSpan ?? TextSpan(text: text.data ?? '', style: text.style),
    textDirection: Directionality.of(context),
    textScaler: MediaQuery.textScalerOf(context),
  )..layout();
  final metrics = painter.computeLineMetrics();
  final inset = baseline.baseline -
      (metrics.isEmpty ? 0.0 : metrics.first.baseline);
  painter.dispose();
  return inset;
}

void _expectDayBannerVerticalInset(WidgetTester tester, Finder banner) {
  final textFinders = find.descendant(of: banner, matching: find.byType(Text));
  final textRects = <Rect>[
    for (var index = 0; index < textFinders.evaluate().length; index++)
      tester.getRect(textFinders.at(index)),
  ];
  expect(textRects, isNotEmpty);
  final textBounds = textRects.reduce((a, b) => a.expandToInclude(b));
  final bannerBounds = tester.getRect(banner);
  expect(textBounds.top - bannerBounds.top, closeTo(12.0, 0.5));
  expect(bannerBounds.bottom - textBounds.bottom, closeTo(12.0, 0.5));
}

void main() {
  test('day circle allowance starts 12pt below the DOW baseline', () {
    expect(kFixedTopPadding, 12.0);
    expect(kDayCircleOffset, kFixedTopPadding + 18.0);
  });

  testWidgets(
    'Day View shell title updates immediately when date format changes',
    (tester) async {
      const screenSize = Size(402, 874);
      const appShellLeadingInset = 24.0 + kAppHeaderToolbarHeight;
      SharedPreferences.setMockInitialValues({'calendar_view_mode': 'list'});
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = screenSize;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final transition = AppHeaderTitleTransition();
      addTearDown(transition.dispose);
      final previousFormat = appDateFormatNotifier.value;
      addTearDown(() => appDateFormatNotifier.value = previousFormat);
      appDateFormatNotifier.value = AppDateFormat.monthDayYearSlash;

      final calendarKey = GlobalKey<CalendarTabState>();
      var reportedTitle = '';
      await tester.pumpWidget(
        CupertinoApp(
          builder: (context, child) => AppHeaderScrollInsetScope(
            leadingInset: appShellLeadingInset,
            titleCollapseExtent: kAppHeaderTitleCollapseDistance,
            titleTransition: transition,
            child: AppWindowContentBoundary(
              child: Padding(
                padding: const EdgeInsets.only(top: appShellLeadingInset),
                child: child ?? const SizedBox.shrink(),
              ),
            ),
          ),
          home: CalendarTab(
            key: calendarKey,
            onViewChanged: (view, _, _, currentTitle, _, _) {
              reportedTitle = currentTitle;
              if (view == CalendarView.day) {
                transition.bindTo(null, preserveCollapseProgress: true);
              }
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      _expectDowBaselineAtHeaderBottom(
        tester,
        find.byKey(const ValueKey('calendar-month-panels')),
      );

      final calendar = calendarKey.currentState!;
      await calendar.advanceCurrentHeader();
      await tester.pumpAndSettle();
      final monthFirstTitle = reportedTitle;

      appDateFormatNotifier.value = AppDateFormat.dayMonthYearDot;
      await tester.pump();

      expect(calendar.headerTitle, isNot(monthFirstTitle));
      expect(reportedTitle, calendar.headerTitle);
      expect(reportedTitle, matches(RegExp(r'^\d{1,2} [A-Za-z]{3}$')));
    },
  );

  testWidgets(
    'entering Day View preserves expanded shared-header geometry',
    (tester) async {
      const screenSize = Size(402, 874);
      const appShellLeadingInset = 24.0 + kAppHeaderToolbarHeight;
      SharedPreferences.setMockInitialValues({'calendar_view_mode': 'list'});
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = screenSize;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final transition = AppHeaderTitleTransition();
      final calendarKey = GlobalKey<CalendarTabState>();
      var reportedView = CalendarView.month;
      addTearDown(transition.dispose);

      await tester.pumpWidget(
        CupertinoApp(
          builder: (context, child) => AppHeaderScrollInsetScope(
            leadingInset: appShellLeadingInset,
            titleCollapseExtent: kAppHeaderTitleCollapseDistance,
            titleTransition: transition,
            child: AppWindowContentBoundary(
              child: Padding(
                padding: const EdgeInsets.only(top: appShellLeadingInset),
                child: child ?? const SizedBox.shrink(),
              ),
            ),
          ),
          home: CalendarTab(
            key: calendarKey,
            onViewChanged: (view, _, _, _, _, _) {
              reportedView = view;
              if (view == CalendarView.day) {
                transition.bindTo(null, preserveCollapseProgress: true);
              }
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      final calendar = calendarKey.currentState!;
      final monthHeaderPosition = calendar.headerScrollPosition!;
      transition.bindTo(monthHeaderPosition);
      expect(transition.collapseProgress, 0);

      await calendar.advanceCurrentHeader();
      await tester.pumpAndSettle();

      expect(reportedView, CalendarView.day);
      expect(
        monthHeaderPosition.pixels,
        closeTo(0, 0.5),
        reason: 'The Month body reset must not collapse its independent header.',
      );
      expect(transition.collapseProgress, 0);

      final dow = find.byWidgetPredicate(
        (widget) => widget.runtimeType.toString() == '_DayViewDowMask',
      );
      final selectedWeek = find.byKey(
        const Key('day-view-pinned-week-strip'),
      );
      final banners = find.byWidgetPredicate(
        (widget) => widget.runtimeType.toString() == '_DayBanner',
      );
      expect(selectedWeek, findsOneWidget);
      expect(dow, findsOneWidget);
      expect(
        find.byKey(const ValueKey('calendar-month-panels')),
        findsNothing,
        reason: 'Settled Day View must not paint the Month rows behind its header.',
      );
      expect(
        find.ancestor(
          of: selectedWeek,
          matching: find.byType(AppHeaderScrollClip),
        ),
        findsNothing,
        reason: 'The settled strip must not remain inside the Month viewport clip.',
      );
      expect(
        tester.getRect(selectedWeek).top,
        closeTo(tester.getRect(dow).bottom, 0.5),
      );
      expect(
        tester.getRect(banners.at(1)).top,
        closeTo(tester.getRect(selectedWeek).bottom, 0.5),
      );
      expect(tester.takeException(), isNull);

      // On reverse, the Month grid returns under the same collapse progress
      // that positions the selected strip and the rows above it.
      final reverseToMonth = calendar.advanceCurrentHeader();
      await tester.pump(const Duration(milliseconds: 16));
      expect(
        find.byKey(const ValueKey('calendar-month-panels')),
        findsOneWidget,
      );
      await tester.pumpAndSettle();
      await reverseToMonth;
    },
  );

  testWidgets(
    'Day week-strip swipes use the strip’s actual screen position',
    (tester) async {
      const screenSize = Size(402, 874);
      const appShellLeadingInset = 24.0 + kAppHeaderToolbarHeight;
      SharedPreferences.setMockInitialValues({'calendar_view_mode': 'list'});
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = screenSize;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final previousFormat = appDateFormatNotifier.value;
      appDateFormatNotifier.value = AppDateFormat.dayMonthYearSlash;
      addTearDown(() => appDateFormatNotifier.value = previousFormat);

      final transition = AppHeaderTitleTransition();
      addTearDown(transition.dispose);
      final calendarKey = GlobalKey<CalendarTabState>();

      await tester.pumpWidget(
        CupertinoApp(
          builder: (context, child) => AppHeaderScrollInsetScope(
            leadingInset: appShellLeadingInset,
            titleCollapseExtent: kAppHeaderTitleCollapseDistance,
            titleTransition: transition,
            child: AppWindowContentBoundary(
              child: Padding(
                padding: const EdgeInsets.only(top: appShellLeadingInset),
                child: child ?? const SizedBox.shrink(),
              ),
            ),
          ),
          home: CalendarTab(
            key: calendarKey,
            onViewChanged: (_, _, _, _, _, _) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      final calendar = calendarKey.currentState!;
      await calendar.advanceCurrentHeader();
      await tester.pumpAndSettle();
      expect(calendar.view, CalendarView.day);

      final stripRect = tester.getRect(
        find.byKey(const Key('day-view-pinned-week-strip')),
      );
      final calendarRect = tester.getRect(find.byKey(calendarKey));
      final localStripCenterY = stripRect.center.dy - calendarRect.top;
      expect(
        localStripCenterY,
        greaterThan(28 + stripRect.height),
        reason: 'The strip sits below the old fixed local-Y threshold.',
      );

      final startOfWeek = DateTime.now();
      await tester.dragFrom(stripRect.center, const Offset(-180, 0));
      await tester.pumpAndSettle();

      expect(
        calendar.headerTitle,
        formatAppDateMedium(
          startOfWeek.add(const Duration(days: 7)),
          includeYear: false,
        ),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'entering Day View preserves compact shared-header geometry',
    (tester) async {
      const screenSize = Size(402, 874);
      const appShellLeadingInset =
          24.0 + kAppHeaderToolbarHeight;
      SharedPreferences.setMockInitialValues({'calendar_view_mode': 'list'});
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = screenSize;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final transition = AppHeaderTitleTransition();
      final calendarKey = GlobalKey<CalendarTabState>();
      var reportedView = CalendarView.month;
      addTearDown(transition.dispose);

      await tester.pumpWidget(
        CupertinoApp(
          builder: (context, child) => AppHeaderScrollInsetScope(
            leadingInset: appShellLeadingInset,
            titleCollapseExtent: kAppHeaderTitleCollapseDistance,
            titleTransition: transition,
            child: AppWindowContentBoundary(
              child: Padding(
                padding: const EdgeInsets.only(top: appShellLeadingInset),
                child: child ?? const SizedBox.shrink(),
              ),
            ),
          ),
          home: CalendarTab(
            key: calendarKey,
            onViewChanged: (view, _, _, _, _, _) {
              reportedView = view;
              if (view == CalendarView.day) {
                transition.bindTo(null, preserveCollapseProgress: true);
              }
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      final calendar = calendarKey.currentState!;
      final monthHeaderPosition = calendar.headerScrollPosition!;
      transition.bindTo(monthHeaderPosition);
      monthHeaderPosition.jumpTo(kAppHeaderTitleCollapseDistance);
      await tester.pumpAndSettle();
      expect(transition.collapseProgress, closeTo(1.0, 0.02));

      await calendar.advanceCurrentHeader();
      await tester.pumpAndSettle();
      expect(reportedView, CalendarView.day);
      expect(transition.collapseProgress, closeTo(1.0, 0.02));

      final dow = find.byWidgetPredicate(
        (widget) => widget.runtimeType.toString() == '_DayViewDowMask',
      );
      final dowLabel = find
          .descendant(of: dow, matching: find.byType(Text))
          .first;
      final dowLabelRect = tester.getRect(dowLabel);
      expect(
        dowLabelRect.top,
        closeTo(
          appShellLeadingInset -
              kAppHeaderToolbarHeight +
              kAppHeaderSettledToolbarCircleBottom +
              kAppHeaderExpandedTitleContentGap,
          0.5,
        ),
      );
      final selectedWeek = find.byKey(
        const Key('day-view-pinned-week-strip'),
      );
      final banners = find.byWidgetPredicate(
        (widget) => widget.runtimeType.toString() == '_DayBanner',
      );

      expect(selectedWeek, findsOneWidget);
      expect(dow, findsOneWidget);
      expect(
        find.byKey(const ValueKey('calendar-month-panels')),
        findsNothing,
        reason: 'Settled Day View must not paint the Month rows behind its header.',
      );
      expect(
        find.ancestor(
          of: selectedWeek,
          matching: find.byType(AppHeaderScrollClip),
        ),
        findsNothing,
        reason: 'The settled strip must not remain inside the Month viewport clip.',
      );
      expect(
        tester.getRect(selectedWeek).top,
        closeTo(tester.getRect(dow).bottom, 0.5),
        reason: 'The compact selected week must begin immediately below DOW.',
      );
      _expectDowBaselineAtHeaderBottom(tester, dow);
      expect(
        tester.getRect(banners.at(1)).top,
        closeTo(tester.getRect(selectedWeek).bottom, 0.5),
        reason: 'The compact Day Banner must begin immediately below strip.',
      );

      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('empty Month List re-centers below the grid as the title collapses', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'calendar_view_mode': 'list'});
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(402, 874);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final sourceController = ScrollController();
    final transition = AppHeaderTitleTransition();
    addTearDown(() {
      transition.dispose();
      sourceController.dispose();
    });

    await tester.pumpWidget(
      CupertinoApp(
        builder: (context, child) => AppWindowContentBoundary(child: child!),
        home: AppHeaderScrollInsetScope(
          leadingInset: 0,
          titleCollapseExtent: kAppHeaderTitleCollapseDistance,
          titleTransition: transition,
          child: IndexedStack(
            index: 1,
            children: [
              AppHeaderScrollView(
                controller: sourceController,
                slivers: const [
                  SliverToBoxAdapter(child: AppHeaderScrollInset()),
                  SliverToBoxAdapter(child: SizedBox(height: 100)),
                ],
              ),
              CalendarTab(onViewChanged: (_, _, _, _, _, _) {}),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final calendar = tester.state<CalendarTabState>(find.byType(CalendarTab));
    calendar.setViewMode(CalendarViewMode.list, persist: false);
    await tester.pumpAndSettle();
    expect(calendar.viewMode, CalendarViewMode.list);
    final selectedEmptyState = find.text('No Events').at(1);
    final expandedCenterY = tester.getCenter(selectedEmptyState).dy;
    final compactContentSpacing =
        appHeaderCompactContentSpacingForOrientation(Orientation.portrait);

    final source = AppHeaderScrollView.headerPositionFor(sourceController)!;
    transition.bindTo(source);
    source.jumpTo(kAppHeaderTitleCollapseDistance);
    await tester.pumpAndSettle();
    expect(transition.collapseProgress, 1);
    final compactCenterY = tester.getCenter(selectedEmptyState).dy;
    expect(
      compactCenterY,
      closeTo(
        expandedCenterY +
            (kAppHeaderTitleHeight - compactContentSpacing) / 2 -
            _calendarDowTextTopInset(tester),
        1,
      ),
    );
    source.jumpTo(0);
    await tester.pumpAndSettle();
    expect(tester.getCenter(selectedEmptyState).dy, closeTo(expandedCenterY, 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Month View trailing surface fills and follows the week strip in every mode',
    (tester) async {
      const screenSize = Size(402, 874);
      SharedPreferences.setMockInitialValues({'calendar_view_mode': 'compact'});
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = screenSize;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final calendarKey = GlobalKey<CalendarTabState>();
      await tester.pumpWidget(
        CupertinoApp(
          builder: (context, child) => AppWindowContentBoundary(
            child: child ?? const SizedBox.shrink(),
          ),
          home: CupertinoPageScaffold(
            child: CalendarTab(
              key: calendarKey,
              onViewChanged: (_, _, _, _, _, _) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final calendar = calendarKey.currentState!;
      final now = DateTime.now();
      final surfaceFinder = find.byKey(
        ValueKey('calendar-month-trailing-surface-${now.year}-${now.month}'),
      );

      for (final mode in CalendarViewMode.values) {
        calendar.setViewMode(mode, persist: false);
        await tester.pumpAndSettle();

        expect(surfaceFinder, findsOneWidget, reason: 'Month mode: $mode');
        final surface = tester.widget<ColoredBox>(surfaceFinder);
        expect(
          surface.color,
          CupertinoDynamicColor.resolve(
            kBackgroundColor,
            tester.element(surfaceFinder),
          ),
        );
        expect(
          tester.getRect(surfaceFinder).height,
          greaterThan(200),
          reason: 'The trailing surface should fill the space below the grid.',
        );
      }

      final monthRect = tester.getRect(surfaceFinder);
      await calendar.advanceCurrentHeader();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 180));
      final collapsingRect = tester.getRect(surfaceFinder);
      expect(
        collapsingRect.top,
        greaterThan(monthRect.top),
        reason: 'The trailing surface should move down with the week strips.',
      );

      await tester.pumpAndSettle();
      calendar.navigateDown();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 270));
      final returningRect = tester.getRect(surfaceFinder);
      expect(
        returningRect.top,
        lessThan(collapsingRect.top),
        reason: 'The trailing surface should move up as Month View returns.',
      );
      await tester.pumpAndSettle();
      expect(tester.getRect(surfaceFinder).top, closeTo(monthRect.top, 1));
      expect(tester.takeException(), isNull);
    },
  );

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
      final selectedWeek = find.byKey(
        const Key('day-view-pinned-week-strip'),
      );
      final centerBannerRect = tester.getRect(banners.at(1));
      final centerTimelineRect = tester.getRect(timelines.at(1));
      _expectDayBannerVerticalInset(tester, banners.at(1));
      expect(selectedWeek, findsOneWidget);
      final selectedWeekRect = tester.getRect(selectedWeek);
      const weekStripHeight = 64.0;
      final titleBaselineGap =
          AppHeaderScrollView.expandedTitleContentGapAdjustment(
            desiredGap: kAppHeaderExpandedTitleContentGap,
            existingSpacing: 0.0,
            collapseProgress: 0.0,
            topExtension: kContentAreaTopRaise,
            baselineDescent: AppHeaderScrollView.titleBaselineDescent,
          );
      final targetDowLabelTop =
          kAppHeaderTitleHeight +
          kAppHeaderExpandedTitleDownshift -
          kContentAreaTopRaise +
          titleBaselineGap;

      expect(
        tester.getTopLeft(
          find.descendant(of: dowMask, matching: find.byType(Text)).first,
        ).dy,
        closeTo(targetDowLabelTop, 0.5),
      );
      expect(
        dowRect.top,
        closeTo(
          targetDowLabelTop -
              (tester.getTopLeft(
                    find.descendant(
                      of: dowMask,
                      matching: find.byType(Text),
                    ).first,
                  ).dy -
                  dowRect.top),
          0.5,
        ),
      );
      expect(dowRect.height, closeTo(28.0, 0.5));
      _expectDowBaselineAtHeaderBottom(tester, dowMask);
      expect(selectedWeekRect.top, closeTo(dowRect.bottom, 0.5));
      expect(selectedWeekRect.bottom, closeTo(centerBannerRect.top, 0.5));
      expect(
        centerBannerRect.top,
        closeTo(dowRect.bottom + weekStripHeight, 0.5),
      );
      expect(centerTimelineRect.top, closeTo(centerBannerRect.bottom, 0.5));
    },
  );

  testWidgets('portrait Multi Day header follows compact title on entry', (
    tester,
  ) async {
    const screenSize = Size(402, 874);
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = screenSize;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final transition = AppHeaderTitleTransition();
    final calendarKey = GlobalKey<CalendarTabState>();
    addTearDown(transition.dispose);

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
        home: AppHeaderScrollInsetScope(
          leadingInset: 0,
          titleCollapseExtent: kAppHeaderTitleCollapseDistance,
          titleTransition: transition,
          child: CupertinoPageScaffold(
            child: CalendarTab(
              key: calendarKey,
              daySubMode: DayViewSubMode.multiDay,
              onViewChanged: (view, _, _, _, _, _) {
                if (view == CalendarView.day) {
                  transition.bindTo(null, preserveCollapseProgress: true);
                }
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final calendar = calendarKey.currentState!;
    final monthHeaderPosition = calendar.headerScrollPosition!;
    transition.bindTo(monthHeaderPosition);
    monthHeaderPosition.jumpTo(kAppHeaderTitleCollapseDistance);
    await tester.pumpAndSettle();
    expect(transition.collapseProgress, closeTo(1.0, 0.02));

    calendar.jumpToTodayDay();
    await tester.pumpAndSettle();
    expect(transition.collapseProgress, closeTo(1.0, 0.02));

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
    _expectDayBannerVerticalInset(tester, centerBanner);
    expect(dowRect.height, closeTo(28.0, 0.5));
    _expectDowBaselineAtHeaderBottom(tester, dowMask);
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

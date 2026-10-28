import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart'
    show LiquidGlassSwitch;
import 'package:liquid_glass_easy/src/widgets/lens/liquid_glass_lens.dart'
    show LiquidGlassLens;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_scheduler/app_theme.dart' show AdaptiveLabelPillRow;
import 'package:smart_scheduler/main.dart' show AppShell;
import 'package:smart_scheduler/services/event_model.dart';
import 'package:smart_scheduler/tabs/calendar_tab.dart';
import 'package:smart_scheduler/widgets/app_header_scroll_edge.dart';
import 'package:smart_scheduler/widgets/app_window_content_boundary.dart';
import 'package:smart_scheduler/widgets/interactive_tap_focus_dismissal.dart';

void main() {
  testWidgets('editing an event toggles All-day state and dependent rows', (
    tester,
  ) async {
    final calendarKey = await _mountCalendar(tester);

    final sheetContext = tester.element(find.byType(CalendarTab));
    calendarKey.currentState!.showEditEventSheet(
      sheetContext,
      const ScheduledEvent(
        id: 'all-day-switch-test',
        title: 'Timed event',
        date: '2026-10-27',
        time: '09:00',
        alerts: const ['At time of event'],
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.testTextInput.isVisible, isFalse);

    final allDayRow = find
        .ancestor(of: find.text('All-day'), matching: find.byType(Row))
        .first;
    final allDaySwitch = find.descendant(
      of: allDayRow,
      matching: find.byType(LiquidGlassSwitch),
    );
    expect(allDaySwitch, findsOneWidget);
    final startsRow = find
        .ancestor(
          of: find.text('Starts'),
          matching: find.byType(AdaptiveLabelPillRow),
        )
        .first;
    final endsRow = find
        .ancestor(
          of: find.text('Ends'),
          matching: find.byType(AdaptiveLabelPillRow),
        )
        .first;
    int pillCount(Finder row) =>
        tester.widget<AdaptiveLabelPillRow>(row).pills.length;
    final travelTimeTransition = find
        .ancestor(
          of: find.text('Travel Time'),
          matching: find.byType(SizeTransition),
        )
        .first;
    final switchLens = find.descendant(
      of: allDaySwitch,
      matching: find.byType(LiquidGlassLens),
    );

    double glassThumbWidth() {
      final thumbPosition = find
          .ancestor(of: switchLens.first, matching: find.byType(Positioned))
          .first;
      return tester.widget<Positioned>(thumbPosition).width!;
    }

    double glassThumbHeight() {
      final thumbPosition = find
          .ancestor(of: switchLens.first, matching: find.byType(Positioned))
          .first;
      return tester.widget<Positioned>(thumbPosition).height!;
    }

    double glassThumbLeft() {
      final thumbPosition = find
          .ancestor(of: switchLens.first, matching: find.byType(Positioned))
          .first;
      return tester.widget<Positioned>(thumbPosition).left!;
    }

    final initialThumbLeft = glassThumbLeft();
    expect(tester.widget<LiquidGlassLens>(switchLens.first).visibility, isFalse);
    expect(
      tester.widget<SizeTransition>(travelTimeTransition).sizeFactor.value,
      closeTo(1, 0.001),
    );

    expect(pillCount(startsRow), 2);
    expect(pillCount(endsRow), 2);

    // Tapping the switch and the row label are separate supported targets.
    await tester.tap(allDaySwitch);
    await tester.pumpAndSettle();
    expect(tester.widget<LiquidGlassSwitch>(allDaySwitch).value, isTrue);
    expect(
      tester.widget<SizeTransition>(travelTimeTransition).sizeFactor.value,
      closeTo(0, 0.001),
    );
    expect(pillCount(startsRow), 1);
    expect(pillCount(endsRow), 1);
    expect(glassThumbWidth(), closeTo(37, 0.1));
    expect(glassThumbHeight(), closeTo(24, 0.1));
    expect(glassThumbLeft(), greaterThan(initialThumbLeft));
    expect(tester.widget<LiquidGlassLens>(switchLens.first).visibility, isFalse);

    await tester.tap(find.text('All-day'));
    await tester.pumpAndSettle();
    expect(tester.widget<LiquidGlassSwitch>(allDaySwitch).value, isFalse);
    expect(
      tester.widget<SizeTransition>(travelTimeTransition).sizeFactor.value,
      closeTo(1, 0.001),
    );
    expect(pillCount(startsRow), 2);
    expect(pillCount(endsRow), 2);
    expect(glassThumbWidth(), closeTo(37, 0.1));
    expect(glassThumbHeight(), closeTo(24, 0.1));
    expect(glassThumbLeft(), closeTo(initialThumbLeft, 0.1));
    expect(tester.widget<LiquidGlassLens>(switchLens.first).visibility, isFalse);
  });

  testWidgets('editing an all-day event toggles back and forth by touch', (
    tester,
  ) async {
    final calendarKey = await _mountCalendar(tester);
    final sheetContext = tester.element(find.byType(CalendarTab));
    calendarKey.currentState!.showEditEventSheet(
      sheetContext,
      const ScheduledEvent(
        id: 'all-day-switch-initially-on-test',
        title: 'All-day event',
        date: '2026-10-27',
        isAllDay: true,
        alerts: const ['Night before (9 PM)'],
      ),
    );
    await tester.pumpAndSettle();

    final allDayRow = find
        .ancestor(of: find.text('All-day'), matching: find.byType(Row))
        .first;
    final allDaySwitch = find.descendant(
      of: allDayRow,
      matching: find.byType(LiquidGlassSwitch),
    );
    final startsRow = find
        .ancestor(
          of: find.text('Starts'),
          matching: find.byType(AdaptiveLabelPillRow),
        )
        .first;
    final endsRow = find
        .ancestor(
          of: find.text('Ends'),
          matching: find.byType(AdaptiveLabelPillRow),
        )
        .first;

    int pillCount(Finder row) =>
        tester.widget<AdaptiveLabelPillRow>(row).pills.length;

    expect(tester.widget<LiquidGlassSwitch>(allDaySwitch).value, isTrue);
    expect(pillCount(startsRow), 1);
    expect(pillCount(endsRow), 1);

    // Use an explicit touch sequence rather than invoking the row callback.
    final touch = await tester.startGesture(tester.getCenter(allDaySwitch));
    await tester.pump(const Duration(milliseconds: 80));
    await touch.up();
    await tester.pumpAndSettle();

    expect(tester.widget<LiquidGlassSwitch>(allDaySwitch).value, isFalse);
    expect(pillCount(startsRow), 2);
    expect(pillCount(endsRow), 2);

    await tester.tap(find.text('All-day'));
    await tester.pumpAndSettle();
    expect(tester.widget<LiquidGlassSwitch>(allDaySwitch).value, isTrue);
    expect(pillCount(startsRow), 1);
    expect(pillCount(endsRow), 1);

    await tester.tap(allDaySwitch);
    await tester.pumpAndSettle();
    expect(tester.widget<LiquidGlassSwitch>(allDaySwitch).value, isFalse);
    expect(pillCount(startsRow), 2);
    expect(pillCount(endsRow), 2);
  });

  testWidgets('new event sheet All-day switch settles with initial focus', (
    tester,
  ) async {
    final calendarKey = await _mountCalendar(tester);
    final sheetContext = tester.element(find.byType(CalendarTab));
    calendarKey.currentState!.showNewEventSheet(sheetContext);
    await tester.pumpAndSettle();

    final allDayRow = find
        .ancestor(of: find.text('All-day'), matching: find.byType(Row))
        .first;
    final allDaySwitch = find.descendant(
      of: allDayRow,
      matching: find.byType(LiquidGlassSwitch),
    );
    expect(allDaySwitch, findsOneWidget);

    await tester.tap(allDaySwitch);
    await tester.pumpAndSettle();
    expect(tester.widget<LiquidGlassSwitch>(allDaySwitch).value, isTrue);

    await tester.tap(allDaySwitch);
    await tester.pumpAndSettle();
    expect(tester.widget<LiquidGlassSwitch>(allDaySwitch).value, isFalse);
  });

  testWidgets('All-day toggle works when Edit is opened from AppShell', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(402, 874);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      CupertinoApp(
        builder: (context, child) => InteractiveTapFocusDismissal(
          child: AppWindowContentBoundary(
            child: child ?? const SizedBox.shrink(),
          ),
        ),
        home: const AppShell(),
      ),
    );
    await tester.pumpAndSettle();

    final calendar = tester.state<CalendarTabState>(
      find.byType(CalendarTab, skipOffstage: false),
    );
    calendar.showEditEventSheet(
      tester.element(find.byType(AppShell)),
      const ScheduledEvent(
        id: 'all-day-switch-app-shell-test',
        title: 'Timed event from AppShell',
        date: '2026-10-27',
        time: '09:00',
        alerts: const ['At time of event'],
      ),
    );
    await tester.pumpAndSettle();

    final allDayRow = find
        .ancestor(of: find.text('All-day'), matching: find.byType(Row))
        .first;
    final allDaySwitch = find.descendant(
      of: allDayRow,
      matching: find.byType(LiquidGlassSwitch),
    );
    final startsRow = find
        .ancestor(
          of: find.text('Starts'),
          matching: find.byType(AdaptiveLabelPillRow),
        )
        .first;

    await tester.tap(allDaySwitch);
    await tester.pumpAndSettle();
    expect(tester.widget<LiquidGlassSwitch>(allDaySwitch).value, isTrue);
    expect(
      tester.widget<AdaptiveLabelPillRow>(startsRow).pills.length,
      1,
    );

    await tester.tap(find.text('All-day'));
    await tester.pumpAndSettle();
    expect(tester.widget<LiquidGlassSwitch>(allDaySwitch).value, isFalse);
    expect(
      tester.widget<AdaptiveLabelPillRow>(startsRow).pills.length,
      2,
    );

    // A route-level gesture cancellation can settle the glass switch without
    // delivering its value callback. The form still must take the user's
    // tap-like interaction as the source of truth.
    final cancelledTap = await tester.startGesture(
      tester.getCenter(allDaySwitch),
    );
    await tester.pump(const Duration(milliseconds: 60));
    await cancelledTap.cancel();
    await tester.pumpAndSettle();
    expect(tester.widget<LiquidGlassSwitch>(allDaySwitch).value, isTrue);
    expect(
      tester.widget<AdaptiveLabelPillRow>(startsRow).pills.length,
      1,
    );
    expect(
      tester.widget<AdaptiveLabelPillRow>(
        find
            .ancestor(
              of: find.text('Ends'),
              matching: find.byType(AdaptiveLabelPillRow),
            )
            .first,
      ).pills.length,
      1,
    );
  });
}

Future<GlobalKey<CalendarTabState>> _mountCalendar(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(402, 874);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final calendarKey = GlobalKey<CalendarTabState>();
  final transition = AppHeaderTitleTransition();
  addTearDown(transition.dispose);
  const appShellLeadingInset = 24.0 + kAppHeaderToolbarHeight;
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
      home: CalendarTab(key: calendarKey, onViewChanged: (_, _, _, _, _, _) {}),
    ),
  );
  await tester.pumpAndSettle();
  return calendarKey;
}

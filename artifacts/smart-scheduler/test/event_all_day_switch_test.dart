import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart'
    show LiquidGlassSwitch;
import 'package:liquid_glass_easy/src/widgets/lens/liquid_glass_lens.dart'
    show LiquidGlassLens;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_scheduler/app_theme.dart' show AdaptiveLabelPillRow;
import 'package:smart_scheduler/app_settings.dart'
    show appEventDurationNotifier;
import 'package:smart_scheduler/main.dart' show AppShell;
import 'package:smart_scheduler/services/event_model.dart';
import 'package:smart_scheduler/tabs/calendar_tab.dart';
import 'package:smart_scheduler/widgets/app_header_scroll_edge.dart';
import 'package:smart_scheduler/widgets/app_window_content_boundary.dart';
import 'package:smart_scheduler/widgets/event_time_picker.dart';
import 'package:smart_scheduler/widgets/interactive_tap_focus_dismissal.dart';

Finder _dateTimeRow(String label) => find
    .ancestor(of: find.text(label), matching: find.byType(AdaptiveLabelPillRow))
    .first;

String _timeText(WidgetTester tester, String label) =>
    tester.widget<AdaptiveLabelPillRow>(_dateTimeRow(label)).pills[1].text;

int _minutesOfDay(String value) {
  final match = RegExp(
    r'^(\d{1,2}):(\d{2})\s*([AP]M)$',
    caseSensitive: false,
  ).firstMatch(value.trim());
  if (match == null) {
    throw FormatException('Unexpected time label: $value');
  }
  var hour = int.parse(match.group(1)!);
  final minute = int.parse(match.group(2)!);
  final isPm = match.group(3)!.toUpperCase() == 'PM';
  hour %= 12;
  if (isPm) hour += 12;
  return hour * 60 + minute;
}

int _displayedIntervalMinutes(WidgetTester tester) {
  final starts = _minutesOfDay(_timeText(tester, 'Starts'));
  final ends = _minutesOfDay(_timeText(tester, 'Ends'));
  return (ends - starts + 24 * 60) % (24 * 60);
}

void main() {
  testWidgets('new events use the selected default duration', (tester) async {
    appEventDurationNotifier.value = '1 hour, 30 minutes';
    final calendarKey = await _mountCalendar(tester);
    calendarKey.currentState!.showNewEventSheet(
      tester.element(find.byType(CalendarTab)),
    );
    await tester.pumpAndSettle();

    expect(_displayedIntervalMinutes(tester), 90);
  });

  testWidgets('editing preserves the saved duration when Starts changes', (
    tester,
  ) async {
    appEventDurationNotifier.value = '2 hours';
    final calendarKey = await _mountCalendar(tester);
    calendarKey.currentState!.showEditEventSheet(
      tester.element(find.byType(CalendarTab)),
      const ScheduledEvent(
        id: 'saved-event-duration-test',
        title: 'Saved interval',
        date: 'October 27, 2026',
        time: '9:00 AM',
        endDate: 'October 27, 2026',
        endTime: '10:15 AM',
        alerts: ['At time of event'],
      ),
    );
    await tester.pumpAndSettle();
    expect(_displayedIntervalMinutes(tester), 75);

    await tester.tap(find.text(_timeText(tester, 'Starts')).first);
    await tester.pumpAndSettle();
    final startsPicker = tester
        .widgetList<EventTimePicker>(find.byType(EventTimePicker))
        .last;
    startsPicker.onChanged(DateTime(2026, 10, 27, 10));
    await tester.pumpAndSettle();

    expect(_displayedIntervalMinutes(tester), 75);
  });

  testWidgets('Ends wheel snaps to five minutes after scrolling settles', (
    tester,
  ) async {
    final calendarKey = await _mountCalendar(tester);
    calendarKey.currentState!.showEditEventSheet(
      tester.element(find.byType(CalendarTab)),
      const ScheduledEvent(
        id: 'minimum-event-duration-test',
        title: 'Minimum interval',
        date: 'October 27, 2026',
        time: '2:00 PM',
        endDate: 'October 27, 2026',
        endTime: '2:10 PM',
        alerts: ['At time of event'],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text(_timeText(tester, 'Ends')));
    await tester.pumpAndSettle();
    final endsPicker = tester
        .widgetList<EventTimePicker>(find.byType(EventTimePicker))
        .last;
    endsPicker.onWheelChanged!(DateTime(2026, 10, 27, 14, 4));
    await tester.pumpAndSettle();

    final inProgressPicker = tester
        .widgetList<EventTimePicker>(find.byType(EventTimePicker))
        .last;
    expect(inProgressPicker.initialTime, DateTime(2026, 10, 27, 14, 4));
    expect(_displayedIntervalMinutes(tester), 4);

    inProgressPicker.onWheelScrollEnd!();
    await tester.pumpAndSettle();

    final correctedPicker = tester
        .widgetList<EventTimePicker>(find.byType(EventTimePicker))
        .last;
    expect(correctedPicker.initialTime, DateTime(2026, 10, 27, 14, 5));
    final minuteWheel = tester
        .widgetList<ListWheelScrollView>(
          find.byKey(const ValueKey('event-time-minute-wheel')),
        )
        .last;
    final minuteController =
        minuteWheel.controller! as FixedExtentScrollController;
    expect(minuteController.selectedItem % 60, 5);
    expect(_displayedIntervalMinutes(tester), 5);
  });

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

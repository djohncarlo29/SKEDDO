import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart'
    show LiquidGlassSwitch;
import 'package:liquid_glass_easy/src/widgets/lens/liquid_glass_lens.dart'
    show LiquidGlassLens;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_scheduler/app_theme.dart';
import 'package:smart_scheduler/services/event_model.dart';
import 'package:smart_scheduler/tabs/calendar_tab.dart';
import 'package:smart_scheduler/widgets/app_header_scroll_edge.dart';
import 'package:smart_scheduler/widgets/app_window_content_boundary.dart';

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
    expect(allDaySwitch, findsOneWidget);
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

    expect(
      tester.widget<SizeTransition>(travelTimeTransition).sizeFactor.value,
      closeTo(1, 0.001),
    );

    await tester.tap(allDaySwitch);
    await tester.pumpAndSettle();
    expect(tester.widget<LiquidGlassSwitch>(allDaySwitch).value, isTrue);
    expect(
      tester.widget<SizeTransition>(travelTimeTransition).sizeFactor.value,
      closeTo(0, 0.001),
    );
    expect(glassThumbWidth(), closeTo(37, 0.1));

    await tester.tap(allDaySwitch);
    await tester.pumpAndSettle();
    expect(tester.widget<LiquidGlassSwitch>(allDaySwitch).value, isFalse);
    expect(
      tester.widget<SizeTransition>(travelTimeTransition).sizeFactor.value,
      closeTo(1, 0.001),
    );
    expect(glassThumbWidth(), closeTo(37, 0.1));
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

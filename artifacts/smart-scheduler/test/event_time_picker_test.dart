import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_scheduler/widgets/event_time_picker.dart';

void main() {
  testWidgets('tapping the selected band opens full inline time entry', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    DateTime? changedTime;
    await tester.pumpWidget(
      CupertinoApp(
        home: Center(
          child: SizedBox(
            width: 360,
            child: EventTimePicker(
              initialTime: DateTime(2026, 10, 2, 1),
              onChanged: (time) => changedTime = time,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final minuteWheel = find.byKey(const ValueKey('event-time-minute-wheel'));
    await tester.tapAt(tester.getRect(minuteWheel).center);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('event-time-hour-entry')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('event-time-minute-entry')),
      findsOneWidget,
    );
    expect(
      tester
          .widget<CupertinoTextField>(
            find.byKey(const ValueKey('event-time-hour-entry')),
          )
          .keyboardType,
      TextInputType.number,
    );

    await tester.tap(find.byKey(const ValueKey('event-time-hour-entry')));
    await tester.enterText(
      find.byKey(const ValueKey('event-time-hour-entry')),
      '5',
    );
    await tester.pumpAndSettle();

    // The keyboard editor stays open while the hour wheel finishes its spin.
    expect(find.byKey(const ValueKey('event-time-hour-entry')), findsOneWidget);
    final hourWheelWidget = tester.widget<ListWheelScrollView>(
      find.byKey(const ValueKey('event-time-hour-wheel')),
    );
    expect(
      (hourWheelWidget.controller! as FixedExtentScrollController).selectedItem %
          12,
      4,
    );
    final hourWheelRect = tester.getRect(
      find.byKey(const ValueKey('event-time-hour-wheel')),
    );
    expect(
      tester.getCenter(find.text('4').first).dy,
      lessThan(hourWheelRect.center.dy),
    );
    expect(
      tester.getCenter(find.text('6').first).dy,
      greaterThan(hourWheelRect.center.dy),
    );

    await tester.tap(find.byKey(const ValueKey('event-time-minute-entry')));
    await tester.enterText(
      find.byKey(const ValueKey('event-time-minute-entry')),
      '30',
    );
    await tester.pumpAndSettle();

    final minuteWheelWidget = tester.widget<ListWheelScrollView>(
      minuteWheel,
    );
    expect(
      (minuteWheelWidget.controller! as FixedExtentScrollController)
              .selectedItem %
          60,
      30,
    );
    expect(changedTime, DateTime(2026, 10, 2, 5, 30));
    expect(
      find.byKey(const ValueKey('event-time-minute-entry')),
      findsOneWidget,
    );

    final selectedHourWheelRect = tester.getRect(
      find.byKey(const ValueKey('event-time-hour-wheel')),
    );
    await tester.tapAt(
      Offset(selectedHourWheelRect.center.dx, selectedHourWheelRect.top + 4),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('event-time-hour-entry')), findsNothing);
    expect(changedTime, DateTime(2026, 10, 2, 5, 30));
  });

  testWidgets('dragging the selected band still spins the wheel', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      CupertinoApp(
        home: Center(
          child: SizedBox(
            width: 360,
            child: EventTimePicker(
              initialTime: DateTime(2026, 10, 2, 1),
              onChanged: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final hourWheel = find.byKey(const ValueKey('event-time-hour-wheel'));
    final initialIndex =
        (tester.widget<ListWheelScrollView>(hourWheel).controller!
                as FixedExtentScrollController)
            .selectedItem;

    await tester.drag(hourWheel, const Offset(0, -80));
    await tester.pumpAndSettle();

    final finalIndex =
        (tester.widget<ListWheelScrollView>(hourWheel).controller!
                as FixedExtentScrollController)
            .selectedItem;
    expect(finalIndex, isNot(initialIndex));
    expect(find.byKey(const ValueKey('event-time-hour-entry')), findsNothing);
  });
}
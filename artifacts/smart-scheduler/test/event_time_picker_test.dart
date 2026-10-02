import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_scheduler/widgets/event_time_picker.dart';

const _inputKey = ValueKey('event-time-numeric-input');
const _hourWheelKey = ValueKey('event-time-hour-wheel');
const _minuteWheelKey = ValueKey('event-time-minute-wheel');

Future<void> _mountPicker(
  WidgetTester tester, {
  required DateTime initialTime,
  ValueChanged<DateTime>? onChanged,
  Widget Function(Widget child)? wrapPicker,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    tester.view.resetViewInsets();
  });

  Widget picker = EventTimePicker(
    initialTime: initialTime,
    onChanged: onChanged ?? (_) {},
  );
  if (wrapPicker != null) picker = wrapPicker(picker);

  await tester.pumpWidget(
    CupertinoApp(
      home: Center(child: SizedBox(width: 360, child: picker)),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _openKeyboard(WidgetTester tester) async {
  await tester.tapAt(tester.getRect(find.byKey(_minuteWheelKey)).center);
  await tester.pumpAndSettle();
}

Future<void> _type(WidgetTester tester, String value) async {
  await tester.enterText(find.byKey(_inputKey), value);
  await tester.pumpAndSettle();
}

int _selectedHour(WidgetTester tester) {
  final wheel = tester.widget<ListWheelScrollView>(find.byKey(_hourWheelKey));
  return (wheel.controller! as FixedExtentScrollController).selectedItem % 12 +
      1;
}

int _selectedMinute(WidgetTester tester) {
  final wheel = tester.widget<ListWheelScrollView>(find.byKey(_minuteWheelKey));
  return (wheel.controller! as FixedExtentScrollController).selectedItem % 60;
}

void main() {
  testWidgets(
    'selection-bar tap opens one invisible numeric input and preserves the minute wheel',
    (tester) async {
      DateTime? changedTime;
      await _mountPicker(
        tester,
        initialTime: DateTime(2026, 10, 2, 10, 43),
        onChanged: (time) => changedTime = time,
      );

      final minuteWheel = find.byKey(_minuteWheelKey);
      final minuteControllerBefore = tester
          .widget<ListWheelScrollView>(minuteWheel)
          .controller;
      await _openKeyboard(tester);

      expect(find.byKey(_inputKey), findsOneWidget);
      expect(find.byKey(const ValueKey('event-time-hour-entry')), findsNothing);
      expect(
        tester.widget<CupertinoTextField>(find.byKey(_inputKey)).keyboardType,
        TextInputType.number,
      );
      final input = tester.widget<CupertinoTextField>(find.byKey(_inputKey));
      expect(input.focusNode!.hasFocus, isTrue);
      expect(input.showCursor, isFalse);
      expect(input.style!.color, CupertinoColors.transparent);
      expect(tester.testTextInput.isVisible, isTrue);

      await _type(tester, '2');
      expect(_selectedHour(tester), 2);
      expect(_selectedMinute(tester), 43);
      expect(
        identical(
          minuteControllerBefore,
          tester.widget<ListWheelScrollView>(minuteWheel).controller,
        ),
        isTrue,
      );
      expect(changedTime, DateTime(2026, 10, 2, 2, 43));
      expect(
        tester
            .widget<CupertinoTextField>(find.byKey(_inputKey))
            .focusNode!
            .hasFocus,
        isTrue,
      );
      expect(tester.testTextInput.isVisible, isTrue);

      // Minute digits are appended to the same hidden input stream.
      await _type(tester, '25');
      expect(_selectedMinute(tester), 5);
      await _type(tester, '258');
      expect(_selectedMinute(tester), 58);

      // A digit after a completed minute is ignored; it does not restart at 03.
      await _type(tester, '2583');
      expect(_selectedMinute(tester), 58);
      expect(tester.testTextInput.isVisible, isTrue);
      expect(changedTime, DateTime(2026, 10, 2, 2, 58));

      await tester.tapAt(const Offset(5, 5));
      await tester.pump();
      expect(
        tester
            .widget<CupertinoTextField>(find.byKey(_inputKey))
            .focusNode!
            .hasFocus,
        isTrue,
      );
      expect(tester.testTextInput.isVisible, isTrue);
    },
  );

  testWidgets(
    'tapping minute switches input there, then tapping hour switches back',
    (tester) async {
      await _mountPicker(tester, initialTime: DateTime(2026, 10, 2, 10, 43));
      await _openKeyboard(tester);
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pump();

      await tester.tapAt(tester.getRect(find.byKey(_minuteWheelKey)).center);
      await tester.pumpAndSettle();
      expect(tester.testTextInput.isVisible, isTrue);
      expect(
        tester
            .widget<CupertinoTextField>(find.byKey(_inputKey))
            .focusNode!
            .hasFocus,
        isTrue,
      );

      // Selecting minutes first skips hour entry entirely.
      await _type(tester, '35');
      expect(_selectedHour(tester), 10);
      expect(_selectedMinute(tester), 35);

      // The keyboard remains open, and the hour column becomes the active
      // input target so the committed minute can be left unchanged.
      await tester.tapAt(tester.getRect(find.byKey(_hourWheelKey)).center);
      await tester.pumpAndSettle();
      expect(tester.testTextInput.isVisible, isTrue);
      expect(
        tester
            .widget<CupertinoTextField>(find.byKey(_inputKey))
            .controller!
            .text,
        isEmpty,
      );
      await _type(tester, '12');
      expect(_selectedHour(tester), 12);
      expect(_selectedMinute(tester), 35);
      expect(tester.testTextInput.isVisible, isTrue);
    },
  );

  testWidgets(
    'selection-band tap reopens the keypad if entry mode outlives it',
    (tester) async {
      await _mountPicker(tester, initialTime: DateTime(2026, 10, 2, 10, 43));
      await _openKeyboard(tester);
      expect(tester.testTextInput.isVisible, isTrue);

      // Simulate the OS hiding the keypad while the entry overlay remains
      // mounted and focused.
      tester.testTextInput.hide();
      await tester.pumpAndSettle();
      expect(find.byKey(_inputKey), findsOneWidget);
      expect(tester.testTextInput.isVisible, isFalse);

      await tester.tapAt(tester.getRect(find.byKey(_minuteWheelKey)).center);
      await tester.pumpAndSettle();

      expect(find.byKey(_inputKey), findsOneWidget);
      expect(
        tester
            .widget<CupertinoTextField>(find.byKey(_inputKey))
            .focusNode!
            .hasFocus,
        isTrue,
      );
      expect(tester.testTextInput.isVisible, isTrue);

      // Focus loss is another path to an inactive keyboard. The mounted
      // selection bar must still restore the numeric input.
      tester.testTextInput.hide();
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      expect(find.byKey(_inputKey), findsOneWidget);
      expect(
        tester
            .widget<CupertinoTextField>(find.byKey(_inputKey))
            .focusNode!
            .hasFocus,
        isFalse,
      );

      await tester.tapAt(tester.getRect(find.byKey(_hourWheelKey)).center);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<CupertinoTextField>(find.byKey(_inputKey))
            .focusNode!
            .hasFocus,
        isTrue,
      );
      expect(tester.testTextInput.isVisible, isTrue);
    },
  );

  testWidgets(
    'hour prefixes, invalid digits, and backspace update only meaningful values',
    (tester) async {
      await _mountPicker(tester, initialTime: DateTime(2026, 10, 2, 10, 43));
      await _openKeyboard(tester);

      await _type(tester, '1');
      expect(_selectedHour(tester), 1);
      expect(_selectedMinute(tester), 43);

      // Invalid second hour digit is discarded and advances to minute.
      await _type(tester, '15');
      expect(_selectedHour(tester), 1);
      expect(_selectedMinute(tester), 43);
      expect(
        tester
            .widget<CupertinoTextField>(find.byKey(_inputKey))
            .controller!
            .text,
        '1',
      );

      // The rejected 5 is not reused; a fresh 5 now enters minute 05.
      await _type(tester, '15');
      expect(_selectedMinute(tester), 5);

      // Deleting the minute digit leaves its current wheel selection in place.
      await _type(tester, '1');
      expect(_selectedMinute(tester), 5);

      // The next delete clears the committed hour, so a fresh hour can start.
      await _type(tester, '');
      // Backspace from the committed hour returns to it and reduces 12 to 1.
      await _type(tester, '1');
      await _type(tester, '12');
      expect(_selectedHour(tester), 12);
      await _type(tester, '1');
      expect(_selectedHour(tester), 1);
      expect(_selectedMinute(tester), 5);

      // A leading hour zero is only pending; 07 selects hour 7.
      await _type(tester, '');
      await _type(tester, '0');
      expect(_selectedHour(tester), 1);
      await _type(tester, '07');
      expect(_selectedHour(tester), 7);
      expect(_selectedMinute(tester), 5);
    },
  );

  testWidgets(
    'minute prefixes reject values above 59 and backspace edits 58 to 5 to empty',
    (tester) async {
      await _mountPicker(tester, initialTime: DateTime(2026, 10, 2, 2, 43));
      await _openKeyboard(tester);

      await _type(tester, '2');
      await _type(tester, '26'); // First minute digit immediately selects 06.
      expect(_selectedMinute(tester), 6);
      await _type(tester, '265'); // 65 is invalid; keep 06 and the 6 prefix.
      expect(_selectedMinute(tester), 6);
      expect(
        tester
            .widget<CupertinoTextField>(find.byKey(_inputKey))
            .controller!
            .text,
        '26',
      );

      // Delete the pending 6, then enter a valid 58.
      await _type(tester, '2');
      expect(_selectedMinute(tester), 6);
      await _type(tester, '25');
      expect(_selectedMinute(tester), 5);
      await _type(tester, '258');
      expect(_selectedMinute(tester), 58);
      await _type(tester, '25');
      expect(_selectedMinute(tester), 5);
      await _type(tester, '2');
      expect(_selectedMinute(tester), 5);
    },
  );

  testWidgets('a direct wheel drag clears pending numeric input', (
    tester,
  ) async {
    await _mountPicker(tester, initialTime: DateTime(2026, 10, 2, 1, 20));
    await _openKeyboard(tester);
    await _type(tester, '1');

    await tester.drag(find.byKey(_hourWheelKey), const Offset(0, -80));
    await tester.pumpAndSettle();

    final input = tester.widget<CupertinoTextField>(find.byKey(_inputKey));
    expect(input.controller!.text, isEmpty);
    expect(input.focusNode!.hasFocus, isTrue);
    expect(tester.testTextInput.isVisible, isTrue);

    // The next digit starts fresh instead of combining with the stale 1.
    await _type(tester, '3');
    expect(_selectedHour(tester), 3);
  });

  testWidgets(
    'wheel dragging keeps the keypad open and blocks ancestor drag dismissal',
    (tester) async {
      var ancestorDragStarts = 0;
      var ancestorDragUpdates = 0;
      await _mountPicker(
        tester,
        initialTime: DateTime(2026, 10, 2, 1, 20),
        wrapPicker: (child) => NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            if (notification is ScrollStartNotification &&
                notification.dragDetails != null) {
              ancestorDragStarts++;
              // Simulate iOS implicitly resigning the text input as scrolling
              // begins. The picker should retain focus through the gesture.
              FocusManager.instance.primaryFocus?.unfocus();
            } else if (notification is ScrollUpdateNotification &&
                notification.dragDetails != null) {
              ancestorDragUpdates++;
              FocusManager.instance.primaryFocus?.unfocus();
            }
            return false;
          },
          child: child,
        ),
      );
      await _openKeyboard(tester);
      await _type(tester, '1');

      await tester.drag(find.byKey(_hourWheelKey), const Offset(0, -80));
      await tester.pumpAndSettle();

      final input = tester.widget<CupertinoTextField>(find.byKey(_inputKey));
      expect(ancestorDragStarts, 1);
      expect(ancestorDragUpdates, 0);
      expect(_selectedHour(tester), isNot(1));
      expect(input.controller!.text, isEmpty);
      expect(input.focusNode!.hasFocus, isTrue);
      expect(tester.testTextInput.isVisible, isTrue);
    },
  );

  testWidgets(
    'dismissing and reopening numeric entry works after committed or partial input',
    (tester) async {
      await _mountPicker(tester, initialTime: DateTime(2026, 10, 2, 10, 43));

      Future<void> makeKeyboardVisible() async {
        tester.view.viewInsets = const FakeViewPadding(bottom: 300);
        await tester.pump();
      }

      Future<void> dismissKeyboard() async {
        tester.testTextInput.hide();
        tester.view.viewInsets = FakeViewPadding.zero;
        await tester.pump();
        await tester.pumpAndSettle();
      }

      await _openKeyboard(tester);
      await makeKeyboardVisible();
      await _type(tester, '1234');
      expect(_selectedHour(tester), 12);
      expect(_selectedMinute(tester), 34);

      // Dismissal after a completed edit retains the wheel values and leaves
      // the selection band available for another entry session.
      await dismissKeyboard();
      expect(find.byKey(_inputKey), findsNothing);
      await _openKeyboard(tester);
      expect(find.byKey(_inputKey), findsOneWidget);
      expect(_selectedHour(tester), 12);
      expect(_selectedMinute(tester), 34);
      expect(
        tester
            .widget<CupertinoTextField>(find.byKey(_inputKey))
            .controller!
            .text,
        isEmpty,
      );

      // A partial entry can also be dismissed; the next session starts fresh.
      await makeKeyboardVisible();
      await _type(tester, '1');
      await dismissKeyboard();
      expect(find.byKey(_inputKey), findsNothing);
      await _openKeyboard(tester);
      expect(
        tester
            .widget<CupertinoTextField>(find.byKey(_inputKey))
            .controller!
            .text,
        isEmpty,
      );
      await _type(tester, '3');
      expect(_selectedHour(tester), 3);
      expect(_selectedMinute(tester), 34);
      expect(tester.testTextInput.isVisible, isTrue);

      // Reopen again after another dismiss to guard against one-shot tap
      // handlers or stale focus/controller state.
      await makeKeyboardVisible();
      await dismissKeyboard();
      expect(find.byKey(_inputKey), findsNothing);
      await _openKeyboard(tester);
      expect(find.byKey(_inputKey), findsOneWidget);
      expect(_selectedHour(tester), 3);
      expect(_selectedMinute(tester), 34);
      expect(tester.testTextInput.isVisible, isTrue);
    },
  );

  testWidgets('selection bar reopens after manual wheel interaction', (
    tester,
  ) async {
    await _mountPicker(tester, initialTime: DateTime(2026, 10, 2, 10, 43));
    await _openKeyboard(tester);
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pump();

    tester.testTextInput.hide();
    tester.view.viewInsets = FakeViewPadding.zero;
    await tester.pumpAndSettle();
    expect(find.byKey(_inputKey), findsNothing);

    await tester.drag(find.byKey(_hourWheelKey), const Offset(0, -80));
    await tester.pumpAndSettle();
    final hourAfterWheelDrag = _selectedHour(tester);
    expect(hourAfterWheelDrag, isNot(10));

    await tester.tapAt(tester.getRect(find.byKey(_minuteWheelKey)).center);
    await tester.pumpAndSettle();
    expect(find.byKey(_inputKey), findsOneWidget);
    expect(
      tester
          .widget<CupertinoTextField>(find.byKey(_inputKey))
          .focusNode!
          .hasFocus,
      isTrue,
    );
    expect(tester.testTextInput.isVisible, isTrue);
    expect(_selectedHour(tester), hourAfterWheelDrag);
    expect(_selectedMinute(tester), 43);
  });

  testWidgets('dragging the wheel before numeric entry still spins it', (
    tester,
  ) async {
    await _mountPicker(tester, initialTime: DateTime(2026, 10, 2, 1));

    final hourWheel = find.byKey(_hourWheelKey);
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
    expect(find.byKey(_inputKey), findsNothing);
  });
}

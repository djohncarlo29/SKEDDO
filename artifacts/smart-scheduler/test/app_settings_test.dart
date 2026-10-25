import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_scheduler/app_settings.dart';
import 'package:smart_scheduler/services/app_database.dart';
import 'package:smart_scheduler/services/local_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  const systemCalendarChannel = MethodChannel(
    'com.smartscheduler/system_calendar',
  );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    SharedPreferences.resetStatic();
    appSystemFirstDayOfWeekNotifier.value = 'Sunday';
    appStartOfWeekUsesSystemNotifier.value = true;
    appStartOfWeekNotifier.value = 'Sunday';
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(systemCalendarChannel, (call) async => 0);
    appLiquidGlassOpacityNotifier.value = liquidGlassOpacityForSliderPosition(
      kDefaultLiquidGlassSliderPosition,
    );
    await LocalStorage.instance.useDatabaseForTesting(
      AppDatabase(NativeDatabase.memory()),
    );
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(systemCalendarChannel, null);
    await LocalStorage.instance.resetDatabaseForTesting();
  });

  test('first weekday defaults to the detected system value', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(systemCalendarChannel, (call) async => 3);

    await loadAppSettings();

    expect(appSystemFirstDayOfWeekNotifier.value, 'Wednesday');
    expect(appStartOfWeekUsesSystemNotifier.value, isTrue);
    expect(appStartOfWeekNotifier.value, 'Wednesday');
  });

  test('legacy saved first weekday remains an app-only choice', () async {
    SharedPreferences.setMockInitialValues({
      'app_start_of_week': 'Saturday',
    });

    await loadAppSettings();

    expect(appStartOfWeekUsesSystemNotifier.value, isFalse);
    expect(appStartOfWeekNotifier.value, 'Saturday');
  });

  test('custom first weekday choice persists across reloads', () async {
    appStartOfWeekUsesSystemNotifier.value = false;
    appStartOfWeekNotifier.value = 'Thursday';
    await saveAppSetting('First Day of Week', 'Thursday');

    appStartOfWeekUsesSystemNotifier.value = true;
    appStartOfWeekNotifier.value = 'Sunday';
    await loadAppSettings();

    expect(appStartOfWeekUsesSystemNotifier.value, isFalse);
    expect(appStartOfWeekNotifier.value, 'Thursday');
  });

  test('calendar weekday columns and month offsets follow all seven starts', () {
    final expectedOffsets = <String, int>{
      'Sunday': 4,
      'Monday': 3,
      'Tuesday': 2,
      'Wednesday': 1,
      'Thursday': 0,
      'Friday': 6,
      'Saturday': 5,
    };
    final expectedLetters = <String, List<String>>{
      'Sunday': ['S', 'M', 'T', 'W', 'T', 'F', 'S'],
      'Monday': ['M', 'T', 'W', 'T', 'F', 'S', 'S'],
      'Tuesday': ['T', 'W', 'T', 'F', 'S', 'S', 'M'],
      'Wednesday': ['W', 'T', 'F', 'S', 'S', 'M', 'T'],
      'Thursday': ['T', 'F', 'S', 'S', 'M', 'T', 'W'],
      'Friday': ['F', 'S', 'S', 'M', 'T', 'W', 'T'],
      'Saturday': ['S', 'S', 'M', 'T', 'W', 'T', 'F'],
    };

    for (final day in kFirstDayOfWeekOptions) {
      final startIndex = firstDayOfWeekIndexForName(day);
      expect(
        calendarWeekdayColumnForDate(
          DateTime(2026, 10, 25),
          firstDay: day,
        ),
        (7 - startIndex) % 7,
      );
      expect(calendarMonthStartOffset(2026, 10, firstDay: day), expectedOffsets[day]);
      expect(calendarWeekdayHeaderLetters(firstDay: day), expectedLetters[day]);
    }
  });

  test('Liquid Glass defaults to 50% when no value is stored', () async {
    await loadAppSettings();

    expect(
      liquidGlassSliderPositionForOpacity(appLiquidGlassOpacityNotifier.value),
      kDefaultLiquidGlassSliderPosition,
    );
  });

  test('Liquid Glass restores the changed slider value after reload', () async {
    const changedPosition = 0.73;
    final changedValue = liquidGlassOpacityForSliderPosition(changedPosition);
    await saveAppSetting('Liquid Glass', changedValue.toString());

    appLiquidGlassOpacityNotifier.value = liquidGlassOpacityForSliderPosition(
      kDefaultLiquidGlassSliderPosition,
    );
    await loadAppSettings();

    expect(
      liquidGlassSliderPositionForOpacity(appLiquidGlassOpacityNotifier.value),
      changedPosition,
    );
  });
}

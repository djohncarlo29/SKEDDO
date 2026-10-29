import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_scheduler/ai/parsed_date.dart';
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
    appAccentNotifier.value = 5;
    appAccentUsesSystemNotifier.value = false;
    appSystemFirstDayOfWeekNotifier.value = 'Sunday';
    appStartOfWeekUsesSystemNotifier.value = true;
    appStartOfWeekNotifier.value = 'Sunday';
    appDateFormatNotifier.value = AppDateFormat.monthDayYearSlash;
    appCustomDateFormatNotifier.value = AppDateFormat.monthDayYearSlash;
    appSystemDateFormatNotifier.value = AppDateFormat.monthDayYearSlash;
    appSystemDateFormatPatternNotifier.value = null;
    appSystemDateFormatSampleNotifier.value = null;
    appDateFormatUsesSystemNotifier.value = false;
    appDateLocaleNotifier.value = DateLocalePreference.monthFirst;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          systemCalendarChannel,
          (call) async => switch (call.method) {
            'getFirstDayOfWeekIndex' => 0,
            'getDateFormatPattern' => 'M/d/yyyy',
            _ => null,
          },
        );
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
        .setMockMethodCallHandler(
          systemCalendarChannel,
          (call) async => switch (call.method) {
            'getFirstDayOfWeekIndex' => 3,
            'getDateFormatPattern' => 'M/d/yyyy',
            _ => null,
          },
        );

    await loadAppSettings();

    expect(appSystemFirstDayOfWeekNotifier.value, 'Wednesday');
    expect(appStartOfWeekUsesSystemNotifier.value, isTrue);
    expect(appStartOfWeekNotifier.value, 'Wednesday');
  });

  test('system accent mode restores independently of the selected swatch', () async {
    SharedPreferences.setMockInitialValues({
      'app_accent_index': 2,
      'app_accent_uses_system': true,
    });

    await loadAppSettings();

    expect(appAccentNotifier.value, 2);
    expect(appAccentUsesSystemNotifier.value, isTrue);
  });

  test('accent mode defaults to the existing app-only selection', () async {
    await loadAppSettings();

    expect(appAccentUsesSystemNotifier.value, isFalse);
    expect(appAccentNotifier.value, 5);
  });

  test('mirrored settings use a consistent System trailing value', () {
    expect(
      mirrorSystemSettingTrailingValue(
        usesSystem: true,
        appOnlyValue: 'Monday',
        systemDetail: 'Monday',
      ),
      'System (Monday)',
    );
    expect(
      mirrorSystemSettingTrailingValue(
        usesSystem: true,
        appOnlyValue: 'Monday',
      ),
      'System',
    );
    expect(
      mirrorSystemSettingTrailingValue(
        usesSystem: false,
        appOnlyValue: 'Monday',
      ),
      'Monday',
    );
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

  test('Date Format defaults to the requested test selection', () async {
    await loadAppSettings();

    expect(appDateFormatNotifier.value, AppDateFormat.monthDayYearSlash);
    expect(appDateFormatNotifier.value.sample, '08/19/2026');
  });

  test('Date Format selection persists and keeps parser order aligned', () async {
    appDateFormatNotifier.value = AppDateFormat.dayMonthYearDot;
    appCustomDateFormatNotifier.value = AppDateFormat.dayMonthYearDot;
    appDateFormatUsesSystemNotifier.value = false;
    appDateLocaleNotifier.value =
        AppDateFormat.dayMonthYearDot.parserLocalePreference;
    await saveAppSetting('Date Format', appDateFormatNotifier.value.sample);

    appDateFormatNotifier.value = AppDateFormat.monthDayYearSlash;
    appCustomDateFormatNotifier.value = AppDateFormat.monthDayYearSlash;
    appDateLocaleNotifier.value = DateLocalePreference.monthFirst;
    await loadAppSettings();

    expect(appDateFormatNotifier.value, AppDateFormat.dayMonthYearDot);
    expect(appDateLocaleNotifier.value, DateLocalePreference.dayFirst);
  });

  test('native date patterns map to supported order and separators', () {
    expect(
      AppDateFormat.fromSystemPattern('M/d/yy'),
      AppDateFormat.monthDayYearShortSlash,
    );
    expect(
      AppDateFormat.fromSystemPattern('dd.MM.yyyy'),
      AppDateFormat.dayMonthYearDot,
    );
    expect(
      AppDateFormat.fromSystemPattern('yyyy-MM-dd'),
      AppDateFormat.yearMonthDayDash,
    );
  });

  test('System date format persists separately from App Only choice', () async {
    appCustomDateFormatNotifier.value = AppDateFormat.dayMonthYearDot;
    appSystemDateFormatNotifier.value = AppDateFormat.dayMonthYearSlash;
    appDateFormatUsesSystemNotifier.value = true;
    appDateFormatNotifier.value = AppDateFormat.dayMonthYearSlash;
    await saveAppSetting('Date Format', 'System');

    appCustomDateFormatNotifier.value = AppDateFormat.monthDayYearSlash;
    appDateFormatUsesSystemNotifier.value = false;
    appDateFormatNotifier.value = AppDateFormat.monthDayYearSlash;
    await loadAppSettings();

    expect(appDateFormatUsesSystemNotifier.value, isTrue);
    expect(appCustomDateFormatNotifier.value, AppDateFormat.dayMonthYearDot);
    expect(appDateFormatNotifier.value, AppDateFormat.monthDayYearSlash);
    expect(
      formatAppDate(DateTime(2026, 8, 19)),
      '8/19/2026',
      reason: 'System mode should use the native pattern, not its mapped preset.',
    );
    expect(appSystemDateFormatSampleNotifier.value, '8/19/2026');
  });
}

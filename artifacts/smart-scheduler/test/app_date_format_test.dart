import 'package:flutter_test/flutter_test.dart';
import 'package:smart_scheduler/app_settings.dart';

void main() {
  final sampleDate = DateTime(2026, 8, 19);

  test('date format options produce the requested exact samples', () {
    final expected = <String>[
      '19/08/2026',
      '08/19/26',
      '19/08/26',
      '08/19/2026',
      '19.08.2026',
      '19-08-2026',
      '2026/08/19',
      '2026.08.19',
      '2026-08-19',
    ];

    expect(
      AppDateFormat.values.map((format) => format.sample).toList(),
      expected,
    );
    expect(
      AppDateFormat.values.map((format) => format.format(sampleDate)).toList(),
      expected,
    );
  });

  test('the test default is 08/19/2026', () {
    expect(appDateFormatNotifier.value, AppDateFormat.monthDayYearSlash);
    expect(formatAppDate(sampleDate), '08/19/2026');
  });

  test('stored date strings use the selected display format', () {
    final previous = appDateFormatNotifier.value;
    addTearDown(() => appDateFormatNotifier.value = previous);

    appDateFormatNotifier.value = AppDateFormat.yearMonthDayDash;
    expect(formatStoredAppDate('August 19, 2026'), '2026-08-19');
    expect(formatStoredAppDate('2026-08-19'), '2026-08-19');

    appDateFormatNotifier.value = AppDateFormat.dayMonthYearDot;
    expect(formatStoredAppDate('19/08/2026'), '19.08.2026');
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:smart_scheduler/app_settings.dart';

void main() {
  final sampleDate = DateTime(2026, 8, 19);

  test('date formats produce the requested exact samples', () {
    final expected = <String>[
      '19/08/2026',
      '19/08/26',
      '19.08.2026',
      '19.08.26',
      '19-08-2026',
      '19-08-26',
      '08/19/2026',
      '08/19/26',
      '08.19.2026',
      '08.19.26',
      '08-19-2026',
      '08-19-26',
      '2026/08/19',
      '2026.08.19',
      '2026-08-19',
    ];

    expect(
      AppDateFormat.values.map((format) => format.format(sampleDate)).toList(),
      expected,
    );
    final today = DateTime.now();
    expect(
      AppDateFormat.values.map((format) => format.sample).toList(),
      AppDateFormat.values.map((format) => format.format(today)).toList(),
    );
  });

  test('date format examples use the date they are built with', () {
    for (final format in AppDateFormat.values) {
      expect(
        format.contextFooterFor(sampleDate),
        'Format Example:\n'
        '• Short: ${format.format(sampleDate)}\n'
        '• Medium: ${format.formatMedium(sampleDate)}\n'
        '• Long: ${format.formatLong(sampleDate)}\n'
        '• Full: ${format.formatFull(sampleDate)}',
      );
    }

    final today = DateTime.now();
    for (final format in AppDateFormat.values) {
      expect(format.sample, format.format(today));
      expect(format.contextFooter, format.contextFooterFor(today));
    }
  });

  test('Medium format supports full and yearless dates', () {
    final date = DateTime(2026, 10, 29);
    final dayFirst = [
      AppDateFormat.dayMonthYearSlash,
      AppDateFormat.dayMonthYearShortSlash,
      AppDateFormat.dayMonthYearDot,
      AppDateFormat.dayMonthYearShortDot,
      AppDateFormat.dayMonthYearDash,
      AppDateFormat.dayMonthYearShortDash,
    ];

    for (final format in AppDateFormat.values) {
      final expected = dayFirst.contains(format) ? '29 Oct' : 'Oct 29';
      expect(format.formatMedium(date, includeYear: false), expected);
      expect(
        format.formatMedium(date),
        dayFirst.contains(format) ? '29 Oct 2026' : 'Oct 29, 2026',
      );
    }
  });

  test('the test default is month/day/year', () {
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

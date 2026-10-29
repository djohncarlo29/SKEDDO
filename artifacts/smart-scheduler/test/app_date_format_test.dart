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

  test('each date format has its requested context footer examples', () {
    final short = AppDateFormat.values.map((format) => format.sample).toList();
    final medium = [
      '19 Aug 2026',
      'Aug 19, 2026',
      '19 Aug 2026',
      'Aug 19, 2026',
      '19 Aug 2026',
      '19 Aug 2026',
      'Aug 19, 2026',
      'Aug 19, 2026',
      'Aug 19, 2026',
    ];
    final long = [
      '19 August 2026',
      'August 19, 2026',
      '19 August 2026',
      'August 19, 2026',
      '19 August 2026',
      '19 August 2026',
      'August 19, 2026',
      'August 19, 2026',
      'August 19, 2026',
    ];
    final full = [
      'Wednesday, 19 August 2026',
      'Wednesday, August 19, 2026',
      'Wednesday, 19 August 2026',
      'Wednesday, August 19, 2026',
      'Wednesday, 19 August 2026',
      'Wednesday, 19 August 2026',
      'Wednesday, August 19, 2026',
      'Wednesday, August 19, 2026',
      'Wednesday, August 19, 2026',
    ];

    for (var i = 0; i < AppDateFormat.values.length; i++) {
      expect(
        AppDateFormat.values[i].contextFooter,
        'Format Example:\n'
        '• Short: ${short[i]}\n'
        '• Medium: ${medium[i]}\n'
        '• Long: ${long[i]}\n'
        '• Full: ${full[i]}',
      );
    }
  });

  test('Medium format supports full and yearless dates', () {
    final date = DateTime(2026, 10, 29);
    final dayFirst = [
      AppDateFormat.dayMonthYearSlash,
      AppDateFormat.dayMonthYearShortSlash,
      AppDateFormat.dayMonthYearDot,
      AppDateFormat.dayMonthYearDash,
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

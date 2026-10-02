import 'package:flutter_test/flutter_test.dart';
import 'package:smart_scheduler/ai/parsed_date.dart';
import 'package:smart_scheduler/services/event_model.dart';
import 'package:smart_scheduler/services/recurrence_expander.dart';

void main() {
  ScheduledEvent customEvent(DateTime baseDate, Map<String, dynamic> config) {
    return ScheduledEvent(
      id: 'custom',
      title: 'Custom repeat',
      date: '${baseDate.year}-${baseDate.month}-${baseDate.day}',
      repeat: 'Custom repeat',
      customRepeatConfig: config,
      parsedDate: ParsedDate(absoluteDate: baseDate),
    );
  }

  List<DateTime> expand(
    DateTime baseDate,
    Map<String, dynamic> config,
    DateTime from,
    DateTime to,
  ) => RecurrenceExpander.expand(
    customEvent(baseDate, config),
    from,
    to,
  ).map((event) => event.parsedDate!.absoluteDate!).toList();

  Map<String, dynamic> monthly(int position, int day) => {
    'frequency': 'Monthly',
    'everyCount': 1,
    'monthlyMode': 'OnThe',
    'onThePositionIndex': position,
    'onTheDayIndex': day,
    'positionOptionsVersion': 2,
  };

  test('next to last weekday counts matching dates, not a fixed ordinal', () {
    // February 2026 has four Mondays; March has five.
    expect(
      expand(
        DateTime(2026, 2, 1),
        monthly(5, 0),
        DateTime(2026, 2, 1),
        DateTime(2026, 3, 31),
      ),
      [DateTime(2026, 2, 16), DateTime(2026, 3, 23)],
    );
  });

  test('day and weekend-day groups select calendar dates in order', () {
    final base = DateTime(2026, 2, 1);
    final from = DateTime(2026, 2, 1);
    final to = DateTime(2026, 2, 28);

    expect(
      expand(base, monthly(5, 7), from, to),
      [DateTime(2026, 2, 27)],
      reason: 'next to last day is the day before the month ends',
    );
    expect(expand(base, monthly(6, 7), from, to), [
      DateTime(2026, 2, 28),
    ], reason: 'last day is the month end');
    expect(
      expand(base, monthly(5, 9), from, to),
      [DateTime(2026, 2, 22)],
      reason: 'weekend days are counted together in calendar order',
    );
    expect(
      expand(base, monthly(6, 8), from, to),
      [DateTime(2026, 2, 27)],
      reason: 'last weekday is the final Monday–Friday date',
    );
  });

  test('a missing fifth weekday skips that month', () {
    final februaryConfig = monthly(4, 0);
    expect(
      expand(
        DateTime(2026, 2, 1),
        februaryConfig,
        DateTime(2026, 2, 1),
        DateTime(2026, 2, 28),
      ),
      isEmpty,
    );
    expect(
      expand(
        DateTime(2026, 2, 1),
        februaryConfig,
        DateTime(2026, 2, 1),
        DateTime(2026, 3, 31),
      ),
      [DateTime(2026, 3, 30)],
    );
  });

  test('yearly ordinal options use the union of supported selected months', () {
    // February 2026 has four Mondays; March has five.
    expect(
      RecurrenceExpander.availableYearlyPositionIndices(
        year: 2026,
        selectedMonths: {2},
        dayIndex: 0,
      ),
      isNot(contains(4)),
    );
    expect(
      RecurrenceExpander.availableYearlyPositionIndices(
        year: 2026,
        selectedMonths: {2, 3},
        dayIndex: 0,
      ),
      contains(4),
    );
    expect(
      RecurrenceExpander.availableYearlyMonthIndices(
        year: 2026,
        selectedMonths: {2, 3},
        positionIndex: 4,
        dayIndex: 0,
      ),
      [3],
    );
  });

  test('yearly grouped weekday rules use the selected month', () {
    expect(
      expand(
        DateTime(2026, 1, 1),
        {
          'frequency': 'Yearly',
          'everyCount': 1,
          'selectedMonths': [1],
          'yearlyDaysEnabled': true,
          'yearlyPositionIndex': 5,
          'yearlyDayIndex': 8,
          'positionOptionsVersion': 2,
        },
        DateTime(2026, 1, 1),
        DateTime(2027, 1, 31),
      ),
      [DateTime(2026, 1, 29), DateTime(2027, 1, 28)],
    );
  });

  test('legacy saved last-position index remains last after the insertion', () {
    final legacy = monthly(5, 8)..remove('positionOptionsVersion');
    final current = monthly(5, 8);

    expect(
      expand(
        DateTime(2026, 2, 1),
        legacy,
        DateTime(2026, 2, 1),
        DateTime(2026, 2, 28),
      ),
      [DateTime(2026, 2, 27)],
    );
    expect(
      expand(
        DateTime(2026, 2, 1),
        current,
        DateTime(2026, 2, 1),
        DateTime(2026, 2, 28),
      ),
      [DateTime(2026, 2, 26)],
    );
  });
}

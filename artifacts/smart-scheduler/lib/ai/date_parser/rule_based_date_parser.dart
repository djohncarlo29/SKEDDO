import '../interfaces.dart';
import '../parsed_date.dart';

/// Pure-Dart temporal normalizer used by event creation and offline search.
///
/// The parser deliberately stores meaning rather than surface syntax:
/// `Aug 12`, `12 August`, `2026/08/12`, and `08/12/2026` all become a
/// canonical date; times become `HH:mm`; ranges and recurrence rules retain
/// both boundaries and the original expression.
class RuleBasedDateParser implements DateParser {
  RuleBasedDateParser({
    this.localePreference = DateLocalePreference.monthFirst,
  });

  DateLocalePreference localePreference;

  static const _weekdays = <String, int>{
    'monday': DateTime.monday, 'mon': DateTime.monday,
    'tuesday': DateTime.tuesday, 'tue': DateTime.tuesday,
    'wednesday': DateTime.wednesday, 'wed': DateTime.wednesday,
    'thursday': DateTime.thursday, 'thu': DateTime.thursday,
    'friday': DateTime.friday, 'fri': DateTime.friday,
    'saturday': DateTime.saturday, 'sat': DateTime.saturday,
    'sunday': DateTime.sunday, 'sun': DateTime.sunday,
  };

  static const _months = <String, int>{
    'january': 1, 'jan': 1, 'february': 2, 'feb': 2,
    'march': 3, 'mar': 3, 'april': 4, 'apr': 4, 'may': 5,
    'june': 6, 'jun': 6, 'july': 7, 'jul': 7, 'august': 8, 'aug': 8,
    'september': 9, 'sep': 9, 'sept': 9, 'october': 10, 'oct': 10,
    'november': 11, 'nov': 11, 'december': 12, 'dec': 12,
  };

  static const _numbers = <String, int>{
    'a': 1, 'an': 1, 'one': 1, 'two': 2, 'three': 3, 'four': 4,
    'five': 5, 'six': 6, 'seven': 7, 'eight': 8, 'nine': 9, 'ten': 10,
    'eleven': 11, 'twelve': 12, 'thirteen': 13, 'fourteen': 14,
    'fifteen': 15, 'sixteen': 16, 'seventeen': 17, 'eighteen': 18,
    'nineteen': 19, 'twenty': 20, 'thirty': 30,
  };

  @override
  ParsedDate parse(
    String input, {
    DateTime? now,
    DateLocalePreference? localePreference,
  }) {
    final raw = input.trim();
    if (raw.isEmpty) return ParsedDate(rawInput: input);
    final ref = now ?? DateTime.now();
    final preference = localePreference ?? this.localePreference;
    final text = _clean(raw);

    final recurring = _parseRecurring(text, ref, raw, preference);
    if (recurring != null) return recurring;

    final deadline = _parseDeadline(text, ref, raw, preference);
    if (deadline != null) return deadline;

    final isoDateTime = RegExp(
      r'^(\d{4})[-/.](\d{1,2})[-/.](\d{1,2})(?:t|\s+)(.+)$',
    ).firstMatch(text);
    if (isoDateTime != null) {
      final date = _validDate(
        int.parse(isoDateTime.group(1)!),
        int.parse(isoDateTime.group(2)!),
        int.parse(isoDateTime.group(3)!),
      );
      final time = _parseTime(isoDateTime.group(4)!);
      if (date != null && time != null) return _combine(date, time, raw);
    }

    final compound = _parseDateAndTime(text, ref, raw, preference);
    if (compound != null) return compound;

    final timeRange = _parseTimeRange(text, raw);
    if (timeRange != null) return _timeRangeResult(timeRange, raw);

    final time = _parseTime(text);
    if (time != null) return _timeResult(time, raw);

    return _parseDateOnly(text, ref, raw, preference) ??
        ParsedDate(rawInput: raw);
  }

  String _clean(String value) => value
      .toLowerCase()
      .replaceAll('–', '-')
      .replaceAll('—', '-')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  ParsedDate _result({
    required String raw,
    DateTime? date,
    DateTime? start,
    DateTime? end,
    DateTime? deadline,
    TemporalPrecision? datePrecision,
    TimePrecision? timePrecision,
    String? canonicalTime,
    String? canonicalEndTime,
    List<DateTime> alternateDates = const [],
    String? recurrence,
    int? recurrenceInterval,
    List<int> recurrenceWeekdays = const [],
    String? recurrenceOrdinal,
    bool recurring = false,
    RecurrenceType? recurrenceType,
    int? recurrenceWeekday,
  }) {
    final dateOnly = date == null ? null : _dateOnly(date);
    final startValue = start ?? dateOnly;
    return ParsedDate(
      absoluteDate: dateOnly,
      startDateTime: startValue,
      endDateTime: end,
      deadlineDateTime: deadline,
      canonicalTime: canonicalTime,
      canonicalEndTime: canonicalEndTime,
      datePrecision: datePrecision ?? (dateOnly == null ? null : TemporalPrecision.day),
      timePrecision: timePrecision,
      alternateDates: alternateDates,
      recurrence: recurrence,
      recurrenceInterval: recurrenceInterval,
      recurrenceWeekdays: recurrenceWeekdays,
      recurrenceOrdinal: recurrenceOrdinal,
      isRecurring: recurring,
      recurrenceType: recurrenceType,
      recurrenceWeekday: recurrenceWeekday,
      rawInput: raw,
    );
  }

  // ── Date + time combinations ──────────────────────────────────────────────

  ParsedDate? _parseDateAndTime(
    String text,
    DateTime ref,
    String raw,
    DateLocalePreference preference,
  ) {
    // “tomorrow morning”, “this afternoon”, and similar phrases.
    final dayPart = RegExp(
      r'^(tomorrow morning|tomorrow afternoon|tomorrow evening|'
      r'tomorrow night|this morning|this afternoon|this evening|'
      r'later today|today|tomorrow|yesterday|tonight)\s*'
      r'(?:at\s*)?(.*)$',
    ).firstMatch(text);
    if (dayPart != null) {
      final phrase = dayPart.group(1)!;
      final basePhrase = phrase.contains('tomorrow')
          ? 'tomorrow'
          : phrase.contains('yesterday')
          ? 'yesterday'
          : 'today';
      final base = _parseDateOnly(basePhrase, ref, raw, preference);
      if (base == null) return null;
      final suffix = dayPart.group(2)!.trim();
      final t = suffix.isEmpty ? null : _parseTime(suffix);
      if (t != null) return _combine(base.absoluteDate!, t, raw);
      final qualifier = _qualifier(dayPart.group(1)!);
      // Do not silently downgrade an invalid explicit time to a date-only
      // result. This is important when EventStore combines separate fields.
      if (suffix.isNotEmpty && qualifier == null) return null;
      return _result(
        raw: raw,
        date: base.absoluteDate,
        datePrecision: TemporalPrecision.day,
        timePrecision: qualifier == null ? null : TimePrecision.approximate,
      );
    }

    // “August 12 from 8 to 10 PM” and “tomorrow from 8 AM to 10 AM”.
    final fromTo = RegExp(r'^(.+?)\s+from\s+(.+?)\s+(?:to|until)\s+(.+)$')
        .firstMatch(text);
    if (fromTo != null) {
      final date = _parseDateOnly(fromTo.group(1)!, ref, raw, preference);
      if (date != null) {
        final range = _parseTimeRange(
          '${fromTo.group(2)} to ${fromTo.group(3)}',
          raw,
        );
        if (range != null) {
          return _combineRange(date.absoluteDate!, range, raw);
        }
      }
    }

    // “date at time”, “time on date”, “date time”, including punctuation-free.
    final at = RegExp(r'^(.+?)\s+at\s+(.+)$').firstMatch(text);
    if (at != null) {
      final date = _parseDateOnly(at.group(1)!, ref, raw, preference);
      final time = _parseTime(at.group(2)!);
      if (date != null && time != null) return _combine(date.absoluteDate!, time, raw);
    }
    final on = RegExp(r'^(.+?)\s+on\s+(.+)$').firstMatch(text);
    if (on != null) {
      final time = _parseTime(on.group(1)!);
      final date = _parseDateOnly(on.group(2)!, ref, raw, preference);
      if (date != null && time != null) return _combine(date.absoluteDate!, time, raw);
    }

    // “Aug 12 at 8 PM” is covered above; this handles “Aug 12 8 PM” and
    // “Tuesday 8 PM” without making a bare “8” look like a time.
    final timeMatch = RegExp(
      r'(\d{1,4}(?::\d{2})?\s*(?:am|pm)|'
      r'\d{1,2}\s+(?:in the morning|in the evening|at night)|'
      r'\d{1,2}:\d{2})\s*$',
    ).firstMatch(text);
    if (timeMatch != null) {
      final dateText = text.substring(0, timeMatch.start).trim();
      final date = _parseDateOnly(dateText, ref, raw, preference);
      final time = _parseTime(timeMatch.group(1)!);
      if (date != null && time != null) return _combine(date.absoluteDate!, time, raw);
    }
    return null;
  }

  ParsedDate _combine(DateTime date, _ParsedTime time, String raw) {
    final start = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    return _result(
      raw: raw,
      date: date,
      start: start,
      canonicalTime: time.canonical,
      datePrecision: TemporalPrecision.day,
      timePrecision: time.precision,
    );
  }

  ParsedDate _combineRange(DateTime date, _TimeRange range, String raw) {
    final start = DateTime(date.year, date.month, date.day, range.start.hour, range.start.minute);
    var end = DateTime(date.year, date.month, date.day, range.end.hour, range.end.minute);
    if (end.isBefore(start)) end = end.add(const Duration(days: 1));
    return _result(
      raw: raw,
      date: date,
      start: start,
      end: end,
      canonicalTime: range.start.canonical,
      canonicalEndTime: range.end.canonical,
      datePrecision: TemporalPrecision.day,
      timePrecision: TimePrecision.minute,
    );
  }

  // ── Time parsing ───────────────────────────────────────────────────────────

  _ParsedTime? _parseTime(String value) {
    var text = _clean(value)
        .replaceAll(RegExp(r'^(around|about|by|before|after|until|from|starting at)\s+'), '')
        .replaceAll(' o\'clock', '');
    if (text == 'noon') return const _ParsedTime(12, 0);
    if (text == 'midnight') return const _ParsedTime(0, 0);

    var qualifier = '';
    if (text.contains(' in the morning')) {
      qualifier = 'morning';
      text = text.replaceFirst(' in the morning', '');
    } else if (text.contains(' in the evening')) {
      qualifier = 'evening';
      text = text.replaceFirst(' in the evening', '');
    } else if (text.contains(' at night')) {
      qualifier = 'night';
      text = text.replaceFirst(' at night', '');
    }
    if (text.startsWith('half past ')) {
      final base = _parseTime(text.substring(10));
      return base?.withMinute(30);
    }
    if (text.startsWith('quarter past ')) {
      final base = _parseTime(text.substring(13));
      return base?.withMinute(15);
    }
    if (text.startsWith('quarter to ')) {
      final base = _parseTime(text.substring(11));
      if (base == null) return null;
      final hour = base.hour == 0 ? 23 : base.hour - 1;
      return _ParsedTime(hour, 45, precision: base.precision);
    }

    for (final entry in _numbers.entries) {
      text = text.replaceAll(RegExp(r'\b' + entry.key + r'\b'), '${entry.value}');
    }
    // Compact 24-hour values such as "0830" or "2000".
    final compact = RegExp(r'^(\d{2})(\d{2})$').firstMatch(text);
    if (compact != null) {
      final hour = int.parse(compact.group(1)!);
      final minute = int.parse(compact.group(2)!);
      if (hour > 23 || minute > 59) return null;
      return _ParsedTime(hour, minute);
    }
    final spoken = RegExp(r'^(\d{1,2})\s+(\d{2})(?:\s*(am|pm))?$')
        .firstMatch(text);
    if (spoken != null) {
      var hour = int.parse(spoken.group(1)!);
      final minute = int.parse(spoken.group(2)!);
      final ampm = spoken.group(3);
      if (minute > 59) return null;
      if (ampm == 'pm' && hour != 12) hour += 12;
      if (ampm == 'am' && hour == 12) hour = 0;
      if (hour > 23) return null;
      return _ParsedTime(hour, minute);
    }
    final m12 = RegExp(r'^(\d{1,2})(?::(\d{2}))?\s*(am|pm)?$').firstMatch(text);
    if (m12 == null) return null;
    var hour = int.tryParse(m12.group(1)!);
    final minute = int.tryParse(m12.group(2) ?? '0');
    final ampm = m12.group(3);
    if (hour == null || minute == null || minute > 59) return null;
    if (ampm != null && (hour < 1 || hour > 12)) return null;
    if (ampm == null && (qualifier.isEmpty && hour > 23)) return null;
    if (ampm == null && qualifier.isEmpty && hour > 12) {
      return _ParsedTime(hour, minute);
    }
    if (ampm == 'pm' && hour != 12) hour += 12;
    if (ampm == 'am' && hour == 12) hour = 0;
    if (hour > 23) return null;
    if (qualifier == 'evening' || qualifier == 'night') {
      if (hour < 12) hour += 12;
    }
    return _ParsedTime(hour, minute);
  }

  _TimeRange? _parseTimeRange(String text, String raw) {
    final match = RegExp(r'^(.+?)\s*(?:-|to|until)\s*(.+)$').firstMatch(_clean(text));
    if (match == null) return null;
    var left = match.group(1)!;
    var right = match.group(2)!;
    // “8–10 PM” carries AM/PM only on the right.
    final rightTime = _parseTime(right);
    if (rightTime == null) return null;
    if (!RegExp(r'(?:am|pm|in the|at night)', caseSensitive: false).hasMatch(left)) {
      final suffix = right.toLowerCase().contains('pm') ? ' pm' : right.toLowerCase().contains('am') ? ' am' : '';
      left = '$left$suffix';
    }
    final leftTime = _parseTime(left);
    return leftTime == null ? null : _TimeRange(leftTime, rightTime);
  }

  ParsedDate _timeResult(_ParsedTime time, String raw) => _result(
    raw: raw,
    canonicalTime: time.canonical,
    timePrecision: time.precision,
  );

  ParsedDate _timeRangeResult(_TimeRange range, String raw) => _result(
    raw: raw,
    canonicalTime: range.start.canonical,
    canonicalEndTime: range.end.canonical,
    timePrecision: TimePrecision.minute,
  );

  // ── Date parsing ───────────────────────────────────────────────────────────

  ParsedDate? _parseDateOnly(
    String text,
    DateTime ref,
    String raw,
    DateLocalePreference preference,
  ) {
    var s = _clean(text)
        .replaceAll(RegExp(r'^(on|due|deadline)\s*:?\s+'), '')
        .replaceAll(' the ', ' ')
        .replaceAll(RegExp(r',+$'), '')
        .trim();
    final weekdayPrefix = RegExp(
      r'^(monday|tuesday|wednesday|thursday|friday|saturday|sunday|'
      r'mon|tue|wed|thu|fri|sat|sun),?(?:\s+(.*))?$',
    ).firstMatch(s);
    if (weekdayPrefix != null && weekdayPrefix.group(2)?.trim().isNotEmpty == true) {
      s = weekdayPrefix.group(2)!.trim();
    }
    if (s == 'today') return _result(raw: raw, date: _dateOnly(ref));
    if (s == 'tomorrow') return _result(raw: raw, date: _dateOnly(ref.add(const Duration(days: 1))));
    if (s == 'yesterday') return _result(raw: raw, date: _dateOnly(ref.subtract(const Duration(days: 1))));
    if (s == 'the day after tomorrow') {
      return _result(raw: raw, date: _dateOnly(ref.add(const Duration(days: 2))));
    }
    if (s == 'the day before yesterday') {
      return _result(raw: raw, date: _dateOnly(ref.subtract(const Duration(days: 2))));
    }

    final offset = RegExp(
      r'^(?:in\s+)?(.+?)\s+(day|days|week|weeks|month|months)\s+(from now|ago)$',
    )
        .firstMatch(s);
    final inOffset = RegExp(
      r'^in\s+(.+?)\s+(day|days|week|weeks|month|months)$',
    ).firstMatch(s);
    final offsetMatch = offset ?? inOffset;
    if (offsetMatch != null) {
      final n = _number(offsetMatch.group(1)!);
      if (n != null) {
        final unit = offsetMatch.group(2)!;
        final past = offset != null && offsetMatch.group(3) == 'ago';
        final amount = past ? -n : n;
        final date = unit.startsWith('month')
            ? DateTime(ref.year, ref.month + amount, ref.day)
            : ref.add(
                Duration(days: unit.startsWith('week') ? amount * 7 : amount),
              );
        return _result(raw: raw, date: _dateOnly(date));
      }
    }

    final weekend = RegExp(r'^(this|next|last)?\s*weekend$').firstMatch(s);
    if (weekend != null) {
      final thisSat = _nextWeekday(ref, DateTime.saturday);
      final date = weekend.group(1) == 'next'
          ? thisSat.add(const Duration(days: 7))
          : weekend.group(1) == 'last'
          ? thisSat.subtract(const Duration(days: 7))
          : thisSat;
      return _result(raw: raw, date: date);
    }

    if (s == 'this week' || s == 'next week' || s == 'last week') {
      final monday = _dateOnly(ref).subtract(Duration(days: ref.weekday - 1));
      final shift = s == 'next week' ? 7 : s == 'last week' ? -7 : 0;
      return _result(
        raw: raw,
        date: monday.add(Duration(days: shift)),
        datePrecision: TemporalPrecision.week,
      );
    }
    if (s == 'next month' || s == 'last month' || s == 'this month') {
      final shift = s == 'next month' ? 1 : s == 'last month' ? -1 : 0;
      final date = DateTime(ref.year, ref.month + shift, 1);
      return _result(raw: raw, date: date, datePrecision: TemporalPrecision.month);
    }
    if (s == 'next year' || s == 'last year' || s == 'this year') {
      final shift = s == 'next year' ? 1 : s == 'last year' ? -1 : 0;
      return _result(raw: raw, date: DateTime(ref.year + shift, 1, 1), datePrecision: TemporalPrecision.year);
    }
    if (s.contains('end of') || s.contains('start of') || s.contains('beginning of')) {
      final next = s.contains('next');
      if (s.contains('month')) {
        final month = DateTime(ref.year, ref.month + (next ? 1 : 0), 1);
        final date = s.contains('end') ? DateTime(month.year, month.month + 1, 0) : month;
        return _result(raw: raw, date: date, datePrecision: TemporalPrecision.approximate);
      }
      if (s.contains('week')) {
        final monday = _dateOnly(ref).subtract(Duration(days: ref.weekday - 1));
        return _result(raw: raw, date: monday.add(Duration(days: next ? 13 : 6)), datePrecision: TemporalPrecision.approximate);
      }
      if (s.contains('year')) {
        final year = ref.year + (next ? 1 : 0);
        final date = s.contains('end')
            ? DateTime(year, 12, 31)
            : DateTime(year, 1, 1);
        return _result(raw: raw, date: date, datePrecision: TemporalPrecision.approximate);
      }
    }
    if (s == 'later today') return _result(raw: raw, date: _dateOnly(ref), datePrecision: TemporalPrecision.approximate);
    if (s == 'later this week' || s == 'sometime next week') {
      final monday = _dateOnly(ref).subtract(Duration(days: ref.weekday - 1));
      return _result(raw: raw, date: monday.add(Duration(days: s.contains('next') ? 7 : 0)), datePrecision: TemporalPrecision.approximate);
    }

    for (final prefix in ['next ', 'last ', 'this ']) {
      if (s.startsWith(prefix)) {
        final weekday = _weekdays[s.substring(prefix.length)];
        if (weekday != null) {
          final date = prefix == 'next '
              ? _nextWeekday(ref, weekday, skipToday: true)
              : prefix == 'last '
              ? _prevWeekday(ref, weekday)
              : _dateOnly(ref).subtract(Duration(days: ref.weekday - 1)).add(Duration(days: weekday - 1));
          return _result(raw: raw, date: date);
        }
      }
    }
    final bareWeekday = _weekdays[s];
    if (bareWeekday != null) return _result(raw: raw, date: _nextWeekday(ref, bareWeekday));

    var m = RegExp(
      r'^(\d{4})[-/.](\d{1,2})[-/.](\d{1,2})(?:(?:t|\s+).*)?$',
    ).firstMatch(s);
    if (m != null) {
      final date = _validDate(int.parse(m.group(1)!), int.parse(m.group(2)!), int.parse(m.group(3)!));
      if (date != null) return _result(raw: raw, date: date);
    }
    m = RegExp(r'^(\d{4})(\d{2})(\d{2})$').firstMatch(s);
    if (m != null) {
      final date = _validDate(int.parse(m.group(1)!), int.parse(m.group(2)!), int.parse(m.group(3)!));
      if (date != null) return _result(raw: raw, date: date);
    }

    m = RegExp(r'^(\d{1,2})[/\-.](\d{1,2})[/\-.](\d{2,4})$').firstMatch(s);
    if (m != null) {
      var year = int.parse(m.group(3)!);
      if (year < 100) year += 2000;
      final a = int.parse(m.group(1)!);
      final b = int.parse(m.group(2)!);
      DateTime? preferred;
      DateTime? alternate;
      if (a > 12 && b <= 12) {
        preferred = _validDate(year, b, a);
      } else if (b > 12 && a <= 12) {
        preferred = _validDate(year, a, b);
      } else if (preference == DateLocalePreference.dayFirst) {
        preferred = _validDate(year, b, a);
        alternate = _validDate(year, a, b);
      } else {
        preferred = _validDate(year, a, b);
        alternate = _validDate(year, b, a);
      }
      if (preferred != null) {
        return _result(raw: raw, date: preferred, alternateDates: [
          if (alternate != null && alternate != preferred) alternate,
        ]);
      }
    }

    m = RegExp(r'^([a-z]+)\s+(\d{1,2})(?:st|nd|rd|th)?(?:,?\s+(\d{4}))?$').firstMatch(s);
    if (m != null) {
      final month = _months[m.group(1)!];
      final day = int.tryParse(m.group(2)!);
      if (month != null && day != null) {
        final year = int.tryParse(m.group(3) ?? '') ?? _bestYear(ref, month, day);
        final date = _validDate(year, month, day);
        if (date != null) return _result(raw: raw, date: date);
      }
    }
    m = RegExp(r'^(\d{1,2})(?:st|nd|rd|th)?\s+([a-z]+)(?:,?\s+(\d{4}))?$').firstMatch(s);
    if (m != null) {
      final day = int.tryParse(m.group(1)!);
      final month = _months[m.group(2)!];
      if (month != null && day != null) {
        final year = int.tryParse(m.group(3) ?? '') ?? _bestYear(ref, month, day);
        final date = _validDate(year, month, day);
        if (date != null) return _result(raw: raw, date: date);
      }
    }
    final month = _months[s];
    if (month != null) return _result(raw: raw, date: DateTime(month < ref.month ? ref.year + 1 : ref.year, month, 1), datePrecision: TemporalPrecision.month);
    return null;
  }

  // ── Recurrence and constraints ────────────────────────────────────────────

  ParsedDate? _parseRecurring(String text, DateTime ref, String raw, DateLocalePreference preference) {
    final compact = text.replaceAll(',', ' and ');
    if (compact == 'daily' || compact == 'every day' || compact == 'everyday') {
      return _result(raw: raw, date: _dateOnly(ref), recurring: true, recurrenceType: RecurrenceType.daily, recurrence: 'FREQ=DAILY');
    }
    if (compact == 'weekly' || compact == 'every week') {
      return _result(raw: raw, date: _dateOnly(ref), recurring: true, recurrenceType: RecurrenceType.weekly, recurrence: 'FREQ=WEEKLY');
    }
    if (compact == 'monthly' || compact == 'every month') {
      return _result(raw: raw, date: _dateOnly(ref), recurring: true, recurrenceType: RecurrenceType.monthly, recurrence: 'FREQ=MONTHLY');
    }
    if (compact == 'yearly' || compact == 'annually' || compact == 'every year') {
      return _result(raw: raw, date: _dateOnly(ref), recurring: true, recurrenceType: RecurrenceType.yearly, recurrence: 'FREQ=YEARLY');
    }
    final every = RegExp(r'^every\s+(?:(\d+|[a-z]+)\s+)?(.+?)(?:\s+at\s+(.+))?$').firstMatch(text);
    if (every != null) {
      final interval = _number(every.group(1) ?? '1') ?? 1;
      final subject = every.group(2)!.trim();
      final days = subject.split(RegExp(r'\s+and\s+')).map((d) => _weekdays[d.trim()]).whereType<int>().toList();
      if (days.isNotEmpty) {
        final time = every.group(3) == null ? null : _parseTime(every.group(3)!);
        final date = _nextWeekday(ref, days.first);
        return _result(raw: raw, date: date, canonicalTime: time?.canonical, recurring: true, recurrenceType: RecurrenceType.weekly, recurrenceWeekday: days.first, recurrenceWeekdays: days, recurrenceInterval: interval, recurrence: 'FREQ=WEEKLY;INTERVAL=$interval;BYDAY=${days.map(_weekdayCode).join(',')}', timePrecision: time == null ? null : TimePrecision.minute);
      }
      if (subject == 'weekday' || subject == 'weekdays') {
        const days = [DateTime.monday, DateTime.tuesday, DateTime.wednesday, DateTime.thursday, DateTime.friday];
        return _result(
          raw: raw,
          date: _nextWeekday(ref, days.first),
          recurring: true,
          recurrenceType: RecurrenceType.weekly,
          recurrenceWeekdays: days,
          recurrenceInterval: interval,
          recurrence: 'FREQ=WEEKLY;INTERVAL=$interval;BYDAY=MO,TU,WE,TH,FR',
        );
      }
      final everyOther = RegExp(r'^(other|second)\s+(.+)$').firstMatch(subject);
      if (everyOther != null) {
        final day = _weekdays[everyOther.group(2)!];
        if (day != null) {
          return _result(
            raw: raw,
            date: _nextWeekday(ref, day),
            recurring: true,
            recurrenceType: RecurrenceType.weekly,
            recurrenceWeekday: day,
            recurrenceWeekdays: [day],
            recurrenceInterval: 2,
            recurrence: 'FREQ=WEEKLY;INTERVAL=2;BYDAY=${_weekdayCode(day)}',
          );
        }
      }
      final unitSubject = subject.replaceAll('every ', '').trim();
      if (unitSubject == 'day' || unitSubject == 'days' ||
          unitSubject == 'week' || unitSubject == 'weeks') {
        final unit = unitSubject.startsWith('day') ? 'DAILY' : 'WEEKLY';
        return _result(raw: raw, date: _dateOnly(ref), recurring: true, recurrenceType: unit == 'DAILY' ? RecurrenceType.daily : RecurrenceType.weekly, recurrenceInterval: interval, recurrence: 'FREQ=$unit;INTERVAL=$interval');
      }
    }
    final ordinal = RegExp(r'^the\s+(first|second|third|fourth|last)\s+(\w+)\s+of\s+every\s+month$').firstMatch(text);
    if (ordinal != null) {
      final day = _weekdays[ordinal.group(2)!];
      if (day != null) {
        final position = switch (ordinal.group(1)) {
          'first' => 1,
          'second' => 2,
          'third' => 3,
          'fourth' => 4,
          _ => -1,
        };
        return _result(
          raw: raw,
          date: _nextWeekday(ref, day),
          recurring: true,
          recurrenceType: RecurrenceType.monthly,
          recurrenceOrdinal: ordinal.group(1),
          recurrenceWeekday: day,
          recurrence: 'FREQ=MONTHLY;BYDAY=${_weekdayCode(day)};BYSETPOS=$position',
        );
      }
    }
    return null;
  }

  ParsedDate? _parseDeadline(String text, DateTime ref, String raw, DateLocalePreference preference) {
    final match = RegExp(r'^(?:due|deadline|by|before|no later than)\s*:?\s+(.+)$').firstMatch(text);
    if (match == null) return null;
    final value = parse(match.group(1)!, now: ref, localePreference: preference);
    final deadline = value.startDateTime ?? value.absoluteDate;
    return deadline == null ? null : ParsedDate(
      absoluteDate: value.absoluteDate,
      startDateTime: value.startDateTime,
      deadlineDateTime: deadline,
      canonicalTime: value.canonicalTime,
      datePrecision: value.datePrecision,
      timePrecision: value.timePrecision,
      alternateDates: value.alternateDates,
      rawInput: raw,
    );
  }

  String? _qualifier(String text) {
    if (text.contains('morning')) return 'morning';
    if (text.contains('afternoon')) return 'afternoon';
    if (text.contains('evening')) return 'evening';
    if (text.contains('night') || text == 'tonight') return 'night';
    return null;
  }

  int? _number(String value) {
    final direct = int.tryParse(value);
    if (direct != null) return direct;
    return _numbers[value.trim()];
  }

  static String _weekdayCode(int day) => const ['MO', 'TU', 'WE', 'TH', 'FR', 'SA', 'SU'][day - 1];
  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
  static DateTime? _validDate(int year, int month, int day) {
    final value = DateTime(year, month, day);
    return value.year == year && value.month == month && value.day == day ? value : null;
  }
  static DateTime _nextWeekday(DateTime ref, int weekday, {bool skipToday = false}) {
    var date = _dateOnly(ref);
    if (!skipToday && date.weekday == weekday) return date;
    do { date = date.add(const Duration(days: 1)); } while (date.weekday != weekday);
    return date;
  }
  static DateTime _prevWeekday(DateTime ref, int weekday) {
    var date = _dateOnly(ref).subtract(const Duration(days: 1));
    while (date.weekday != weekday) {
      date = date.subtract(const Duration(days: 1));
    }
    return date;
  }
  static int _bestYear(DateTime ref, int month, int day) {
    final candidate = DateTime(ref.year, month, day);
    return candidate.isBefore(_dateOnly(ref)) ? ref.year + 1 : ref.year;
  }
}

class _ParsedTime {
  final int hour;
  final int minute;
  final TimePrecision precision;
  const _ParsedTime(
    this.hour,
    this.minute, {
    this.precision = TimePrecision.minute,
  });
  String get canonical => '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  _ParsedTime withMinute(int value) => _ParsedTime(hour, value, precision: precision);
}

class _TimeRange {
  final _ParsedTime start;
  final _ParsedTime end;
  const _TimeRange(this.start, this.end);
}
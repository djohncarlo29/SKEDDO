// ParsedDate — the canonical temporal representation used by the local parser,
// event persistence, and smart search.

enum RecurrenceType { daily, weekly, monthly, yearly }

/// How an ambiguous numeric date should be ranked.
enum DateLocalePreference { monthFirst, dayFirst }

enum TemporalPrecision { year, month, week, day, minute, approximate }

/// Precision values that describe a clock time, kept separate from calendar
/// precision so a time can never be tagged as a year/month/week/day.
enum TimePrecision { minute, approximate }

class ParsedDate {
  /// Legacy date-only view retained for calendar and matcher consumers.
  final DateTime? absoluteDate;

  /// Canonical start/end values.  Date-only values are normalised to midnight.
  final DateTime? startDateTime;
  final DateTime? endDateTime;

  /// A deadline is kept separately from an event's start/end range.
  final DateTime? deadlineDateTime;

  /// Canonical time without a date, formatted as HH:mm.
  final String? canonicalTime;
  final String? canonicalEndTime;

  /// Precision prevents approximate phrases such as "later this week" from
  /// being mistaken for exact minute-level appointments.
  final TemporalPrecision? datePrecision;
  final TimePrecision? timePrecision;

  /// IANA timezone when supplied by the caller or a future locale layer.
  final String? timezone;

  /// All valid interpretations of an ambiguous numeric date.  The preferred
  /// interpretation remains [absoluteDate] and is ranked first.
  final List<DateTime> alternateDates;

  /// Canonical recurrence details.  [recurrence] is intentionally a simple,
  /// serialisable rule string (for example FREQ=WEEKLY;BYDAY=MO,WE).
  final String? recurrence;
  final int? recurrenceInterval;
  final List<int> recurrenceWeekdays;
  final String? recurrenceOrdinal;

  final bool isRecurring;
  final RecurrenceType? recurrenceType;
  final int? recurrenceWeekday;

  /// Original expression, preserved exactly for search/debugging.
  final String rawInput;

  const ParsedDate({
    this.absoluteDate,
    DateTime? startDateTime,
    this.endDateTime,
    this.deadlineDateTime,
    this.canonicalTime,
    this.canonicalEndTime,
    this.datePrecision,
    this.timePrecision,
    this.timezone,
    this.alternateDates = const [],
    this.recurrence,
    this.recurrenceInterval,
    this.recurrenceWeekdays = const [],
    this.recurrenceOrdinal,
    this.isRecurring = false,
    this.recurrenceType,
    this.recurrenceWeekday,
    this.rawInput = '',
  }) : startDateTime = startDateTime ?? absoluteDate;

  String? get originalDateText => rawInput.isEmpty ? null : rawInput;

  /// Canonical YYYY-MM-DD date, useful for exact local comparisons.
  String? get canonicalDate {
    final d = startDateTime ?? absoluteDate;
    if (d == null) return null;
    return '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
  }

  /// True when this event has any resolved calendar date.
  bool get isScheduled => (startDateTime ?? absoluteDate) != null;

  ParsedDate copyWith({
    DateTime? absoluteDate,
    DateTime? startDateTime,
    DateTime? endDateTime,
    DateTime? deadlineDateTime,
    String? canonicalTime,
    String? canonicalEndTime,
    TemporalPrecision? datePrecision,
    TimePrecision? timePrecision,
    String? timezone,
    List<DateTime>? alternateDates,
    String? recurrence,
    int? recurrenceInterval,
    List<int>? recurrenceWeekdays,
    String? recurrenceOrdinal,
  }) => ParsedDate(
    absoluteDate: absoluteDate ?? this.absoluteDate,
    startDateTime: startDateTime ?? this.startDateTime,
    endDateTime: endDateTime ?? this.endDateTime,
    deadlineDateTime: deadlineDateTime ?? this.deadlineDateTime,
    canonicalTime: canonicalTime ?? this.canonicalTime,
    canonicalEndTime: canonicalEndTime ?? this.canonicalEndTime,
    datePrecision: datePrecision ?? this.datePrecision,
    timePrecision: timePrecision ?? this.timePrecision,
    timezone: timezone ?? this.timezone,
    alternateDates: alternateDates ?? this.alternateDates,
    recurrence: recurrence ?? this.recurrence,
    recurrenceInterval: recurrenceInterval ?? this.recurrenceInterval,
    recurrenceWeekdays: recurrenceWeekdays ?? this.recurrenceWeekdays,
    recurrenceOrdinal: recurrenceOrdinal ?? this.recurrenceOrdinal,
    isRecurring: isRecurring,
    recurrenceType: recurrenceType,
    recurrenceWeekday: recurrenceWeekday,
    rawInput: rawInput,
  );

  // ── Range predicates ─────────────────────────────────────────────────────

  bool isToday(DateTime now) {
    final d = absoluteDate;
    if (d == null) return false;
    return d.year == now.year && d.month == now.month && d.day == now.day;
  }

  bool isTomorrow(DateTime now) {
    final d = absoluteDate;
    if (d == null) return false;
    final t = now.add(const Duration(days: 1));
    return d.year == t.year && d.month == t.month && d.day == t.day;
  }

  bool isThisWeek(DateTime now) {
    final d = absoluteDate;
    if (d == null) return false;
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final weekStart = DateTime(monday.year, monday.month, monday.day);
    final weekEnd = weekStart.add(const Duration(days: 7));
    final dt = DateTime(d.year, d.month, d.day);
    return !dt.isBefore(weekStart) && dt.isBefore(weekEnd);
  }

  bool isNextWeek(DateTime now) {
    final d = absoluteDate;
    if (d == null) return false;
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final nextMonday = monday.add(const Duration(days: 7));
    final weekStart = DateTime(nextMonday.year, nextMonday.month, nextMonday.day);
    final weekEnd = weekStart.add(const Duration(days: 7));
    final dt = DateTime(d.year, d.month, d.day);
    return !dt.isBefore(weekStart) && dt.isBefore(weekEnd);
  }

  bool isThisMonth(DateTime now) {
    final d = absoluteDate;
    return d != null && d.year == now.year && d.month == now.month;
  }

  bool isNextMonth(DateTime now) {
    final d = absoluteDate;
    if (d == null) return false;
    final nm = now.month == 12
        ? DateTime(now.year + 1, 1)
        : DateTime(now.year, now.month + 1);
    return d.year == nm.year && d.month == nm.month;
  }

  bool isPastWeek(DateTime now) {
    final d = absoluteDate;
    if (d == null) return false;
    final start = now.subtract(const Duration(days: 7));
    final dt = DateTime(d.year, d.month, d.day);
    final startDay = DateTime(start.year, start.month, start.day);
    final nowDay = DateTime(now.year, now.month, now.day);
    return !dt.isBefore(startDay) && !dt.isAfter(nowDay);
  }

  // ── Serialization ─────────────────────────────────────────────────────────

  Map<String, dynamic> toJson() => {
    if (absoluteDate != null) 'absoluteDate': absoluteDate!.toIso8601String(),
    if (startDateTime != null) 'startDateTime': startDateTime!.toIso8601String(),
    if (endDateTime != null) 'endDateTime': endDateTime!.toIso8601String(),
    if (deadlineDateTime != null)
      'deadlineDateTime': deadlineDateTime!.toIso8601String(),
    if (canonicalTime != null) 'canonicalTime': canonicalTime,
    if (canonicalEndTime != null) 'canonicalEndTime': canonicalEndTime,
    if (datePrecision != null) 'datePrecision': datePrecision!.name,
    if (timePrecision != null) 'timePrecision': timePrecision!.name,
    if (timezone != null) 'timezone': timezone,
    if (alternateDates.isNotEmpty)
      'alternateDates': alternateDates.map((d) => d.toIso8601String()).toList(),
    if (recurrence != null) 'recurrence': recurrence,
    if (recurrenceInterval != null) 'recurrenceInterval': recurrenceInterval,
    if (recurrenceWeekdays.isNotEmpty) 'recurrenceWeekdays': recurrenceWeekdays,
    if (recurrenceOrdinal != null) 'recurrenceOrdinal': recurrenceOrdinal,
    'isRecurring': isRecurring,
    if (recurrenceType != null) 'recurrenceType': recurrenceType!.name,
    if (recurrenceWeekday != null) 'recurrenceWeekday': recurrenceWeekday,
    'rawInput': rawInput,
  };

  factory ParsedDate.fromJson(Map<String, dynamic> j) {
    TemporalPrecision? datePrecision(String? value) {
      if (value == null) return null;
      for (final item in TemporalPrecision.values) {
        if (item.name == value) return item;
      }
      return null;
    }
    TimePrecision? timePrecision(String? value) {
      if (value == null) return null;
      for (final item in TimePrecision.values) {
        if (item.name == value) return item;
      }
      return null;
    }
    final adStr = j['absoluteDate'] as String?;
    final rtStr = j['recurrenceType'] as String?;
    final dates = (j['alternateDates'] as List?)
        ?.whereType<String>()
        .map(DateTime.tryParse)
        .whereType<DateTime>()
        .toList() ?? const <DateTime>[];
    return ParsedDate(
      absoluteDate: adStr != null ? DateTime.tryParse(adStr) : null,
      startDateTime: DateTime.tryParse(j['startDateTime'] as String? ?? ''),
      endDateTime: DateTime.tryParse(j['endDateTime'] as String? ?? ''),
      deadlineDateTime: DateTime.tryParse(j['deadlineDateTime'] as String? ?? ''),
      canonicalTime: j['canonicalTime'] as String?,
      canonicalEndTime: j['canonicalEndTime'] as String?,
      datePrecision: datePrecision(j['datePrecision'] as String?),
      timePrecision: timePrecision(j['timePrecision'] as String?),
      timezone: j['timezone'] as String?,
      alternateDates: dates,
      recurrence: j['recurrence'] as String?,
      recurrenceInterval: j['recurrenceInterval'] as int?,
      recurrenceWeekdays: (j['recurrenceWeekdays'] as List?)
          ?.whereType<int>().toList() ?? const [],
      recurrenceOrdinal: j['recurrenceOrdinal'] as String?,
      isRecurring: (j['isRecurring'] as bool?) ?? false,
      recurrenceType: rtStr != null
          ? RecurrenceType.values.firstWhere(
              (e) => e.name == rtStr,
              orElse: () => RecurrenceType.weekly,
            )
          : null,
      recurrenceWeekday: j['recurrenceWeekday'] as int?,
      rawInput: (j['rawInput'] as String?) ?? '',
    );
  }

  @override
  String toString() =>
      'ParsedDate(date: $absoluteDate, start: $startDateTime, '
      'end: $endDateTime, recurring: $isRecurring '
      '${recurrenceType?.name ?? ""}, raw: "$rawInput")';
}
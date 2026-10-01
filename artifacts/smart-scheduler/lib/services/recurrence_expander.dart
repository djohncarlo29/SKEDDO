import 'dart:math' as math;
import 'event_model.dart';
import '../ai/parsed_date.dart';

// ─────────────────────────────────────────────────────────────────────────────
// RecurrenceExpander — converts a recurring ScheduledEvent into a flat list
// of concrete dated occurrences within a given date window.
//
// Expanded occurrence IDs use the convention "${baseId}_r${YYYYMMDD}" so
// callers (e.g. HybridMatcher) can recover the base ID via splitting on "_r".
// The occurrence that lands on the base event's own date is returned as the
// original object (unchanged ID), so its embedding entry in HybridMatcher
// remains valid without any extra registration.
//
// Supported repeat rules:
//   • "Every Day"   — daily, interval 1
//   • "Every Week"  — weekly on the same weekday as the base event
//   • "Every Month" — monthly on the same day-of-month as the base event
//   • "Every Year"  — yearly on the same month+day as the base event
//   • Custom        — uses customRepeatConfig with frequency / everyCount /
//                     selectedDays / monthlyMode / selectedDates /
//                     onThePositionIndex / onTheDayIndex / selectedMonths /
//                     yearlyDaysEnabled / yearlyPositionIndex / yearlyDayIndex
//
// End conditions:
//   repeatEndType == "On Date"  → stop at repeatEndDate (inclusive)
//   repeatEndType == "Never"    → stop at [to] window boundary
//
// Safety cap: max 500 occurrences per expansion call.
// ─────────────────────────────────────────────────────────────────────────────
class RecurrenceExpander {
  RecurrenceExpander._();

  static const int _kMaxOccurrences = 500;

  static const List<String> _kMonthsFull = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  // Full weekday names, Monday-first — matching _kDays in the custom repeat UI.
  // Index 0 = Monday … Index 6 = Sunday.
  // DateTime.weekday: Monday = 1 … Sunday = 7.
  static const List<String> _kWeekdays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  // "On the" positions: index → label in the custom-repeat UI.
  // The versioned config index keeps older saved "last" selections intact.
  static const List<String> _kPositions = [
    'first',
    'second',
    'third',
    'fourth',
    'fifth',
    'next to last',
    'last',
  ];

  // Individual weekdays followed by the supported calendar-day groups.
  static const List<String> _kPositionDays = [
    ..._kWeekdays,
    'Day',
    'Weekday',
    'Weekend day',
  ];

  // ── Public API ──────────────────────────────────────────────────────────────

  /// Expand [base] into concrete occurrences within [[from], [to]].
  ///
  /// Returns [] if [base] is not recurring or has no absolute date.
  /// Non-recurring callers should check [event.repeat] before calling.
  static List<ScheduledEvent> expand(
    ScheduledEvent base,
    DateTime from,
    DateTime to,
  ) {
    final pd = base.parsedDate;
    if (pd?.absoluteDate == null) return [];
    final baseDate = DateTime(
      pd!.absoluteDate!.year,
      pd.absoluteDate!.month,
      pd.absoluteDate!.day,
    );
    final repeat = base.repeat;
    if (repeat == null || repeat == 'Never') return [];

    // Resolve the effective end date.
    DateTime effectiveTo = to;
    if (base.repeatEndType == 'On Date' && base.repeatEndDate != null) {
      final endParsed = _parseHumanDate(base.repeatEndDate!);
      if (endParsed != null && endParsed.isBefore(effectiveTo)) {
        effectiveTo = endParsed;
      }
    }

    final results = <ScheduledEvent>[];

    switch (repeat) {
      case 'Every Day':
        _daily(base, baseDate, from, effectiveTo, 1, results);
      case 'Every Week':
        _daily(base, baseDate, from, effectiveTo, 7, results);
      case 'Every Month':
        _monthlyEach(base, baseDate, from, effectiveTo, 1, {
          baseDate.day,
        }, results);
      case 'Every Year':
        _yearly(
          base,
          baseDate,
          from,
          effectiveTo,
          1,
          {baseDate.month},
          false,
          0,
          0,
          results,
        );
      default:
        _expandCustom(base, baseDate, from, effectiveTo, results);
    }

    return results;
  }

  // ── Custom rule dispatcher ──────────────────────────────────────────────────

  static void _expandCustom(
    ScheduledEvent base,
    DateTime baseDate,
    DateTime from,
    DateTime to,
    List<ScheduledEvent> out,
  ) {
    final cfg = base.customRepeatConfig;
    if (cfg == null) return;

    final frequency = (cfg['frequency'] as String?) ?? 'Daily';
    final everyCount = (cfg['everyCount'] as int?) ?? 1;
    final selectedDays = Set<String>.from(
      (cfg['selectedDays'] as List?)?.cast<String>() ?? [],
    );
    final monthlyMode = (cfg['monthlyMode'] as String?) ?? 'Each';
    final selectedDates = Set<int>.from(
      (cfg['selectedDates'] as List?)?.cast<int>() ?? [],
    );
    final onThePositionIndex = _positionIndexFromConfig(
      cfg,
      'onThePositionIndex',
    );
    final onTheDayIndex = (cfg['onTheDayIndex'] as int?) ?? 0;
    final selectedMonths = Set<int>.from(
      (cfg['selectedMonths'] as List?)?.cast<int>() ?? [],
    );
    final yearlyDaysEnabled = (cfg['yearlyDaysEnabled'] as bool?) ?? false;
    final yearlyPositionIndex = _positionIndexFromConfig(
      cfg,
      'yearlyPositionIndex',
    );
    final yearlyDayIndex = (cfg['yearlyDayIndex'] as int?) ?? 0;

    switch (frequency) {
      case 'Daily':
        _daily(base, baseDate, from, to, everyCount, out);
      case 'Weekly':
        _customWeekly(base, baseDate, from, to, everyCount, selectedDays, out);
      case 'Monthly':
        if (monthlyMode == 'OnThe') {
          _monthlyOnThe(
            base,
            baseDate,
            from,
            to,
            everyCount,
            onThePositionIndex,
            onTheDayIndex,
            out,
          );
        } else {
          _monthlyEach(
            base,
            baseDate,
            from,
            to,
            everyCount,
            selectedDates,
            out,
          );
        }
      case 'Yearly':
        _yearly(
          base,
          baseDate,
          from,
          to,
          everyCount,
          selectedMonths,
          yearlyDaysEnabled,
          yearlyPositionIndex,
          yearlyDayIndex,
          out,
        );
    }
  }

  static int _positionIndexFromConfig(Map<String, dynamic> config, String key) {
    final rawIndex = (config[key] as int?) ?? 0;
    final version = (config['positionOptionsVersion'] as int?) ?? 1;
    // Before "next to last" was inserted, index 5 meant "last".
    final index = version < 2 && rawIndex >= 5 ? rawIndex + 1 : rawIndex;
    if (index < 0) return 0;
    if (index >= _kPositions.length) return _kPositions.length - 1;
    return index;
  }

  // ── Expansion primitives ────────────────────────────────────────────────────

  /// Simple daily expansion — covers "Every Day" and "Every Week" (interval 7).
  static void _daily(
    ScheduledEvent base,
    DateTime baseDate,
    DateTime from,
    DateTime to,
    int interval,
    List<ScheduledEvent> out,
  ) {
    var cursor = baseDate;

    // Fast-forward: skip to the cycle that contains or follows [from].
    if (cursor.isBefore(from)) {
      final diff = from.difference(cursor).inDays;
      final steps = diff ~/ interval;
      cursor = cursor.add(Duration(days: steps * interval));
    }

    while (!cursor.isAfter(to) && out.length < _kMaxOccurrences) {
      if (!cursor.isBefore(from)) {
        out.add(_makeOccurrence(base, cursor));
      }
      cursor = cursor.add(Duration(days: interval));
    }
  }

  /// Custom weekly — every [weekCount] weeks on [selectedDays].
  static void _customWeekly(
    ScheduledEvent base,
    DateTime baseDate,
    DateTime from,
    DateTime to,
    int weekCount,
    Set<String> selectedDays,
    List<ScheduledEvent> out,
  ) {
    // With no selected days fall back to the base event's weekday.
    if (selectedDays.isEmpty) {
      _daily(base, baseDate, from, to, weekCount * 7, out);
      return;
    }

    // Monday of the base event's week.
    final baseMon = baseDate.subtract(Duration(days: baseDate.weekday - 1));
    var weekStart = baseMon;

    // Fast-forward to the cycle week that contains or follows [from].
    if (weekStart.isBefore(from)) {
      final weeksDiff = from.difference(weekStart).inDays ~/ 7;
      final cycles = weeksDiff ~/ weekCount;
      weekStart = weekStart.add(Duration(days: cycles * weekCount * 7));
    }

    final stride = Duration(days: weekCount * 7);

    while (out.length < _kMaxOccurrences) {
      // Sorted for deterministic output (Mon → Tue → … → Sun).
      final sortedDays = selectedDays.toList()
        ..sort((a, b) => _kWeekdays.indexOf(a) - _kWeekdays.indexOf(b));

      for (final dayName in sortedDays) {
        final dayIdx = _kWeekdays.indexOf(dayName); // 0=Monday
        if (dayIdx < 0) continue;
        final date = weekStart.add(Duration(days: dayIdx));
        if (date.isAfter(to)) return;
        if (!date.isBefore(from)) {
          out.add(_makeOccurrence(base, date));
          if (out.length >= _kMaxOccurrences) return;
        }
      }
      weekStart = weekStart.add(stride);
    }
  }

  /// Monthly "Each" — every [monthCount] months on [dayNumbers] (1-31).
  static void _monthlyEach(
    ScheduledEvent base,
    DateTime baseDate,
    DateTime from,
    DateTime to,
    int monthCount,
    Set<int> dayNumbers,
    List<ScheduledEvent> out,
  ) {
    final effectiveDays = dayNumbers.isEmpty ? {baseDate.day} : dayNumbers;
    var year = baseDate.year;
    var month = baseDate.month;

    // Fast-forward to the cycle month that is at or before [from].
    final monthsFromBase = (from.year - year) * 12 + (from.month - month);
    if (monthsFromBase > 0) {
      final cycles = monthsFromBase ~/ monthCount;
      final advance = cycles * monthCount;
      month += advance;
      year += (month - 1) ~/ 12;
      month = ((month - 1) % 12) + 1;
    }

    while (out.length < _kMaxOccurrences) {
      final sortedDays = effectiveDays.toList()..sort();
      for (final day in sortedDays) {
        final daysInMonth = DateTime(year, month + 1, 0).day;
        if (day > daysInMonth) continue; // e.g., Feb 30 → skip
        final date = DateTime(year, month, day);
        if (date.isAfter(to)) return;
        if (!date.isBefore(from)) {
          out.add(_makeOccurrence(base, date));
          if (out.length >= _kMaxOccurrences) return;
        }
      }
      // Advance by monthCount months.
      month += monthCount;
      year += (month - 1) ~/ 12;
      month = ((month - 1) % 12) + 1;
    }
  }

  /// Monthly "On the" — every [monthCount] months on the [positionIndex]-th
  /// occurrence of selector [dayIndex] in the month.
  static void _monthlyOnThe(
    ScheduledEvent base,
    DateTime baseDate,
    DateTime from,
    DateTime to,
    int monthCount,
    int positionIndex,
    int weekdayIndex,
    List<ScheduledEvent> out,
  ) {
    var year = baseDate.year;
    var month = baseDate.month;

    // Fast-forward similarly to _monthlyEach.
    final monthsFromBase = (from.year - year) * 12 + (from.month - month);
    if (monthsFromBase > 0) {
      final cycles = monthsFromBase ~/ monthCount;
      final advance = cycles * monthCount;
      month += advance;
      year += (month - 1) ~/ 12;
      month = ((month - 1) % 12) + 1;
    }

    while (out.length < _kMaxOccurrences) {
      final date = _nthWeekdayOfMonth(year, month, positionIndex, weekdayIndex);
      if (date != null) {
        if (date.isAfter(to)) return;
        if (!date.isBefore(from)) {
          out.add(_makeOccurrence(base, date));
          if (out.length >= _kMaxOccurrences) return;
        }
      }
      month += monthCount;
      year += (month - 1) ~/ 12;
      month = ((month - 1) % 12) + 1;
    }
  }

  /// Yearly — every [yearCount] years in [selectedMonths] (1-12).
  /// If [daysEnabled], uses the [posIdx]-th [dayIdx]-weekday of each month;
  /// otherwise uses the base event's day-of-month.
  static void _yearly(
    ScheduledEvent base,
    DateTime baseDate,
    DateTime from,
    DateTime to,
    int yearCount,
    Set<int> selectedMonths,
    bool daysEnabled,
    int posIdx,
    int dayIdx,
    List<ScheduledEvent> out,
  ) {
    final effectiveMonths = selectedMonths.isEmpty
        ? {baseDate.month}
        : selectedMonths;
    var year = baseDate.year;

    // Fast-forward.
    if (year < from.year) {
      final diff = from.year - year;
      final cycles = diff ~/ yearCount;
      year += cycles * yearCount;
    }

    while (out.length < _kMaxOccurrences) {
      final sortedMonths = effectiveMonths.toList()..sort();
      for (final mon in sortedMonths) {
        final DateTime? date;
        if (daysEnabled) {
          date = _nthWeekdayOfMonth(year, mon, posIdx, dayIdx);
        } else {
          final daysInMonth = DateTime(year, mon + 1, 0).day;
          final day = math.min(baseDate.day, daysInMonth);
          date = DateTime(year, mon, day);
        }
        if (date == null) continue;
        if (date.isAfter(to)) return;
        if (!date.isBefore(from)) {
          out.add(_makeOccurrence(base, date));
          if (out.length >= _kMaxOccurrences) return;
        }
      }
      year += yearCount;
    }
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  /// Returns the requested ordinal position of a weekday or date group in the
  /// given month/year. A missing fifth occurrence returns null.
  static DateTime? _nthWeekdayOfMonth(
    int year,
    int month,
    int positionIndex,
    int dayIndex,
  ) {
    final dates = <DateTime>[];
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final selector = dayIndex >= 0 && dayIndex < _kPositionDays.length
        ? _kPositionDays[dayIndex]
        : null;
    for (var day = 1; day <= daysInMonth; day++) {
      final date = DateTime(year, month, day);
      final matches = switch (selector) {
        'Day' => true,
        'Weekday' =>
          date.weekday >= DateTime.monday && date.weekday <= DateTime.friday,
        'Weekend day' =>
          date.weekday == DateTime.saturday || date.weekday == DateTime.sunday,
        _ => _kWeekdays.indexOf(selector ?? '') == date.weekday - 1,
      };
      if (matches) dates.add(date);
    }

    final matchIndex = switch (positionIndex) {
      5 => dates.length - 2, // second-to-last matching date
      6 => dates.length - 1, // final matching date
      _ => positionIndex,
    };
    if (matchIndex < 0 || matchIndex >= dates.length) return null;
    return dates[matchIndex];
  }

  /// Build an expanded occurrence for [date].
  ///
  /// If [date] is exactly the base event's own absolute date, the original
  /// object is returned unchanged (preserves embedding map key in HybridMatcher).
  static ScheduledEvent _makeOccurrence(ScheduledEvent base, DateTime date) {
    final baseAbs = base.parsedDate!.absoluteDate!;
    if (date.year == baseAbs.year &&
        date.month == baseAbs.month &&
        date.day == baseAbs.day) {
      return base;
    }

    final dateStr = _formatDate(date);
    // ID encodes the date so it is unique and stable across expansion windows.
    final occId =
        '${base.id}_r${date.year}'
        '${date.month.toString().padLeft(2, '0')}'
        '${date.day.toString().padLeft(2, '0')}';

    return ScheduledEvent(
      id: occId,
      title: base.title,
      subtitle: base.subtitle,
      date: dateStr,
      time: base.time,
      endDate: null, // single-day occurrence; multi-day span not expanded
      endTime: base.endTime,
      isAllDay: base.isAllDay,
      location: base.location,
      destination: base.destination,
      travelTime: base.travelTime,
      travelMode: base.travelMode,
      repeat: base.repeat,
      repeatEndType: base.repeatEndType,
      repeatEndDate: base.repeatEndDate,
      customRepeatConfig: base.customRepeatConfig,
      alert: base.alert,
      secondAlert: base.secondAlert,
      alerts: base.alerts,
      url: base.url,
      notes: base.notes,
      attachmentPaths: base.attachmentPaths,
      parsedDate: ParsedDate(absoluteDate: date, rawInput: dateStr),
      categoryId: base.categoryId,
      reminderOption: base.reminderOption,
      reminderDateTime: base.reminderDateTime,
      reminderRepeat: base.reminderRepeat,
      reminderCustomRepeatConfig: base.reminderCustomRepeatConfig,
    );
  }

  /// Parse "Month D, YYYY" → DateTime.  Returns null on failure.
  static DateTime? _parseHumanDate(String s) {
    final parts = s.trim().split(RegExp(r'[\s,]+'));
    if (parts.length < 3) return null;
    final month = _kMonthsFull.indexOf(parts[0]) + 1;
    if (month == 0) return null;
    final day = int.tryParse(parts[1]);
    final year = int.tryParse(parts[2]);
    if (day == null || year == null) return null;
    return DateTime(year, month, day);
  }

  /// Format DateTime → "Month D, YYYY" (matches the app's _fmtDateSave format).
  static String _formatDate(DateTime d) =>
      '${_kMonthsFull[d.month - 1]} ${d.day}, ${d.year}';
}

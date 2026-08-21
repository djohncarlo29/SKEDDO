import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

abstract final class ParsedRuleSource {
  static const String offline = 'offline';

  // Kept as a migration value for old persisted data. It is never produced
  // by the current parser and is normalized to offline when loaded.
  static const String regex = offline;
}

class ParsedRule {
  final Set<int> weekdays;
  final String? timeOfDay;
  final Set<int> months;
  final String semanticTopic;
  final String source;

  ParsedRule({
    Set<int>? weekdays,
    this.timeOfDay,
    Set<int>? months,
    this.semanticTopic = '',
    this.source = ParsedRuleSource.offline,
  }) : weekdays = weekdays ?? <int>{},
       months = months ?? <int>{};

  bool get hasConstraints =>
      weekdays.isNotEmpty || timeOfDay != null || months.isNotEmpty;
}

/// Parses Smart Category rules locally and persists the result.
///
/// This parser intentionally has no network implementation. It recognizes
/// weekdays, weekday/weekend groups, time-of-day phrases, months, and a
/// useful semantic topic from the rule text.
class SmartRuleParser {
  SmartRuleParser._();

  static const _kPrefsKey = 'smart_rule_parser_cache_v1';
  static final _cache = <String, ParsedRule>{};
  static bool _persistedLoaded = false;

  static Future<ParsedRule> parse(String rule) async {
    final key = rule.trim();
    if (key.isEmpty) return ParsedRule();
    if (!_persistedLoaded) await _loadPersisted();
    final cached = _cache[key];
    if (cached != null) return cached;

    final result = _offlineParse(key);
    _cache[key] = result;
    _persistAll();
    return result;
  }

  static void evict(String rule) {
    _cache.remove(rule.trim());
    _persistAll();
  }

  static Future<void> _loadPersisted() async {
    _persistedLoaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kPrefsKey);
      if (raw == null) return;
      final map = jsonDecode(raw) as Map<String, dynamic>;
      for (final entry in map.entries) {
        if (_cache.containsKey(entry.key)) continue;
        final value = entry.value;
        if (value is Map<String, dynamic>) {
          _cache[entry.key] = _fromJson(value);
        }
      }
    } catch (_) {
      // Corrupt preferences should not block local rule parsing.
    }
  }

  static Future<void> _persistAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _kPrefsKey,
        jsonEncode({
          for (final entry in _cache.entries) entry.key: _toJson(entry.value),
        }),
      );
    } catch (_) {
      // Persistence is an optimization; parsing remains fully local.
    }
  }

  static Map<String, dynamic> _toJson(ParsedRule rule) => {
    'weekdays': rule.weekdays.toList(),
    if (rule.timeOfDay != null) 'timeOfDay': rule.timeOfDay,
    'months': rule.months.toList(),
    'topic': rule.semanticTopic,
    'source': ParsedRuleSource.offline,
  };

  static ParsedRule _fromJson(Map<String, dynamic> json) => ParsedRule(
    weekdays: _parseWeekdays(json['weekdays']),
    timeOfDay: _validTimeOfDay(json['timeOfDay'] as String?),
    months: _parseMonths(json['months']),
    semanticTopic: (json['topic'] as String?)?.trim() ?? '',
    source: ParsedRuleSource.offline,
  );

  static ParsedRule _offlineParse(String rule) {
    final lower = rule.toLowerCase();
    final weekdays = <int>{};
    for (final entry in _weekdayWords.entries) {
      if (!RegExp(r'\b' + entry.key + r'\b').hasMatch(lower)) continue;
      if (entry.value == -1) {
        weekdays.addAll([1, 2, 3, 4, 5]);
      } else if (entry.value == -2) {
        weekdays.addAll([6, 7]);
      } else {
        weekdays.add(entry.value);
      }
    }

    String? timeOfDay;
    for (final candidate in _timeOfDayWords) {
      if (RegExp(r'\b' + candidate + r'\b').hasMatch(lower)) {
        timeOfDay = candidate;
        break;
      }
    }

    final months = <int>{};
    for (final entry in _monthWords.entries) {
      if (RegExp(r'\b' + entry.key + r'\b').hasMatch(lower)) {
        months.add(entry.value);
      }
    }

    return ParsedRule(
      weekdays: weekdays,
      timeOfDay: timeOfDay,
      months: months,
      semanticTopic: _topic(rule),
      source: ParsedRuleSource.offline,
    );
  }

  static String _topic(String rule) {
    var topic = rule;
    for (final word in [
      ..._weekdayWords.keys,
      ..._monthWords.keys,
      ..._timeOfDayWords,
      'in',
      'on',
      'during',
      'every',
      'each',
    ]) {
      topic = topic.replaceAll(
        RegExp(r'\b' + RegExp.escape(word) + r'\b', caseSensitive: false),
        ' ',
      );
    }
    return topic.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static const _weekdayWords = {
    'monday': 1,
    'mondays': 1,
    'tuesday': 2,
    'tuesdays': 2,
    'wednesday': 3,
    'wednesdays': 3,
    'thursday': 4,
    'thursdays': 4,
    'friday': 5,
    'fridays': 5,
    'saturday': 6,
    'saturdays': 6,
    'sunday': 7,
    'sundays': 7,
    'weekday': -1,
    'weekdays': -1,
    'weekend': -2,
    'weekends': -2,
  };

  static const _monthWords = {
    'january': 1,
    'jan': 1,
    'february': 2,
    'feb': 2,
    'march': 3,
    'mar': 3,
    'april': 4,
    'apr': 4,
    'may': 5,
    'june': 6,
    'jun': 6,
    'july': 7,
    'jul': 7,
    'august': 8,
    'aug': 8,
    'september': 9,
    'sep': 9,
    'sept': 9,
    'october': 10,
    'oct': 10,
    'november': 11,
    'nov': 11,
    'december': 12,
    'dec': 12,
  };

  static const _timeOfDayWords = [
    'morning',
    'afternoon',
    'evening',
    'night',
  ];

  static Set<int> _parseWeekdays(dynamic raw) {
    if (raw is! List) return {};
    final result = <int>{};
    for (final item in raw) {
      final value = '$item'.toLowerCase();
      final day = _weekdayWords[value];
      if (day == -1) {
        result.addAll([1, 2, 3, 4, 5]);
      } else if (day == -2) {
        result.addAll([6, 7]);
      } else if (day != null) {
        result.add(day);
      } else {
        final number = int.tryParse(value);
        if (number != null && number >= 1 && number <= 7) result.add(number);
      }
    }
    return result;
  }

  static Set<int> _parseMonths(dynamic raw) {
    if (raw is! List) return {};
    final result = <int>{};
    for (final item in raw) {
      final value = '$item'.toLowerCase();
      final month = _monthWords[value] ?? int.tryParse(value);
      if (month != null && month >= 1 && month <= 12) result.add(month);
    }
    return result;
  }

  static String? _validTimeOfDay(String? value) =>
      value != null && _timeOfDayWords.contains(value.toLowerCase())
      ? value.toLowerCase()
      : null;
}
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ParsedRuleSource — origin constants for a ParsedRule.
// ─────────────────────────────────────────────────────────────────────────────

/// Origin constants stored in [ParsedRule.source].
abstract final class ParsedRuleSource {
  /// The rule was parsed by a live Gemini call (proxy or direct REST).
  static const String gemini = 'gemini';

  /// The rule was parsed by the offline regex fallback and may lack month
  /// constraints or a semantic topic.  Persisted entries with this source are
  /// re-queued for a Gemini upgrade on the next startup that has network access.
  static const String regex = 'regex';
}

// ─────────────────────────────────────────────────────────────────────────────
// ParsedRule — structured output from SmartRuleParser.
// ─────────────────────────────────────────────────────────────────────────────

/// Structured components extracted from a Smart Category rule string by
/// [SmartRuleParser].
class ParsedRule {
  /// Allowed [DateTime.weekday] values (1 = Monday … 7 = Sunday).
  /// Empty set means no weekday constraint.
  final Set<int> weekdays;

  /// Required time-of-day bucket, or null if the rule is unconstrained.
  /// One of: 'morning' | 'afternoon' | 'evening' | 'night'.
  final String? timeOfDay;

  /// Allowed month numbers (1 = January … 12 = December).
  /// Empty set means no month constraint.
  final Set<int> months;

  /// The semantic topic after stripping all temporal, weekday, and month
  /// language from the original rule.  An empty string means the rule is
  /// purely temporal (e.g. "Sunday mornings").
  final String semanticTopic;

  /// Origin of this parse result.  Either [ParsedRuleSource.gemini] (from a
  /// successful Gemini call) or [ParsedRuleSource.regex] (offline fallback).
  /// Persisted so the app can upgrade regex entries when the network returns.
  final String source;

  ParsedRule({
    Set<int>? weekdays,
    this.timeOfDay,
    Set<int>? months,
    this.semanticTopic = '',
    this.source = ParsedRuleSource.gemini,
  })  : weekdays = weekdays ?? <int>{},
        months = months ?? <int>{};

  /// True when at least one hard temporal constraint is present.
  bool get hasConstraints =>
      weekdays.isNotEmpty || timeOfDay != null || months.isNotEmpty;
}

// ─────────────────────────────────────────────────────────────────────────────
// SmartRuleParser — Gemini-powered rule parser with persistent cache.
// ─────────────────────────────────────────────────────────────────────────────

/// Parses Smart Category rule strings into structured [ParsedRule] objects.
///
/// Routing:
///   Web                → same-origin proxy  /api/gemini/parse-rule
///   Mobile + proxy     → PROXY_BASE_URL/api/gemini/parse-rule
///   Mobile + key only  → Gemini REST API directly (key from .env)
///   No network/key     → regex fallback (weekday + time-of-day only)
///
/// Results are cached in two layers:
///   1. In-memory map ([_cache]) — cleared when the app process exits.
///   2. SharedPreferences JSON ([_kPrefsKey]) — survives cold starts.
///
/// The persistent cache is loaded lazily on the first [parse] call.
/// A Gemini call is made only when the rule is absent from both layers.
/// [evict] removes the entry from both layers so a stale parse is never
/// served if the user edits and then reverts a Smart Category rule.
class SmartRuleParser {
  SmartRuleParser._();

  // ── SharedPreferences key ─────────────────────────────────────────────────

  static const _kPrefsKey = 'smart_rule_parser_cache_v1';

  // ── In-memory cache ───────────────────────────────────────────────────────

  static final _cache = <String, ParsedRule>{};

  // ── Persistent-cache state ────────────────────────────────────────────────

  /// True once SharedPreferences has been read into [_cache].
  /// Prevents repeated prefs reads on subsequent [parse] calls.
  static bool _persistedLoaded = false;

  /// Rule keys whose persisted entry had [ParsedRuleSource.regex] as source.
  /// These are NOT loaded into [_cache] at startup; they are instead queued
  /// for a background Gemini upgrade attempt by [_backgroundReparse].
  static final _pendingReparse = <String>{};

  // ── Routing helpers ───────────────────────────────────────────────────────

  static String get _proxyBase => dotenv.env['PROXY_BASE_URL'] ?? '';
  static String get _directKey => dotenv.env['GEMINI_API_KEY'] ?? '';
  static bool get _hasProxy => kIsWeb || _proxyBase.isNotEmpty;
  static bool get _hasDirectKey => !kIsWeb && _directKey.isNotEmpty;

  static const _kGeminiUrl =
      'https://generativelanguage.googleapis.com/v1beta/models'
      '/gemini-2.5-flash:generateContent';

  // ── Public API ────────────────────────────────────────────────────────────

  /// Parse [rule] into structured components.  Always returns a [ParsedRule];
  /// falls back to simple regex extraction if Gemini is unavailable.
  ///
  /// Order of resolution:
  ///   1. In-memory cache (populated from SharedPreferences on first call).
  ///   2. SharedPreferences (already merged into in-memory cache on first call).
  ///   3. Gemini via proxy or direct REST call.
  ///   4. Regex fallback (weekday + time-of-day only).
  ///
  /// The result is stored in both layers so future calls — and future cold
  /// starts — skip the network entirely.
  static Future<ParsedRule> parse(String rule) async {
    final key = rule.trim();
    if (key.isEmpty) return ParsedRule();

    // Populate the in-memory cache from SharedPreferences on first call.
    if (!_persistedLoaded) await _loadPersisted();

    if (_cache.containsKey(key)) return _cache[key]!;

    ParsedRule? result;
    if (_hasProxy) {
      result = await _callProxy(key);
    } else if (_hasDirectKey) {
      result = await _callDirect(key);
    }

    result ??= _regexFallback(key);
    _cache[key] = result;
    _persistAll(); // fire-and-forget
    return result;
  }

  /// Evict a cached entry from both the in-memory and persistent caches.
  ///
  /// Call this whenever a Smart Category's rule string is changed so that
  /// the old Gemini result is not served if the user later reverts to it.
  static void evict(String rule) {
    _cache.remove(rule.trim());
    _persistAll(); // fire-and-forget: rewrites prefs without this key
  }

  // ── Persistent cache helpers ──────────────────────────────────────────────

  /// Load all persisted entries from SharedPreferences into [_cache].
  /// Existing in-memory entries are not overwritten (in case [parse] was
  /// called before persistence had a chance to load on a very fast device).
  ///
  /// Entries whose [ParsedRule.source] is [ParsedRuleSource.regex] are NOT
  /// added to the cache.  Instead their keys are collected in [_pendingReparse]
  /// so [parse] will attempt a live Gemini call on the next access, and a
  /// background upgrade pass is launched immediately (fire-and-forget).
  static Future<void> _loadPersisted() async {
    _persistedLoaded = true; // set eagerly to avoid concurrent loads
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kPrefsKey);
      if (raw == null) return;
      final map = jsonDecode(raw) as Map<String, dynamic>;
      for (final entry in map.entries) {
        if (_cache.containsKey(entry.key)) continue; // in-memory entry wins

        final parsed = _fromJson(entry.value as Map<String, dynamic>);
        if (parsed.source == ParsedRuleSource.regex) {
          // Do not serve stale regex results from cache.  Queue for upgrade.
          _pendingReparse.add(entry.key);
        } else {
          _cache[entry.key] = parsed;
        }
      }
    } catch (_) {
      // Corrupt or missing prefs — start fresh; network will re-populate.
    }

    // Launch background upgrade for any regex-sourced entries.
    if (_pendingReparse.isNotEmpty) _backgroundReparse(); // fire-and-forget
  }

  /// Background pass that upgrades regex-sourced persisted entries to Gemini
  /// results.  Iterates [_pendingReparse] sequentially (to avoid hammering the
  /// network), attempts a Gemini call for each rule, and on success replaces
  /// the in-memory and persistent entries.  On failure the regex result is
  /// stored in [_cache] for the current session (so [parse] won't retry the
  /// network again this session), but it is still persisted as
  /// [ParsedRuleSource.regex] so the upgrade is retried on the next launch.
  static Future<void> _backgroundReparse() async {
    if (!_hasProxy && !_hasDirectKey) return; // no network route — skip

    // Snapshot the keys so new additions during iteration are not affected.
    final keys = List<String>.from(_pendingReparse);
    for (final key in keys) {
      // Skip if a concurrent parse() call already populated the entry.
      if (_cache.containsKey(key)) {
        _pendingReparse.remove(key);
        continue;
      }

      ParsedRule? geminiResult;
      if (_hasProxy) {
        geminiResult = await _callProxy(key);
      } else if (_hasDirectKey) {
        geminiResult = await _callDirect(key);
      }

      if (geminiResult != null) {
        // Upgrade succeeded — store as gemini source in both layers.
        _cache[key] = geminiResult;
        _pendingReparse.remove(key);
        _persistAll(); // fire-and-forget
      } else {
        // Upgrade failed — keep regex result in memory for this session only
        // so parse() has a usable result without a network call.  Do NOT call
        // _persistAll() here: the next scheduled persist (triggered by any
        // successful parse) will write this entry with source='regex', which
        // ensures the next cold start re-queues it for another upgrade attempt.
        _cache[key] = _regexFallback(key);
        _pendingReparse.remove(key);
      }
    }
  }

  /// Serialize the current in-memory [_cache] to SharedPreferences.
  /// Called fire-and-forget after every successful parse and every evict.
  static Future<void> _persistAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final map = {
        for (final entry in _cache.entries) entry.key: _toJson(entry.value),
      };
      await prefs.setString(_kPrefsKey, jsonEncode(map));
    } catch (_) {
      // I/O errors must never surface to the user.
    }
  }

  // ── Serialization ─────────────────────────────────────────────────────────

  static Map<String, dynamic> _toJson(ParsedRule r) => {
        'weekdays': r.weekdays.toList(),
        if (r.timeOfDay != null) 'timeOfDay': r.timeOfDay,
        'months': r.months.toList(),
        'topic': r.semanticTopic,
        'source': r.source,
      };

  // ── Proxy call ────────────────────────────────────────────────────────────

  static Future<ParsedRule?> _callProxy(String rule) async {
    try {
      final base = kIsWeb ? '' : _proxyBase;
      final resp = await http
          .post(
            Uri.parse('$base/api/gemini/parse-rule'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'rule': rule}),
          )
          .timeout(const Duration(seconds: 10));
      if (resp.statusCode != 200) return null;
      return _fromJson(jsonDecode(resp.body) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  // ── Direct Gemini call ────────────────────────────────────────────────────

  static Future<ParsedRule?> _callDirect(String rule) async {
    try {
      final resp = await http
          .post(
            Uri.parse('$_kGeminiUrl?key=$_directKey'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'contents': [
                {
                  'parts': [
                    {'text': _buildPrompt(rule)},
                  ],
                },
              ],
              'generationConfig': {
                'maxOutputTokens': 256,
                'temperature': 0.1,
              },
            }),
          )
          .timeout(const Duration(seconds: 10));
      if (resp.statusCode != 200) return null;
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final text =
          (data['candidates']?[0]?['content']?['parts']?[0]?['text']
                  as String?)
              ?.trim() ??
              '';
      final cleaned = text
          .replaceAll(RegExp(r'^```[a-z]*\n?', multiLine: true), '')
          .replaceAll(RegExp(r'```$', multiLine: true), '')
          .trim();
      return _fromJson(jsonDecode(cleaned) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  // ── JSON → ParsedRule ─────────────────────────────────────────────────────

  static ParsedRule _fromJson(Map<String, dynamic> j) => ParsedRule(
        weekdays: _parseWeekdays(j['weekdays']),
        timeOfDay: _validTod(j['timeOfDay'] as String?),
        months: _parseMonths(j['months']),
        semanticTopic: (j['topic'] as String?)?.trim() ?? '',
        // Old persisted entries that pre-date the source field are treated as
        // gemini results — they were written when Gemini was reachable.
        source: (j['source'] as String?) ?? ParsedRuleSource.gemini,
      );

  // ── Regex fallback ────────────────────────────────────────────────────────

  static const _kWeekdayWords = {
    'monday': 1,    'mondays': 1,
    'tuesday': 2,   'tuesdays': 2,
    'wednesday': 3, 'wednesdays': 3,
    'thursday': 4,  'thursdays': 4,
    'friday': 5,    'fridays': 5,
    'saturday': 6,  'saturdays': 6,
    'sunday': 7,    'sundays': 7,
    'weekday': -1,  'weekdays': -1,
    'weekend': -2,  'weekends': -2,
  };

  /// Build a [ParsedRule] from simple regex patterns when Gemini is not
  /// available.  Weekday and time-of-day extraction only; month and semantic
  /// topic are left empty / equal to the full rule.
  static ParsedRule _regexFallback(String rule) {
    final lower = rule.toLowerCase();

    final weekdays = <int>{};
    for (final entry in _kWeekdayWords.entries) {
      if (lower.contains(entry.key)) {
        switch (entry.value) {
          case -1:
            weekdays.addAll([1, 2, 3, 4, 5]);
          case -2:
            weekdays.addAll([6, 7]);
          default:
            weekdays.add(entry.value);
        }
      }
    }

    String? tod;
    if (lower.contains('morning')) {
      tod = 'morning';
    } else if (lower.contains('afternoon')) {
      tod = 'afternoon';
    } else if (lower.contains('evening')) {
      tod = 'evening';
    } else if (lower.contains('night')) {
      tod = 'night';
    }

    return ParsedRule(
      weekdays: weekdays,
      timeOfDay: tod,
      // Regex can't reliably extract month or semantic topic.
      months: <int>{},
      semanticTopic: rule,
      source: ParsedRuleSource.regex,
    );
  }

  // ── Normalization helpers ─────────────────────────────────────────────────

  static const _kDayName = {
    'monday': 1, 'tuesday': 2, 'wednesday': 3, 'thursday': 4,
    'friday': 5, 'saturday': 6, 'sunday': 7,
  };

  static Set<int> _parseWeekdays(dynamic raw) {
    if (raw is! List) return {};
    final result = <int>{};
    for (final item in raw) {
      final s = '$item'.toLowerCase();
      if (s == 'weekday') {
        result.addAll([1, 2, 3, 4, 5]);
      } else if (s == 'weekend') {
        result.addAll([6, 7]);
      } else if (_kDayName.containsKey(s)) {
        result.add(_kDayName[s]!);
      }
    }
    return result;
  }

  static const _kMonthName = {
    'january': 1,  'jan': 1,
    'february': 2, 'feb': 2,
    'march': 3,    'mar': 3,
    'april': 4,    'apr': 4,
    'may': 5,
    'june': 6,     'jun': 6,
    'july': 7,     'jul': 7,
    'august': 8,   'aug': 8,
    'september': 9,  'sep': 9, 'sept': 9,
    'october': 10,   'oct': 10,
    'november': 11,  'nov': 11,
    'december': 12,  'dec': 12,
  };

  static Set<int> _parseMonths(dynamic raw) {
    if (raw is! List) return {};
    final result = <int>{};
    for (final item in raw) {
      if (item is int) {
        if (item >= 1 && item <= 12) result.add(item);
      } else if (item is String) {
        final n = int.tryParse(item);
        if (n != null && n >= 1 && n <= 12) {
          result.add(n);
        } else {
          final mapped = _kMonthName[item.toLowerCase()];
          if (mapped != null) result.add(mapped);
        }
      }
    }
    return result;
  }

  static const _kValidTods = {'morning', 'afternoon', 'evening', 'night'};
  static String? _validTod(String? s) =>
      (s != null && _kValidTods.contains(s.toLowerCase()))
          ? s.toLowerCase()
          : null;

  // ── Prompt ────────────────────────────────────────────────────────────────

  static String _buildPrompt(String rule) =>
      'You are a calendar assistant. Parse this Smart Category rule into its components.\n\n'
      'Rule: "$rule"\n\n'
      'Return ONLY a JSON object:\n'
      '{"weekdays":[],"timeOfDay":null,"months":[],"topic":""}\n\n'
      'weekdays: lowercase day names. Use "weekday" for Mon–Fri group, "weekend" for Sat–Sun group. [] = no constraint.\n'
      'timeOfDay: "morning" (before noon), "afternoon" (noon–5 PM), "evening" (5–9 PM), "night" (after 9 PM), or null.\n'
      'months: month numbers 1–12. [] = no constraint.\n'
      'topic: semantic topic with all temporal/weekday/month words removed.\n\n'
      'Examples:\n'
      '  "weekday lunches in September" → {"weekdays":["weekday"],"timeOfDay":"afternoon","months":[9],"topic":"lunch"}\n'
      '  "Saturday morning workouts" → {"weekdays":["saturday"],"timeOfDay":"morning","months":[],"topic":"workout"}\n'
      '  "doctor appointments" → {"weekdays":[],"timeOfDay":null,"months":[],"topic":"doctor appointment"}\n\n'
      'Return ONLY the JSON, no markdown.';
}

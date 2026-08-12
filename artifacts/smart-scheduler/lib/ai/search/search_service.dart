import 'dart:async';

import '../ai_services.dart';
import '../date_parser/rule_based_date_parser.dart';
import '../interfaces.dart';
import '../../services/event_model.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SearchService — three-tier offline smart search pipeline.
//
// Tier 1 — Exact + date-normalised (instant, pure Dart):
//   • Case-folded substring match on title / location / destination / notes
//   • Multi-format date parser resolves any date representation the user types
//     ("8/12/26", "Aug 12 2026", "12 Aug", "Tuesday", "next week", …) to a
//     DateTimeRange, then compares against the event's parsedDate.absoluteDate.
//
// Tier 2 — Fuzzy (pure Dart, ~1 ms):
//   • Word-level Damerau-Levenshtein matching for missing, extra, substituted,
//     and transposed characters
//   • Character-bigram Jaccard similarity as a secondary signal
//   • Initials match: "aot" → "Attack on Titan"
//   • Token subsequence for abbreviations
//
// Tier 3 — Semantic + synonym fallback (offline, async):
//   • The existing TFLiteEmbeddingService / OnnxEmbeddingService embeds the
//     query; HnswVectorIndex.nearest() returns the closest stored event IDs.
//   • Synonym expansion fallback when the model is cold / unavailable:
//     the query is expanded through a curated synonym map, then Tier 1 exact
//     matching is re-applied to the expanded token set.
//
// Usage:
//   final results = await SearchService().query(q, allEvents,
//       scopeCategoryId: 'usr-1234');
//   // results.primary  — in-scope (same category) hits, score-boosted
//   // results.overflow — out-of-scope hits
//   // results.all      — flat ranked list (primary first, then overflow)
// ─────────────────────────────────────────────────────────────────────────────

enum SearchTier { exact, fuzzy, semantic, synonym }

/// A single matched event plus ranking metadata.
class SearchHit {
  final ScheduledEvent event;
  final double score;
  final SearchTier tier;

  /// Byte ranges [start, end) in the event title where the query matched.
  /// Used by [_HighlightedText] to bold/colour the matched substring.
  final List<MatchSpan> titleSpans;

  const SearchHit({
    required this.event,
    required this.score,
    required this.tier,
    this.titleSpans = const [],
  });
}

/// Half-open [start, end) character range for highlighting.
class MatchSpan {
  final int start;
  final int end;
  const MatchSpan(this.start, this.end);
}

/// Ranked results split into primary (in-scope) and overflow (other categories).
class SearchResults {
  final List<SearchHit> primary;
  final List<SearchHit> overflow;
  final String? suggestedQuery;

  const SearchResults({
    this.primary = const [],
    this.overflow = const [],
    this.suggestedQuery,
  });

  /// All hits merged: primary first, then overflow.
  List<SearchHit> get all => [...primary, ...overflow];

  bool get isEmpty => primary.isEmpty && overflow.isEmpty;
}

// ─────────────────────────────────────────────────────────────────────────────
// SearchService
// ─────────────────────────────────────────────────────────────────────────────
class SearchService {
  final EmbeddingService _embedding;
  final VectorIndex _vectorIndex;

  /// The optional dependencies keep the production service wired to
  /// [AIServices], while allowing the relevance gates to be tested with
  /// deterministic embedding/index implementations.
  SearchService({EmbeddingService? embedding, VectorIndex? vectorIndex})
    : _embedding = embedding ?? AIServices.embedding,
      _vectorIndex = vectorIndex ?? AIServices.vectorIndex;

  // Search result confidence is independent from correction confidence.
  // These values are deliberately named so they can be tuned against model
  // telemetry without changing the ranking algorithm.
  static const _kMinimumFuzzyScore = 0.56;
  static const _kMinimumFuzzyTokenEvidence = 0.62;
  static const _kMinimumFuzzyBigramEvidence = 0.68;
  static const _kMinimumSemanticScore = 0.55;
  static const _kSynonymMatchScore = 0.52;
  static const _kMinimumCorrectionTokenScore = 0.80;

  // ── Month name tables ───────────────────────────────────────────────────────
  static const _longMonths = [
    'january',
    'february',
    'march',
    'april',
    'may',
    'june',
    'july',
    'august',
    'september',
    'october',
    'november',
    'december',
  ];
  static const _shortMonths = [
    'jan',
    'feb',
    'mar',
    'apr',
    'may',
    'jun',
    'jul',
    'aug',
    'sep',
    'oct',
    'nov',
    'dec',
  ];
  static const _dayNames = [
    'monday',
    'tuesday',
    'wednesday',
    'thursday',
    'friday',
    'saturday',
    'sunday',
  ];

  // ── Date normalisation ──────────────────────────────────────────────────────
  // Returns a DateTimeRange that the query string represents, or null if the
  // query is not a recognisable date / time expression.

  static ({DateTime start, DateTime end})? _tryParseDateRange(String raw) {
    final parsed = RuleBasedDateParser().parse(raw);
    final parsedStart = parsed.startDateTime ?? parsed.absoluteDate;
    if (parsedStart != null) {
      final parsedEnd = parsed.endDateTime ?? parsedStart;
      return (
        start: DateTime(parsedStart.year, parsedStart.month, parsedStart.day),
        end: DateTime(parsedEnd.year, parsedEnd.month, parsedEnd.day),
      );
    }

    final s = raw.trim().toLowerCase();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // ── Relative ────────────────────────────────────────────────────────────
    if (s == 'today') return (start: today, end: today);
    if (s == 'tomorrow') {
      final t = today.add(const Duration(days: 1));
      return (start: t, end: t);
    }
    if (s == 'this week') {
      final start = today.subtract(Duration(days: today.weekday - 1));
      return (start: start, end: start.add(const Duration(days: 6)));
    }
    if (s == 'next week') {
      final start = today.add(Duration(days: 8 - today.weekday));
      return (start: start, end: start.add(const Duration(days: 6)));
    }

    // ── Day names ("tuesday", "next friday", "this saturday") ───────────────
    final stripped = s.replaceFirst('next ', '').replaceFirst('this ', '');
    final dayIdx = _dayNames.indexOf(stripped);
    if (dayIdx >= 0) {
      // Find the next occurrence of the requested weekday (including today).
      var target = today;
      for (int i = 0; i < 7; i++) {
        if (target.weekday - 1 == dayIdx) break;
        target = target.add(const Duration(days: 1));
      }
      // "next X" always skips to the following week even if X is today.
      if (s.startsWith('next ') && target.weekday - 1 == today.weekday - 1) {
        target = target.add(const Duration(days: 7));
      }
      return (start: target, end: target);
    }

    // ── ISO: 2026-08-12 ─────────────────────────────────────────────────────
    final iso = RegExp(r'^(\d{4})-(\d{1,2})-(\d{1,2})$').firstMatch(s);
    if (iso != null) {
      final d = _validDate(
        int.parse(iso.group(1)!),
        int.parse(iso.group(2)!),
        int.parse(iso.group(3)!),
      );
      if (d != null) return (start: d, end: d);
    }

    // ── Numeric: M/D/YY, M/D/YYYY, MM/DD/YYYY ───────────────────────────────
    final num_ = RegExp(
      r'^(\d{1,2})[/\-.](\d{1,2})[/\-.](\d{2,4})$',
    ).firstMatch(s);
    if (num_ != null) {
      var y = int.parse(num_.group(3)!);
      if (y < 100) y += 2000;
      final m = int.parse(num_.group(1)!);
      final d = int.parse(num_.group(2)!);
      if (m >= 1 && m <= 12 && d >= 1 && d <= 31) {
        final dt = _validDate(y, m, d);
        if (dt != null) return (start: dt, end: dt);
      }
    }

    // ── Month-Day: "Aug 12", "August 12, 2026", "Aug 12 2026" ───────────────
    final mdn = RegExp(
      r'^([a-z]+)\s+(\d{1,2})(?:[,\s]+(\d{4}))?$',
    ).firstMatch(s);
    if (mdn != null) {
      final mStr = mdn.group(1)!;
      final d = int.parse(mdn.group(2)!);
      final y = mdn.group(3) != null ? int.parse(mdn.group(3)!) : today.year;
      final month = _resolveMonth(mStr);
      if (month != null && d >= 1 && d <= 31) {
        final dt = _validDate(y, month, d);
        if (dt != null) return (start: dt, end: dt);
      }
    }

    // ── Day-Month: "12 Aug", "12 August", "12 Aug 2026", "12 August, 2026" ──
    final dmn = RegExp(
      r'^(\d{1,2})\s+([a-z]+)(?:[,\s]+(\d{4}))?$',
    ).firstMatch(s);
    if (dmn != null) {
      final d = int.parse(dmn.group(1)!);
      final mStr = dmn.group(2)!;
      final y = dmn.group(3) != null ? int.parse(dmn.group(3)!) : today.year;
      final month = _resolveMonth(mStr);
      if (month != null && d >= 1 && d <= 31) {
        final dt = _validDate(y, month, d);
        if (dt != null) return (start: dt, end: dt);
      }
    }

    return null;
  }

  static int? _bareWeekday(String raw) {
    final value = raw.trim().toLowerCase();
    final index = _dayNames.indexOf(value);
    return index < 0 ? null : index + 1;
  }

  static int? _resolveMonth(String s) {
    // Full name first, then 3-letter abbreviation.
    final full = _longMonths.indexOf(s);
    if (full >= 0) return full + 1;
    final abbr = _shortMonths.indexOf(s.length >= 3 ? s.substring(0, 3) : s);
    if (abbr >= 0) return abbr + 1;
    return null;
  }

  static DateTime? _validDate(int year, int month, int day) {
    if (month < 1 || month > 12 || day < 1 || day > 31) return null;
    final value = DateTime(year, month, day);
    if (value.year != year || value.month != month || value.day != day) {
      return null;
    }
    return value;
  }

  // ── Bigram helpers ──────────────────────────────────────────────────────────

  static Set<String> _bigrams(String s) {
    final lower = s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9 ]'), ' ').trim();
    if (lower.length < 2) return {};
    return {
      for (int i = 0; i < lower.length - 1; i++) lower.substring(i, i + 2),
    };
  }

  static double _bigramJaccard(String a, String b) {
    final ba = _bigrams(a);
    final bb = _bigrams(b);
    if (ba.isEmpty || bb.isEmpty) return 0;
    final inter = ba.intersection(bb).length;
    final union = ba.union(bb).length;
    return inter / union;
  }

  static double _bestTokenBigramScore(String query, Iterable<String> fields) {
    final queryTokens = _searchTokens(query).map(_normaliseToken);
    var best = 0.0;
    for (final queryToken in queryTokens) {
      for (final field in fields) {
        for (final targetToken in _searchTokens(field).map(_normaliseToken)) {
          final score = _bigramJaccard(queryToken, targetToken);
          if (score > best) best = score;
        }
      }
    }
    return best;
  }

  // ── Search normalisation ─────────────────────────────────────────────────────

  /// Reduce common inflections to the same search form without requiring a
  /// dictionary or a network service.  This intentionally stays conservative:
  /// it handles common plurals and verb forms while preserving short words and
  /// words ending in "ss".
  static String _normaliseToken(String token) {
    var value = token.toLowerCase();
    for (var pass = 0; pass < 2; pass++) {
      if (value.length > 4 && value.endsWith('ies')) {
        value = '${value.substring(0, value.length - 3)}y';
      } else if (value.length > 5 && value.endsWith('ing')) {
        value = value.substring(0, value.length - 3);
        value = _removePastTenseDouble(value);
      } else if (value.length > 4 && value.endsWith('ed')) {
        value = value.substring(0, value.length - 2);
        value = _removePastTenseDouble(value);
      } else if (value.length > 4 && value.endsWith('es')) {
        value = value.substring(0, value.length - 2);
      } else if (value.length > 3 &&
          value.endsWith('s') &&
          !value.endsWith('ss')) {
        value = value.substring(0, value.length - 1);
      }
    }
    return value;
  }

  /// Undo the doubled final consonant used by English inflections:
  /// shopping → shopp → shop, stopped → stopp → stop.
  ///
  /// Keep "ss" intact so words such as "missing" normalize to "miss", not
  /// "mis". This is deliberately small and deterministic rather than a full
  /// stemmer.
  static String _removePastTenseDouble(String value) {
    if (value.length > 3 &&
        value[value.length - 1] == value[value.length - 2] &&
        !value.endsWith('ss')) {
      return value.substring(0, value.length - 1);
    }
    return value;
  }

  static String _normaliseForSearch(String text) => _searchTokens(
    text,
  ).map(_normaliseToken).where((token) => token.isNotEmpty).join(' ');

  static List<({String text, double weight})> _searchFields(
    ScheduledEvent event,
  ) => [
    (text: event.title, weight: 1.00),
    if (event.subtitle != null && event.subtitle!.isNotEmpty)
      (text: event.subtitle!, weight: 0.88),
    if (event.location != null && event.location!.isNotEmpty)
      (text: event.location!, weight: 0.82),
    if (event.destination != null && event.destination!.isNotEmpty)
      (text: event.destination!, weight: 0.82),
    if (event.date != null && event.date!.isNotEmpty)
      (text: event.date!, weight: 0.78),
    if (event.time != null && event.time!.isNotEmpty)
      (text: event.time!, weight: 0.76),
    if (event.endDate != null && event.endDate!.isNotEmpty)
      (text: event.endDate!, weight: 0.74),
    if (event.endTime != null && event.endTime!.isNotEmpty)
      (text: event.endTime!, weight: 0.72),
    if (event.notes != null && event.notes!.isNotEmpty)
      (text: event.notes!, weight: 0.68),
    if (event.url != null && event.url!.isNotEmpty)
      (text: event.url!, weight: 0.65),
  ];

  static bool _allNormalisedTokensMatch(String query, String text) {
    final queryTokens = _searchTokens(
      query,
    ).map(_normaliseToken).where((token) => token.isNotEmpty).toList();
    final targetTokens = _searchTokens(
      text,
    ).map(_normaliseToken).where((token) => token.isNotEmpty).toList();
    if (queryTokens.isEmpty || targetTokens.isEmpty) return false;

    final used = <int>{};
    for (final queryToken in queryTokens) {
      var found = -1;
      for (var i = 0; i < targetTokens.length; i++) {
        if (!used.contains(i) && targetTokens[i] == queryToken) {
          found = i;
          break;
        }
      }
      if (found < 0) return false;
      used.add(found);
    }
    return true;
  }

  /// Weighted exact match.  Title matches outrank metadata and notes, while
  /// all-token matches work even when the user changes the word order.
  static double _weightedExactScore(String query, ScheduledEvent event) {
    final normalQuery = _normaliseForSearch(query);
    if (normalQuery.isEmpty) return 0.0;

    var best = 0.0;
    final fields = _searchFields(event);
    for (final field in fields) {
      final normalField = _normaliseForSearch(field.text);
      if (normalField.contains(normalQuery)) {
        if (field.weight > best) best = field.weight;
      } else if (_allNormalisedTokensMatch(normalQuery, field.text)) {
        final score = field.weight * 0.94;
        if (score > best) best = score;
      }
    }

    // "Dinner doctor" should still match "Doctor appointment" plus a note
    // containing "Dinner", even though no single field contains both terms.
    final combined = fields.map((field) => field.text).join(' ');
    if (_allNormalisedTokensMatch(normalQuery, combined)) {
      final score = 0.72;
      if (score > best) best = score;
    }
    return best;
  }

  static ({String lexical, List<String> dates}) _splitDateFragments(
    String raw,
  ) {
    final dates = <String>[];
    final numericDate = RegExp(r'\b\d{1,4}[/\-.]\d{1,2}[/\-.]\d{1,4}\b');
    var remainder = raw.replaceAllMapped(numericDate, (match) {
      final value = match.group(0)!;
      if (_tryParseDateRange(value) != null) dates.add(value);
      return ' ';
    });

    final tokens = _searchTokens(remainder);
    final lexicalTokens = <String>[];
    var index = 0;
    while (index < tokens.length) {
      var matchedLength = 0;
      var matchedDate = '';
      for (final length in [3, 2, 1]) {
        if (index + length > tokens.length) continue;
        final candidate = tokens.sublist(index, index + length).join(' ');
        if (_tryParseDateRange(candidate) != null) {
          matchedLength = length;
          matchedDate = candidate;
          break;
        }
      }
      if (matchedLength > 0) {
        dates.add(matchedDate);
        index += matchedLength;
      } else {
        lexicalTokens.add(tokens[index]);
        index++;
      }
    }

    remainder = lexicalTokens.join(' ');
    return (lexical: remainder, dates: dates);
  }

  static bool _eventMatchesDateFragment(ScheduledEvent event, String fragment) {
    final range = _tryParseDateRange(fragment);
    if (range == null) return false;

    final parsed = RuleBasedDateParser().parse(fragment);
    final weekday = _bareWeekday(fragment);
    final eventDates = <DateTime>[
      if (event.parsedDate?.absoluteDate != null)
        event.parsedDate!.absoluteDate!,
      ...(event.parsedDate?.alternateDates ?? const <DateTime>[]),
    ];
    return eventDates.any((date) {
      final day = DateTime(date.year, date.month, date.day);
      final weekdayMatch = weekday != null && date.weekday == weekday;
      final rangeMatch = !day.isBefore(range.start) && !day.isAfter(range.end);
      final parsedDateMatch =
          parsed.absoluteDate != null &&
          date.year == parsed.absoluteDate!.year &&
          date.month == parsed.absoluteDate!.month &&
          date.day == parsed.absoluteDate!.day;
      return weekdayMatch || rangeMatch || parsedDateMatch;
    });
  }

  // ── Typo-tolerant token matching ────────────────────────────────────────────
  //
  // Bigram similarity is useful for ranking related phrases, but comparing a
  // query with an entire field makes a one-character typo disappear inside a
  // long title.  Compare individual words instead so "meetng" can match
  // "meeting" and "doctro" can match "doctor".

  static List<String> _searchTokens(String text) => text
      .toLowerCase()
      .split(RegExp(r'[^a-z0-9]+'))
      .where((token) => token.isNotEmpty)
      .toList();

  static const _soundexCodes = <String, String>{
    'b': '1',
    'f': '1',
    'p': '1',
    'v': '1',
    'c': '2',
    'g': '2',
    'j': '2',
    'k': '2',
    'q': '2',
    's': '2',
    'x': '2',
    'z': '2',
    'd': '3',
    't': '3',
    'l': '4',
    'm': '5',
    'n': '5',
    'r': '6',
  };

  /// Small, deterministic Soundex implementation for phonetic fallback.
  static String _soundex(String token) {
    final letters = token.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');
    if (letters.length < 4) return '';

    final first = letters[0];
    final output = StringBuffer(first.toUpperCase());
    var previousCode = _soundexCodes[first] ?? '';
    for (var i = 1; i < letters.length && output.length < 4; i++) {
      final code = _soundexCodes[letters[i]] ?? '';
      if (code.isEmpty) {
        previousCode = '';
        continue;
      }
      if (code != previousCode) {
        output.write(code);
      }
      previousCode = code;
    }
    return output.toString().padRight(4, '0');
  }

  static bool _keyboardNeighbors(String a, String b) {
    const rows = ['qwertyuiop', 'asdfghjkl', 'zxcvbnm'];
    for (var rowA = 0; rowA < rows.length; rowA++) {
      final indexA = rows[rowA].indexOf(a);
      if (indexA < 0) continue;
      for (var rowB = 0; rowB < rows.length; rowB++) {
        final indexB = rows[rowB].indexOf(b);
        if (indexB < 0) continue;
        final rowDistance = (rowA - rowB).abs();
        final columnDistance = (indexA - indexB).abs();
        return rowDistance == 0 && columnDistance == 1 ||
            rowDistance == 1 && columnDistance <= 1;
      }
    }
    return false;
  }

  static double _keyboardTypoScore(String queryToken, String targetToken) {
    if (queryToken.length != targetToken.length || queryToken.length < 4) {
      return 0.0;
    }
    var mismatches = 0;
    for (var i = 0; i < queryToken.length; i++) {
      if (queryToken[i] == targetToken[i]) continue;
      if (!_keyboardNeighbors(queryToken[i], targetToken[i])) return 0.0;
      mismatches++;
    }
    if (mismatches == 1) return 0.92;
    if (mismatches == 2 && queryToken.length >= 7) return 0.80;
    return 0.0;
  }

  /// Damerau-Levenshtein distance with adjacent transpositions.
  ///
  /// The transposition case handles common keyboard typos such as "doctro"
  /// for "doctor" without making the general fuzzy threshold looser.
  static int _editDistance(String a, String b) {
    if (a == b) return 0;
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;

    var previousPrevious = List<int>.generate(b.length + 1, (index) => index);
    var previous = List<int>.generate(b.length + 1, (index) => index);

    for (var i = 1; i <= a.length; i++) {
      final current = List<int>.filled(b.length + 1, 0);
      current[0] = i;

      for (var j = 1; j <= b.length; j++) {
        final substitutionCost = a[i - 1] == b[j - 1] ? 0 : 1;
        var best = [
          current[j - 1] + 1,
          previous[j] + 1,
          previous[j - 1] + substitutionCost,
        ].reduce((x, y) => x < y ? x : y);

        if (i > 1 && j > 1 && a[i - 1] == b[j - 2] && a[i - 2] == b[j - 1]) {
          final transposition = previousPrevious[j - 2] + 1;
          if (transposition < best) best = transposition;
        }
        current[j] = best;
      }

      previousPrevious = previous;
      previous = current;
    }

    return previous[b.length];
  }

  static double _typoTokenScore(String queryToken, String targetToken) {
    if (queryToken == targetToken) return 1.0;

    final shorter = queryToken.length <= targetToken.length
        ? queryToken
        : targetToken;
    final longer = queryToken.length > targetToken.length
        ? queryToken
        : targetToken;
    if (shorter.length < 3) return 0.0;

    // Preserve useful prefix search without making a three-letter query match
    // any long word that happens to start with those letters.
    if (longer.startsWith(shorter) &&
        shorter.length >= 4 &&
        shorter.length / longer.length >= 0.55) {
      return 0.78 + 0.18 * (shorter.length / longer.length);
    }

    final distance = _editDistance(queryToken, targetToken);
    final maxDistance = longer.length <= 6 ? 1 : 2;
    if (distance > maxDistance) return 0.0;

    final similarity = 1.0 - (distance / longer.length);
    final minimumSimilarity = longer.length <= 3 ? 0.66 : 0.70;
    return similarity >= minimumSimilarity ? similarity : 0.0;
  }

  static double _smartTokenScore(String queryToken, String targetToken) {
    final typo = _typoTokenScore(queryToken, targetToken);
    final keyboard = _keyboardTypoScore(queryToken, targetToken);
    var phonetic = 0.0;
    if (queryToken.length >= 4 && targetToken.length >= 4) {
      final querySound = _soundex(queryToken);
      if (querySound.isNotEmpty && querySound == _soundex(targetToken)) {
        final shorter = queryToken.length < targetToken.length
            ? queryToken.length
            : targetToken.length;
        final longer = queryToken.length > targetToken.length
            ? queryToken.length
            : targetToken.length;
        phonetic = 0.68 + 0.16 * (shorter / longer);
      }
    }
    final result = [
      typo,
      keyboard,
      phonetic,
    ].reduce((best, score) => score > best ? score : best);
    return result;
  }

  /// Returns the average best token score when every query token can be
  /// matched to a distinct event token.  A zero result means the query is not
  /// a plausible typo of the event's searchable text.
  static double _tokenTypoScore(String query, List<String> searchableFields) {
    final queryTokens = _searchTokens(
      query,
    ).map(_normaliseToken).where((token) => token.isNotEmpty).toList();
    if (queryTokens.isEmpty) return 0.0;

    final targetTokens = <String>[
      for (final field in searchableFields)
        ..._searchTokens(field).map(_normaliseToken),
    ];
    if (targetTokens.isEmpty) return 0.0;

    final usedTargets = <int>{};
    var total = 0.0;
    for (final queryToken in queryTokens) {
      var best = 0.0;
      var bestIndex = -1;
      for (var i = 0; i < targetTokens.length; i++) {
        if (usedTargets.contains(i)) continue;
        final score = _smartTokenScore(queryToken, targetTokens[i]);
        if (score > best) {
          best = score;
          bestIndex = i;
        }
      }
      if (bestIndex < 0) return 0.0;
      usedTargets.add(bestIndex);
      total += best;
    }

    return total / queryTokens.length;
  }

  static double _weightedTypoScore(String query, ScheduledEvent event) {
    final fields = _searchFields(event);
    var best = 0.0;
    for (final field in fields) {
      final score = _tokenTypoScore(query, [field.text]) * field.weight;
      if (score > best) best = score;
    }

    // Multi-word queries are allowed to span title + metadata + notes, but
    // remain below a strong title-only match in the ranking.
    final combined = fields.map((field) => field.text).join(' ');
    final combinedScore = _tokenTypoScore(query, [combined]) * 0.72;
    if (combinedScore > best) best = combinedScore;
    return best;
  }

  // ── Initials match ──────────────────────────────────────────────────────────
  // "aot" matches "Attack on Titan" → first characters of each word = "AOT"

  static bool _initialsMatch(String query, String text) {
    final q = query.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    if (q.isEmpty) return false;
    final words = text.toLowerCase().split(RegExp(r'[\s\-_]+'));
    final initials = words.map((w) => w.isNotEmpty ? w[0] : '').join();
    return initials.contains(q) && q.length >= 2;
  }

  // ── Token subsequence ───────────────────────────────────────────────────────
  // All query tokens appear in order in the haystack (allows gaps).

  static bool _tokenSubsequence(String query, String haystack) {
    final tokens = query
        .toLowerCase()
        .split(RegExp(r'[^a-z0-9]+'))
        .where((token) => token.isNotEmpty)
        .toList();
    final target = haystack
        .toLowerCase()
        .split(RegExp(r'[^a-z0-9]+'))
        .where((token) => token.isNotEmpty)
        .toList();
    var from = 0;
    for (final queryToken in tokens) {
      var found = false;
      for (var i = from; i < target.length; i++) {
        // Prefix matching makes short queries such as "att on tit" useful
        // while preserving the order requirement of a subsequence match.
        if (target[i].startsWith(queryToken)) {
          from = i + 1;
          found = true;
          break;
        }
      }
      if (!found) return false;
    }
    return tokens.isNotEmpty;
  }

  // ── Synonym groups ──────────────────────────────────────────────────────────
  // Superset of HybridMatcher._kSynonymGroups — also updated there for
  // Smart Category matching consistency.

  static const _kSynonymGroups = <Set<String>>[
    {
      'eat',
      'eating',
      'food',
      'meal',
      'lunch',
      'dinner',
      'breakfast',
      'brunch',
      'snack',
      'restaurant',
      'cafe',
      'dining',
      'grocery',
      'groceries',
      'supper',
    },
    {
      'exercise',
      'workout',
      'gym',
      'run',
      'running',
      'yoga',
      'swim',
      'swimming',
      'fitness',
      'sport',
      'sports',
      'training',
      'cycling',
      'hike',
      'hiking',
      'walk',
      'walking',
      'jog',
      'jogging',
    },
    {
      'meeting',
      'call',
      'conference',
      'sync',
      'standup',
      'interview',
      'review',
      'presentation',
      'demo',
      'work',
      'office',
      'client',
    },
    {
      'birthday',
      'bday',
      'anniversary',
      'celebrate',
      'celebration',
      'party',
      'bash',
      'gathering',
    },
    {
      'travel',
      'trip',
      'flight',
      'hotel',
      'vacation',
      'holiday',
      'journey',
      'airbnb',
      'airport',
    },
    {
      'doctor',
      'appointment',
      'medical',
      'dentist',
      'hospital',
      'clinic',
      'health',
      'checkup',
      'therapy',
      'physio',
    },
    {
      'family',
      'kids',
      'children',
      'school',
      'pickup',
      'dropoff',
      'parent',
      'son',
      'daughter',
      'wife',
      'husband',
    },
    {
      'shop',
      'shopping',
      'store',
      'mall',
      'buy',
      'purchase',
      'errands',
      'market',
    },
    // Entertainment / media
    {
      'anime',
      'manga',
      'cartoon',
      'animation',
      'animated',
      'series',
      'episode',
      'otaku',
      'watch',
      'viewing',
      'stream',
      'streaming',
      'netflix',
      'crunchyroll',
    },
    {
      'movie',
      'film',
      'cinema',
      'theater',
      'theatre',
      'screening',
      'blockbuster',
    },
    {
      'music',
      'concert',
      'gig',
      'band',
      'album',
      'song',
      'playlist',
      'listen',
      'show',
      'festival',
      'performance',
    },
    {
      'game',
      'gaming',
      'videogame',
      'esport',
      'play',
      'playstation',
      'xbox',
      'nintendo',
      'steam',
      'pc',
    },
    // Leisure / hobbies
    {
      'book',
      'reading',
      'novel',
      'library',
      'read',
      'chapter',
      'fiction',
      'nonfiction',
      'ebook',
    },
    {
      'hobby',
      'craft',
      'art',
      'painting',
      'drawing',
      'knitting',
      'gardening',
      'photography',
      'photo',
      'diy',
    },
    {'sleep', 'rest', 'nap', 'relax', 'meditation', 'spa', 'massage', 'chill'},
    // Finance
    {
      'finance',
      'money',
      'bank',
      'budget',
      'payment',
      'bill',
      'invoice',
      'salary',
      'tax',
      'invest',
      'savings',
    },
    // Chores
    {
      'clean',
      'cleaning',
      'chores',
      'laundry',
      'tidy',
      'dishes',
      'housework',
      'vacuum',
      'mop',
      'sweep',
    },
    // Social
    {'date', 'romantic', 'relationship', 'love', 'valentine', 'anniversary'},
    {
      'church',
      'prayer',
      'worship',
      'religious',
      'spiritual',
      'mosque',
      'temple',
      'mass',
      'service',
    },
    // School / work
    {
      'project',
      'deadline',
      'submit',
      'assignment',
      'homework',
      'report',
      'presentation',
      'essay',
      'thesis',
    },
    {
      'study',
      'studying',
      'learn',
      'learning',
      'course',
      'class',
      'lecture',
      'tutorial',
    },
  ];

  static Set<String> _expandSynonyms(String query) {
    final tokens = query
        .toLowerCase()
        .split(RegExp(r'[^a-z0-9]+'))
        .where((t) => t.length >= 3)
        .toSet();
    if (tokens.isEmpty) return tokens;
    final expanded = Set<String>.from(tokens);
    for (final tok in List<String>.from(tokens)) {
      for (final group in _kSynonymGroups) {
        if (group.contains(tok)) {
          expanded.addAll(group);
          break;
        }
      }
    }
    return expanded;
  }

  // ── Event haystack ──────────────────────────────────────────────────────────

  static String _haystack(ScheduledEvent e) => [
    e.title,
    if (e.subtitle != null) e.subtitle!,
    if (e.date != null) e.date!,
    if (e.time != null) e.time!,
    if (e.endDate != null) e.endDate!,
    if (e.location != null) e.location!,
    if (e.destination != null) e.destination!,
    if (e.notes != null) e.notes!,
    if (e.url != null) e.url!,
  ].join(' ').toLowerCase();

  static String _embeddingId(ScheduledEvent event) {
    final marker = event.id.indexOf('_r');
    return marker > 0 ? event.id.substring(0, marker) : event.id;
  }

  // ── Title highlight spans ───────────────────────────────────────────────────

  static List<MatchSpan> _titleSpans(String title, String query) {
    final spans = <MatchSpan>[];
    final lower = title.toLowerCase();
    final q = query.toLowerCase().trim();
    if (q.isEmpty) return spans;

    // Full query string first.
    var pos = 0;
    while (true) {
      final idx = lower.indexOf(q, pos);
      if (idx < 0) break;
      spans.add(MatchSpan(idx, idx + q.length));
      pos = idx + q.length;
    }

    // Individual tokens if no full match.
    if (spans.isEmpty) {
      for (final tok in q.split(RegExp(r'\s+')).where((t) => t.length >= 2)) {
        var p = 0;
        while (true) {
          final idx = lower.indexOf(tok, p);
          if (idx < 0) break;
          spans.add(MatchSpan(idx, idx + tok.length));
          p = idx + tok.length;
        }
      }
    }

    spans.sort((a, b) => a.start.compareTo(b.start));
    return spans;
  }

  static List<String> _displayTokens(String text) => text
      .split(RegExp(r'[^A-Za-z0-9]+'))
      .where((token) => token.isNotEmpty)
      .toList();

  /// Find a likely spelling correction from lexical evidence only.
  ///
  /// This intentionally does not receive ranked hits. A semantic nearest
  /// neighbor is evidence that an event is related, not evidence that its
  /// title is what the user meant to type.
  static String? _correctionFor(String query, List<ScheduledEvent> events) {
    final queryTokens = _searchTokens(
      query,
    ).map(_normaliseToken).where((token) => token.isNotEmpty).toList();
    if (queryTokens.isEmpty || events.isEmpty) return null;

    final displayTokens = <String>[
      for (final event in events)
        for (final field in _searchFields(event)) ..._displayTokens(field.text),
    ];
    // Deduplicate by the normalised token rather than raw casing. Otherwise
    // "Birthday" and "birthday" would count as competing candidates even
    // though they represent the same correction.
    final uniqueDisplayTokens = <String, String>{};
    for (final displayToken in displayTokens) {
      uniqueDisplayTokens.putIfAbsent(
        _normaliseToken(displayToken),
        () => displayToken,
      );
    }
    final replacements = <String>[];
    var changed = false;

    for (final queryToken in queryTokens) {
      var bestScore = 0.0;
      String? bestToken;
      var secondBestScore = 0.0;
      for (final displayToken in uniqueDisplayTokens.values) {
        final targetToken = _normaliseToken(displayToken);
        if (targetToken == queryToken) continue;
        final score = _smartTokenScore(queryToken, targetToken);
        if (score > bestScore) {
          secondBestScore = bestScore;
          bestScore = score;
          bestToken = displayToken;
        } else if (score > secondBestScore) {
          secondBestScore = score;
        }
      }
      // Require both a strong lexical match and a clear winner. This prevents
      // an arbitrary event word from becoming a correction merely because it
      // is the nearest token available.
      final hasClearWinner =
          bestScore - secondBestScore >= 0.06 || secondBestScore == 0.0;
      if (bestToken != null &&
          bestScore >= _kMinimumCorrectionTokenScore &&
          hasClearWinner) {
        replacements.add(bestToken);
        if (_normaliseToken(bestToken) != queryToken) changed = true;
      } else {
        replacements.add(queryToken);
      }
    }

    return changed ? replacements.join(' ') : null;
  }

  // ── Main query ──────────────────────────────────────────────────────────────

  /// Run the full search pipeline and return ranked [SearchResults].
  ///
  /// [q]               — raw user query string.
  /// [all]             — full event pool to search (typically EventStore.instance.events.value).
  /// [scopeCategoryId] — when set, events with this categoryId are collected into
  ///                     [SearchResults.primary] (with a +0.2 score boost) and all
  ///                     other hits go into [SearchResults.overflow].  Pass null for
  ///                     a flat ranked result (Notes / Calendar / Events grid).
  Future<SearchResults> query(
    String q,
    List<ScheduledEvent> all, {
    String? scopeCategoryId,
    Set<String>? scopeEventIds,
  }) async {
    final trimmed = q.trim();
    if (trimmed.isEmpty || all.isEmpty) return const SearchResults();

    final scores = <String, double>{};
    final tiers = <String, SearchTier>{};
    final spans = <String, List<MatchSpan>>{};

    final qLower = trimmed.toLowerCase();
    final queryParts = _splitDateFragments(trimmed);
    final lexicalQuery = queryParts.lexical;
    final dateFragments = queryParts.dates;
    final hasDateFilter = dateFragments.isNotEmpty;
    final parsedQuery = RuleBasedDateParser().parse(trimmed);
    final queryTime = parsedQuery.canonicalTime;

    // ── Tier 1: Exact + date-normalised ────────────────────────────────────
    for (final event in all) {
      final hay = _haystack(event);
      final textScore = lexicalQuery.isEmpty
          ? 0.0
          : _weightedExactScore(lexicalQuery, event);
      final dateHit = dateFragments.any(
        (fragment) => _eventMatchesDateFragment(event, fragment),
      );
      final directTextHit = hay.contains(qLower);

      // A compound search such as "doctor tomorrow" must satisfy both the
      // lexical and date portions; a date-only search only needs its date.
      bool hit = hasDateFilter
          ? dateHit &&
                (lexicalQuery.isEmpty || textScore > 0.0 || directTextHit)
          : textScore > 0.0 || directTextHit;

      if (!hit && !hasDateFilter && queryTime != null) {
        final storedTime =
            event.parsedDate?.canonicalTime ??
            RuleBasedDateParser().parse(event.time ?? '').canonicalTime;
        hit = storedTime == queryTime;
      }

      if (hit) {
        // Date-only matches are exact but slightly below an exact title match.
        // This keeps a direct title result at the top when both are present.
        scores[event.id] = textScore > 0.0 ? textScore : 0.96;
        tiers[event.id] = SearchTier.exact;
        spans[event.id] = _titleSpans(event.title, trimmed);
      }
    }

    // ── Tier 2: Fuzzy ───────────────────────────────────────────────────────
    for (final event in all) {
      if ((scores[event.id] ?? 0) >= 0.9) continue;
      if (hasDateFilter &&
          !dateFragments.any(
            (fragment) => _eventMatchesDateFragment(event, fragment),
          )) {
        continue;
      }

      final searchQuery = lexicalQuery.isEmpty ? trimmed : lexicalQuery;
      final fields = _searchFields(event).map((field) => field.text).toList();
      final bigram = _bestTokenBigramScore(searchQuery, fields);
      final tokenTypo = _weightedTypoScore(searchQuery, event);
      final initials = _initialsMatch(searchQuery, event.title) ? 0.72 : 0.0;
      final subseq = _tokenSubsequence(searchQuery, _haystack(event))
          ? 0.66
          : 0.0;
      final fuzzy = [
        bigram * 0.85,
        // Keep typo matches below exact matches but above weak semantic
        // matches, so a clear one- or two-edit result is easy to find.
        tokenTypo * 0.90,
        initials,
        subseq,
      ].reduce((a, b) => a > b ? a : b);
      final hasStrongFuzzyEvidence =
          tokenTypo >= _kMinimumFuzzyTokenEvidence ||
          bigram >= _kMinimumFuzzyBigramEvidence ||
          initials > 0.0 ||
          subseq > 0.0;
      if (fuzzy >= _kMinimumFuzzyScore && hasStrongFuzzyEvidence) {
        final current = scores[event.id] ?? 0;
        if (fuzzy > current) {
          scores[event.id] = fuzzy;
          tiers[event.id] = SearchTier.fuzzy;
          spans.putIfAbsent(event.id, () => _titleSpans(event.title, trimmed));
        }
      }
    }

    // ── Tier 3a: Semantic via vector index ──────────────────────────────────
    try {
      final embedding = await _embedding
          .embed(trimmed)
          .timeout(const Duration(milliseconds: 600));

      // NullEmbeddingService returns an all-zero vector — skip when not ready.
      final isReal = embedding.any((v) => v != 0.0);
      if (isReal) {
        final nearest = await _vectorIndex.nearestScored(embedding, topK: 40);
        final eventsByEmbeddingId = <String, List<ScheduledEvent>>{};
        for (final event in all) {
          eventsByEmbeddingId
              .putIfAbsent(_embeddingId(event), () => [])
              .add(event);
        }
        for (final result in nearest) {
          final semScore = result.score;
          if (semScore <= _kMinimumSemanticScore) continue;
          // A recurring occurrence shares the base event's vector. Apply the
          // semantic hit to every visible occurrence in the current corpus.
          for (final event in eventsByEmbeddingId[result.id] ?? const []) {
            if (hasDateFilter &&
                !dateFragments.any(
                  (fragment) => _eventMatchesDateFragment(event, fragment),
                )) {
              continue;
            }
            final current = scores[event.id] ?? 0;
            if (semScore > current) {
              scores[event.id] = semScore;
              tiers[event.id] = SearchTier.semantic;
            }
          }
        }
      }
    } catch (_) {
      // Model timeout or not yet initialised — fall through to synonym tier.
    }

    // ── Tier 3b: Synonym expansion fallback ─────────────────────────────────
    final synonyms = _expandSynonyms(trimmed);
    // Run this deterministic vocabulary pass even when embeddings are
    // available. The vector path is intentionally recall-oriented, while
    // synonym expansion provides a stable offline result for terms such as
    // "anime" → "watch" and also covers a cold/empty vector index.
    final originalTokens = _searchTokens(
      trimmed,
    ).map(_normaliseToken).where((token) => token.isNotEmpty).toSet();
    final expandedTokens = synonyms
        .map(_normaliseToken)
        .where((token) => token.isNotEmpty && !originalTokens.contains(token))
        .toSet();
    if (expandedTokens.isNotEmpty) {
      for (final event in all) {
        final currentScore = scores[event.id] ?? 0;
        final eventTokens = _searchTokens(
          _haystack(event),
        ).map(_normaliseToken).where((token) => token.isNotEmpty).toSet();
        // A synonym is only a hit when an expanded token is explicitly
        // present in the event text. It must not be inferred from a nearest
        // vector or from a substring such as "shop" inside "workshop".
        final matched = expandedTokens.any(eventTokens.contains);
        if (matched && _kSynonymMatchScore > currentScore) {
          scores[event.id] = _kSynonymMatchScore;
          tiers[event.id] = SearchTier.synonym;
        }
      }
    }

    // ── Build & rank hits ───────────────────────────────────────────────────
    final byId = {for (final e in all) e.id: e};
    final hits =
        scores.entries
            .where((e) => byId.containsKey(e.key))
            .map(
              (e) => SearchHit(
                event: byId[e.key]!,
                score: e.value,
                tier: tiers[e.key] ?? SearchTier.fuzzy,
                titleSpans: spans[e.key] ?? [],
              ),
            )
            .toList()
          ..sort((a, b) {
            final c = b.score.compareTo(a.score);
            return c != 0 ? c : a.tier.index.compareTo(b.tier.index);
          });

    // ── Split into primary / overflow ───────────────────────────────────────
    final effectiveScopeIds =
        scopeEventIds ??
        (scopeCategoryId == null
            ? null
            : {
                for (final event in all)
                  if (event.categoryId == scopeCategoryId) event.id,
              });
    if (effectiveScopeIds == null) {
      return SearchResults(
        primary: hits,
        overflow: [],
        suggestedQuery: _correctionFor(trimmed, all),
      );
    }

    final primary = <SearchHit>[];
    final overflow = <SearchHit>[];
    for (final hit in hits) {
      if (effectiveScopeIds.contains(hit.event.id)) {
        primary.add(
          SearchHit(
            event: hit.event,
            // Keep the boost above 1.0 for exact matches. Clamping would make
            // an in-scope exact hit tie with an out-of-scope exact hit and
            // defeat the DCV priority rule.
            score: hit.score + 0.2,
            tier: hit.tier,
            titleSpans: hit.titleSpans,
          ),
        );
      } else {
        overflow.add(hit);
      }
    }
    primary.sort((a, b) => b.score.compareTo(a.score));

    return SearchResults(
      primary: primary,
      overflow: overflow,
      suggestedQuery: _correctionFor(trimmed, all),
    );
  }
}

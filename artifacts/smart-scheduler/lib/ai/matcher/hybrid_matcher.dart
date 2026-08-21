import 'dart:math' show sqrt;
import '../interfaces.dart';
import '../parsed_date.dart';
import '../smart_rule_parser.dart';
import '../../services/event_model.dart';

// ─────────────────────────────────────────────────────────────────────────────
// HybridMatcher — Phase 2 implementation of SmartCategoryMatcher.
//
// Combines two signals:
//   1. Date-range filtering (identical to DeterministicMatcher) for built-in
//      tiles and any time-based concept in user-rule text.
//   2. Vector cosine similarity between the Smart Category's stored embedding
//      and each event's stored embedding — for semantic concepts.
//
// The category embedding is stored per-category alongside its JSON (via
// AIServices.categoryEmbeddingStore).  If the embedding for a category or
// event is absent (zero-vector or null), the matcher falls back to keyword
// matching from DeterministicMatcher so results are never empty.
//
// Phase 3 can tune the threshold or add re-ranking without changing callers.
// ─────────────────────────────────────────────────────────────────────────────
class HybridMatcher implements SmartCategoryMatcher {
  /// Cosine similarity threshold: events with score >= this are included.
  static const double _threshold = 0.18;

  /// Top-N events returned from semantic search (before date post-filter).
  static const int _topN = 50;

  // Stop-words (same as DeterministicMatcher — kept here to avoid import cycle)
  static const _stopWords = {
    'a', 'an', 'the', 'and', 'or', 'but', 'in', 'on', 'at', 'to', 'for',
    'of', 'with', 'by', 'from', 'as', 'is', 'was', 'are', 'were',
    'be', 'been', 'being', 'have', 'has', 'had', 'do', 'does', 'did',
    'will', 'would', 'could', 'should', 'may', 'might', 'must', 'shall',
    'can', 'not', 'no', 'nor', 'so', 'yet', 'both', 'either', 'neither',
    'any', 'all', 'each', 'every', 'some', 'my', 'your', 'his', 'her',
    'its', 'our', 'their', 'this', 'that', 'these', 'those',
    'i', 'me', 'we', 'you', 'he', 'she', 'it', 'they', 'them', 'us',
    'who', 'what', 'when', 'where', 'how', 'which', 'event', 'events',
  };

  /// Map from categoryName → its embedding vector.
  /// Populated externally when a Smart Category is created/updated.
  final _categoryEmbeddings = <String, List<double>>{};

  /// Map from eventId → its embedding vector.
  /// Populated externally by EventPipeline.
  final _eventEmbeddings = <String, List<double>>{};

  /// Map from rule string → its locally parsed rule components.
  /// Populated by [setParsedRule] when AIServices.parseAndRegisterRule resolves.
  final _parsedRules = <String, ParsedRule>{};

  // ── External registration ──────────────────────────────────────────────────

  void setCategoryEmbedding(String categoryName, List<double> embedding) {
    _categoryEmbeddings[categoryName] = embedding;
  }

  void setEventEmbedding(String eventId, List<double> embedding) {
    _eventEmbeddings[eventId] = embedding;
  }

  void removeEventEmbedding(String eventId) {
    _eventEmbeddings.remove(eventId);
  }

  void setParsedRule(String rule, ParsedRule parsed) {
    _parsedRules[rule] = parsed;
  }

  void removeParsedRule(String rule) {
    _parsedRules.remove(rule);
  }

  // ── SmartCategoryMatcher interface ────────────────────────────────────────

  @override
  List<ScheduledEvent> match({
    required List<ScheduledEvent> candidates,
    required String rule,
    String? builtInLabel,
    String? categoryName,
    DateTime? now,
  }) {
    final ref = now ?? DateTime.now();

    if (builtInLabel != null) {
      return _matchBuiltIn(candidates, builtInLabel, ref);
    }

    return _matchUserRule(candidates, rule, ref, categoryName: categoryName);
  }

  // ── Built-in tile matching (unchanged from DeterministicMatcher) ──────────

  List<ScheduledEvent> _matchBuiltIn(
    List<ScheduledEvent> candidates,
    String label,
    DateTime ref,
  ) {
    switch (label) {
      case 'Today':
        return candidates
            .where((e) => e.parsedDate?.isToday(ref) == true)
            .toList();
      case 'Tomorrow':
        return candidates
            .where((e) => e.parsedDate?.isTomorrow(ref) == true)
            .toList();
      case 'This Week':
        return candidates
            .where((e) => e.parsedDate?.isThisWeek(ref) == true)
            .toList();
      case 'Next Week':
        return candidates
            .where((e) => e.parsedDate?.isNextWeek(ref) == true)
            .toList();
      case 'This Month':
        return candidates
            .where((e) => e.parsedDate?.isThisMonth(ref) == true)
            .toList();
      case 'Next Month':
        return candidates
            .where((e) => e.parsedDate?.isNextMonth(ref) == true)
            .toList();
      case 'Scheduled':
        return candidates
            .where((e) => e.parsedDate?.isScheduled == true)
            .toList();
      case 'Unscheduled':
        return candidates
            .where((e) => e.parsedDate == null || !e.parsedDate!.isScheduled)
            .toList();
      case 'All Events':
        return List.of(candidates);
      case 'Completed':
        return [];
      default:
        return [];
    }
  }

  // ── User Smart Category matching ───────────────────────────────────────────

  List<ScheduledEvent> _matchUserRule(
    List<ScheduledEvent> candidates,
    String rule,
    DateTime ref, {
    String? categoryName,
  }) {
    if (rule.trim().isEmpty) return [];
    final ruleLower = rule.toLowerCase();

    // ── Step 1: resolve temporal constraints ────────────────────────────
    // Prefer a parsed rule if one has been registered; fall back to
    // the built-in regex extractors so matching is never left empty-handed.
    final pr = _parsedRules[rule];
    final weekdays = pr != null ? pr.weekdays : _extractWeekdays(ruleLower);
    final timeOfDay = pr != null ? pr.timeOfDay : _extractTimeOfDay(ruleLower);
    final months = pr?.months ?? const <int>{};
    // Date-range predicates (today / this week / etc.) always use regex —
    // they are precise, short-lived, and don't benefit from AI parsing.
    final dateRange = _dateRangeFromRule(ruleLower, ref);

    // ── Step 2: apply hard filters (AND logic) ───────────────────────────
    final List<ScheduledEvent> filtered;
    if (weekdays.isEmpty &&
        timeOfDay == null &&
        months.isEmpty &&
        dateRange == null) {
      filtered = candidates; // no temporal constraint — all candidates eligible
    } else {
      filtered = candidates.where((e) {
        final abs = e.parsedDate?.absoluteDate;
        // Events without a resolved date cannot satisfy any temporal constraint.
        if (abs == null) return false;
        // Weekday: event's weekday must be in the allowed set.
        if (weekdays.isNotEmpty && !weekdays.contains(abs.weekday)) return false;
        // Time-of-day: event's time label must match.
        if (timeOfDay != null && _timeOfDayLabel(e.time) != timeOfDay) return false;
        // Month: event's calendar month must be in the allowed set.
        if (months.isNotEmpty && !months.contains(abs.month)) return false;
        // Date-range predicate (today / this week / etc.).
        if (dateRange != null && !dateRange(e)) return false;
        return true;
      }).toList();
    }

    // ── Step 3: semantic vector match on the filtered set ────────────────
    // Embeddings are stored by category name (via setCategoryEmbedding).
    // Fall back to rule text as key for any legacy entries stored that way.
    final catVec = _categoryEmbeddings[categoryName] ?? _categoryEmbeddings[rule];
    if (catVec != null && !_isZero(catVec)) {
      final semantic = _vectorMatch(filtered, catVec);
      if (semantic.isNotEmpty) return semantic;
      // Fall through: embedding exists but nothing scored above threshold
      // (e.g. new events not yet embedded). Try keyword on same filtered set.
    }

    // ── Step 4: keyword fallback on filtered candidates ──────────────────
    // When a ParsedRule is available, use its semantic topic (temporal words
    // stripped) so keyword scoring doesn't penalise events for lacking month
    // or weekday words that aren't part of the event's content.
    final keywordRule =
        (pr != null && pr.semanticTopic.isNotEmpty) ? pr.semanticTopic : rule;
    return _keywordMatch(filtered, keywordRule);
  }

  // ── Temporal constraint extractors ─────────────────────────────────────────

  // Weekday word → DateTime.weekday value (Mon=1 … Sun=7).
  // Sentinel -1 = weekdays (Mon–Fri).  Sentinel -2 = weekend (Sat–Sun).
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

  /// Returns the set of allowed [DateTime.weekday] values encoded in [rule].
  /// Empty means no weekday constraint.
  static Set<int> _extractWeekdays(String ruleLower) {
    final result = <int>{};
    for (final entry in _kWeekdayWords.entries) {
      if (ruleLower.contains(entry.key)) {
        switch (entry.value) {
          case -1:
            result.addAll(const [1, 2, 3, 4, 5]); // Mon–Fri
          case -2:
            result.addAll(const [6, 7]); // Sat–Sun
          default:
            result.add(entry.value);
        }
      }
    }
    return result;
  }

  /// Returns the time-of-day bucket the rule requires, or null.
  static String? _extractTimeOfDay(String ruleLower) {
    if (ruleLower.contains('morning')) return 'morning';
    if (ruleLower.contains('afternoon')) return 'afternoon';
    if (ruleLower.contains('evening')) return 'evening';
    if (ruleLower.contains('night')) return 'night';
    return null;
  }

  /// Returns a predicate that tests whether an event falls in the date range
  /// implied by [rule], or null if no such range is present.
  static bool Function(ScheduledEvent)? _dateRangeFromRule(
    String ruleLower,
    DateTime ref,
  ) {
    if (ruleLower.contains('today')) {
      return (e) => e.parsedDate?.isToday(ref) == true;
    }
    if (ruleLower.contains('tomorrow')) {
      return (e) => e.parsedDate?.isTomorrow(ref) == true;
    }
    if (ruleLower.contains('this week')) {
      return (e) => e.parsedDate?.isThisWeek(ref) == true;
    }
    if (ruleLower.contains('next week')) {
      return (e) => e.parsedDate?.isNextWeek(ref) == true;
    }
    if (ruleLower.contains('this month')) {
      return (e) => e.parsedDate?.isThisMonth(ref) == true;
    }
    return null;
  }

  List<ScheduledEvent> _vectorMatch(
    List<ScheduledEvent> candidates,
    List<double> catVec,
  ) {
    final qNorm = _norm(catVec);
    if (qNorm == 0) return [];

    final scored = <MapEntry<ScheduledEvent, double>>[];
    for (final event in candidates) {
      // Expanded recurring occurrences have IDs like "42_r20260901".
      // Their embeddings are stored under the base event's original ID ("42").
      final embeddingId = event.id.contains('_r')
          ? event.id.split('_r').first
          : event.id;
      final evVec = _eventEmbeddings[embeddingId];
      if (evVec == null || _isZero(evVec)) continue;
      final vNorm = _norm(evVec);
      if (vNorm == 0) continue;
      final score = _dot(catVec, evVec) / (qNorm * vNorm);
      if (score >= _threshold) scored.add(MapEntry(event, score));
    }

    scored.sort((a, b) => b.value.compareTo(a.value));
    return scored.take(_topN).map((e) => e.key).toList();
  }

  // Converts a stored time string to a time-of-day label so rules like
  // "Sunday morning" can hard-filter on time bucket.
  //
  // Primary format: 12-hour AM/PM ("9:30 AM", "2:00 PM") — enforced by
  // EventStore.create() and .update() since the normalisation added in Task #26.
  // All events created or edited after that point are guaranteed to use this
  // format, so the 12-hour branch is the only path exercised for new data.
  //
  // The 24-hour branch ("09:00", "14:30") is kept as a legacy safety net for
  // any events that were written before normalisation was in place.  It is dead
  // code for all events created after the Task #26 fix and can be removed once
  // those pre-existing events have been re-saved or the app has been
  // re-installed — but retaining it costs nothing and prevents silent mismatch.
  static String? _timeOfDayLabel(String? timeStr) {
    if (timeStr == null || timeStr.isEmpty) return null;
    final trimmed = timeStr.trim();

    // ── 12-hour (primary): "9:30 AM" / "2:00 PM" ────────────────────────
    final m12 = RegExp(
      r'^(\d{1,2}):(\d{2})\s*(AM|PM)$',
      caseSensitive: false,
    ).firstMatch(trimmed);
    if (m12 != null) {
      var hour = int.parse(m12.group(1)!);
      final isPm = m12.group(3)!.toUpperCase() == 'PM';
      if (isPm && hour != 12) hour += 12;
      if (!isPm && hour == 12) hour = 0;
      return _hourToTod(hour);
    }

    // ── 24-hour (legacy safety net): "09:00" / "14:30" / "20:00" ────────
    // Only reached for events stored before time normalisation was added.
    final m24 = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(trimmed);
    if (m24 != null) {
      final hour = int.parse(m24.group(1)!);
      if (hour >= 0 && hour <= 23) return _hourToTod(hour);
    }

    return null;
  }

  /// Maps an absolute 24-hour [hour] (0–23) to a named time-of-day bucket.
  static String _hourToTod(int hour) {
    if (hour >= 5 && hour < 12) return 'morning';
    if (hour >= 12 && hour < 17) return 'afternoon';
    if (hour >= 17 && hour < 21) return 'evening';
    return 'night'; // 21–23 and 0–4
  }

  // ── Synonym / concept groups ───────────────────────────────────────────────
  // When a rule keyword belongs to one of these groups, all other words in the
  // group are also added to the keyword set so the matcher can bridge related
  // concepts that don't share a common root (e.g. "eat" → "lunch", "dinner").
  static const _kSynonymGroups = <Set<String>>[
    // Food / eating
    {
      'eat', 'eating', 'food', 'meal', 'lunch', 'dinner', 'breakfast',
      'brunch', 'snack', 'restaurant', 'cafe', 'dining', 'grocery',
      'groceries', 'supper',
    },
    // Exercise / fitness
    {
      'exercise', 'workout', 'gym', 'run', 'running', 'yoga', 'swim',
      'swimming', 'fitness', 'sport', 'sports', 'training', 'cycling',
      'hike', 'hiking', 'walk', 'walking', 'jog', 'jogging',
    },
    // Meetings / work
    {
      'meeting', 'call', 'conference', 'sync', 'standup', 'interview',
      'review', 'presentation', 'demo', 'work', 'office', 'client',
    },
    // Celebration / birthday
    {
      'birthday', 'bday', 'anniversary', 'celebrate', 'celebration', 'party',
      'bash', 'gathering',
    },
    // Travel
    {
      'travel', 'trip', 'flight', 'hotel', 'vacation', 'holiday', 'journey',
      'airbnb', 'airport',
    },
    // Medical / health
    {
      'doctor', 'appointment', 'medical', 'dentist', 'hospital', 'clinic',
      'health', 'checkup', 'therapy', 'physio',
    },
    // Family / kids
    {
      'family', 'kids', 'children', 'school', 'pickup', 'dropoff',
      'parent', 'son', 'daughter',
    },
    // Shopping
    {
      'shop', 'shopping', 'store', 'mall', 'buy', 'purchase', 'errands',
      'market',
    },
    // Entertainment / media
    {
      'anime', 'manga', 'cartoon', 'animation', 'animated', 'series',
      'episode', 'watch', 'stream', 'streaming',
    },
    {
      'movie', 'film', 'cinema', 'theater', 'theatre', 'screening',
    },
    {
      'music', 'concert', 'gig', 'band', 'album', 'song', 'playlist',
      'listen', 'festival', 'performance',
    },
    {
      'game', 'gaming', 'videogame', 'esport', 'play', 'playstation',
      'xbox', 'nintendo', 'steam',
    },
    // Leisure / hobbies
    {
      'book', 'reading', 'novel', 'library', 'read', 'chapter', 'fiction',
      'nonfiction', 'ebook',
    },
    {
      'hobby', 'craft', 'art', 'painting', 'drawing', 'knitting',
      'gardening', 'photography', 'photo', 'diy',
    },
    {
      'sleep', 'rest', 'nap', 'relax', 'meditation', 'spa', 'massage',
    },
    // Finance / admin
    {
      'finance', 'money', 'bank', 'budget', 'payment', 'bill', 'invoice',
      'salary', 'tax', 'invest', 'savings',
    },
    // Chores
    {
      'clean', 'cleaning', 'chores', 'laundry', 'tidy', 'dishes',
      'housework', 'vacuum', 'sweep',
    },
    // School / work projects
    {
      'project', 'deadline', 'submit', 'assignment', 'homework', 'report',
      'essay', 'thesis',
    },
    {
      'study', 'studying', 'learn', 'learning', 'course', 'class',
      'lecture', 'tutorial',
    },
  ];

  static Set<String> _expandWithSynonyms(Set<String> keywords) {
    final expanded = Set<String>.from(keywords);
    for (final kw in List<String>.from(keywords)) {
      for (final group in _kSynonymGroups) {
        if (group.contains(kw)) {
          expanded.addAll(group);
          break;
        }
      }
    }
    return expanded;
  }

  List<ScheduledEvent> _keywordMatch(
    List<ScheduledEvent> candidates,
    String rule,
  ) {
    final baseKeywords = rule
        .toLowerCase()
        .split(RegExp(r'[^a-z0-9]+'))
        .where((w) => w.length >= 3 && !_stopWords.contains(w))
        .toSet();
    final keywords = _expandWithSynonyms(baseKeywords);
    if (keywords.isEmpty) return [];

    final scored = <MapEntry<ScheduledEvent, int>>[];
    for (final event in candidates) {
      // Derive day-of-week name so "saturday" / "saturdays" both match.
      final pd = event.parsedDate;
      final dayName = pd?.absoluteDate != null
          ? const [
              'Monday', 'Tuesday', 'Wednesday', 'Thursday',
              'Friday', 'Saturday', 'Sunday',
            ][pd!.absoluteDate!.weekday - 1]
          : null;

      final haystack = [
        event.title,
        if (event.subtitle != null && event.subtitle!.isNotEmpty)
          event.subtitle!,
        if (event.destination != null && event.destination!.isNotEmpty)
          event.destination!,
        if (event.location != null && event.location!.isNotEmpty)
          event.location!,
        if (event.notes != null && event.notes!.isNotEmpty) event.notes!,
        // Date/time context — enables keyword rules like "aug 26", "saturday",
        // "saturdays", "sunday morning", "afternoon". Include both singular and
        // plural day name so e.g. "saturdays" hits the haystack substring.
        if (event.date != null && event.date!.isNotEmpty) event.date!,
        if (dayName != null) ...[dayName, '${dayName}s'],
        if (event.time != null && event.time!.isNotEmpty) event.time!,
        if (_timeOfDayLabel(event.time) case final tod?) tod,
      ].join(' ').toLowerCase();
      var score = 0;
      for (final kw in keywords) {
        if (haystack.contains(kw)) score++;
      }
      if (score > 0) scored.add(MapEntry(event, score));
    }

    scored.sort((a, b) => b.value.compareTo(a.value));
    return scored.map((e) => e.key).toList();
  }

  // ── Math ─────────────────────────────────────────────────────────────────

  static double _dot(List<double> a, List<double> b) {
    var s = 0.0;
    final len = a.length < b.length ? a.length : b.length;
    for (var i = 0; i < len; i++) s += a[i] * b[i];
    return s;
  }

  static double _norm(List<double> v) {
    var s = 0.0;
    for (final x in v) s += x * x;
    return sqrt(s);
  }

  static bool _isZero(List<double> v) => v.every((x) => x == 0.0);
}

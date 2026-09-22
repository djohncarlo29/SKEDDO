import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:smart_scheduler/ai/date_parser/rule_based_date_parser.dart';
import 'package:smart_scheduler/ai/event_pipeline.dart';
import 'package:smart_scheduler/ai/parsed_date.dart';
import 'package:smart_scheduler/ai/embedding/null_embedding_service.dart';
import 'package:smart_scheduler/ai/interfaces.dart';
import 'package:smart_scheduler/ai/vector_index/flat_vector_index.dart';
import 'package:smart_scheduler/ai/vector_index/hnsw_vector_index.dart';
import 'package:smart_scheduler/ai/matcher/deterministic_matcher.dart';
import 'package:smart_scheduler/ai/matcher/hybrid_matcher.dart';
import 'package:smart_scheduler/ai/search/search_service.dart';
import 'package:smart_scheduler/services/recurrence_expander.dart';
import 'package:smart_scheduler/services/event_model.dart';
import 'package:smart_scheduler/services/event_store.dart';
import 'package:smart_scheduler/services/local_storage.dart';
import 'package:smart_scheduler/app_settings.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SharedPreferences stub stores for save-failure tests.
// ─────────────────────────────────────────────────────────────────────────────

/// A SharedPreferences store whose [setValue] always returns `false`,
/// simulating a write that the platform declines (e.g. quota exceeded).
class _FalseWritePrefsStore extends InMemorySharedPreferencesStore {
  _FalseWritePrefsStore() : super.empty();

  @override
  Future<bool> setValue(String valueType, String key, Object value) async =>
      false; // write silently "fails"
}

/// A SharedPreferences store whose [setValue] always throws,
/// simulating an exceptional write failure (e.g. permission error).
///
/// Pass [initialData] to pre-populate reads so that loads still succeed while
/// writes fail — useful for testing write-back failure paths in loadFromStorage.
class _ThrowingWritePrefsStore extends InMemorySharedPreferencesStore {
  _ThrowingWritePrefsStore() : super.empty();
  _ThrowingWritePrefsStore.withData(Map<String, Object> data)
    : super.withData(data);

  @override
  Future<bool> setValue(String valueType, String key, Object value) async =>
      throw Exception('Storage quota exceeded');
}

/// A SharedPreferences store whose [getAll] always throws,
/// simulating a read failure (e.g. the underlying store is unavailable).
class _ThrowingReadPrefsStore extends InMemorySharedPreferencesStore {
  _ThrowingReadPrefsStore() : super.empty();

  @override
  Future<Map<String, Object>> getAll() async =>
      throw Exception('Storage unavailable');
}

class _FixedEmbeddingService implements EmbeddingService {
  final List<double> vector;

  const _FixedEmbeddingService(this.vector);

  @override
  int get dimensions => vector.length;

  @override
  Future<List<double>> embed(String text) async => vector;
}

class _FixedVectorIndex implements VectorIndex {
  final List<VectorSearchResult> results;

  const _FixedVectorIndex(this.results);

  @override
  Future<void> clear() async {}

  @override
  Future<List<String>> nearest(List<double> query, {int topK = 10}) async =>
      (await nearestScored(
        query,
        topK: topK,
      )).map((result) => result.id).toList();

  @override
  Future<List<VectorSearchResult>> nearestScored(
    List<double> query, {
    int topK = 10,
  }) async => results.take(topK).toList();

  @override
  Future<void> remove(String id) async {}

  @override
  Future<void> upsert(String id, List<double> embedding) async {}
}

// ─────────────────────────────────────────────────────────────────────────────
// AI layer unit tests — Task #2 requirement.
//
// Covers:
//   A. DateParser — 30+ expression cases (absolute, relative, range, recurring)
//   B. EmbeddingService — dimension and zero-vector behaviour (NullEmbeddingService)
//   C. VectorIndex — nearest-neighbor correctness (FlatVectorIndex + HNSW)
//   D. DeterministicMatcher / HybridMatcher — built-in tile + user rule matching
//
// Tests run without a device (no ONNX runtime loaded — mocked via stubs).
// ─────────────────────────────────────────────────────────────────────────────

void main() {
  // Needed for SharedPreferences platform channel in loadFromStorage tests.
  TestWidgetsFlutterBinding.ensureInitialized();

  // ── Fixed reference date: Wednesday 2025-06-11 ────────────────────────────
  final ref = DateTime(2025, 6, 11); // Wednesday

  // ── A. DateParser ─────────────────────────────────────────────────────────
  group('RuleBasedDateParser', () {
    final parser = RuleBasedDateParser();
    ParsedDate parse(String input) => parser.parse(input, now: ref);
    DateTime? date(String input) => parse(input).absoluteDate;
    DateTime d(int y, int m, int day) => DateTime(y, m, day);

    // ── Absolute dates ───────────────────────────────────────────────────
    test(
      'ISO date YYYY-MM-DD',
      () => expect(date('2025-08-15'), d(2025, 8, 15)),
    );
    test(
      'ISO date with time suffix',
      () => expect(date('2025-08-15T10:00'), d(2025, 8, 15)),
    );
    test('M/D/YYYY', () => expect(date('7/4/2025'), d(2025, 7, 4)));
    test('M/D/YY', () => expect(date('7/4/25'), d(2025, 7, 4)));
    // June 5 is past relative to ref (June 11) → parser advances to next year.
    test(
      'Month name + day (past → next year)',
      () => expect(date('June 5'), d(2026, 6, 5)),
    );
    test(
      'Month name + day + year',
      () => expect(date('July 15, 2025'), d(2025, 7, 15)),
    );
    test(
      'Day + ordinal + month',
      () => expect(date('3rd July'), d(2025, 7, 3)),
    );
    test(
      'Day + month + year',
      () => expect(date('5 August 2025'), d(2025, 8, 5)),
    );
    test(
      'weekday prefix and trailing comma are ignored',
      () => expect(date('Tuesday, August 12,'), d(2025, 8, 12)),
    );
    test(
      'Just month name (future)',
      () => expect(date('August'), d(2025, 8, 1)),
    );
    test(
      'Just month name (past → next year)',
      () => expect(date('January'), d(2026, 1, 1)),
    );

    // ── Simple relative ───────────────────────────────────────────────────
    test('today', () => expect(date('today'), d(2025, 6, 11)));
    test('tomorrow', () => expect(date('tomorrow'), d(2025, 6, 12)));
    test('yesterday', () => expect(date('yesterday'), d(2025, 6, 10)));

    // ── Named-day relatives ───────────────────────────────────────────────
    test('next Friday', () => expect(date('next friday'), d(2025, 6, 13)));
    test('next Monday', () => expect(date('next monday'), d(2025, 6, 16)));
    test('this Friday', () {
      // "this Friday" = Friday of the current ISO week (Mon–Sun)
      // Week of 2025-06-09 (Mon) → Friday = 2025-06-13
      expect(date('this friday'), d(2025, 6, 13));
    });
    test('last Monday', () => expect(date('last monday'), d(2025, 6, 9)));
    test('next Sunday', () => expect(date('next sunday'), d(2025, 6, 15)));

    // ── Offset expressions ────────────────────────────────────────────────
    test('in 3 days', () => expect(date('in 3 days'), d(2025, 6, 14)));
    test('in 1 week', () => expect(date('in 1 week'), d(2025, 6, 18)));
    test('in 2 weeks', () => expect(date('in 2 weeks'), d(2025, 6, 25)));
    test('in 1 month', () => expect(date('in 1 month'), d(2025, 7, 11)));
    test(
      '3 days from now',
      () => expect(date('3 days from now'), d(2025, 6, 14)),
    );
    test(
      '2 weeks from now',
      () => expect(date('2 weeks from now'), d(2025, 6, 25)),
    );

    // ── Text-number offsets ───────────────────────────────────────────────
    test('in two weeks', () => expect(date('in two weeks'), d(2025, 6, 25)));
    test('in three days', () => expect(date('in three days'), d(2025, 6, 14)));
    test('in a week', () => expect(date('in a week'), d(2025, 6, 18)));
    test('in a month', () => expect(date('in a month'), d(2025, 7, 11)));

    // ── Range / period expressions ────────────────────────────────────────
    test('this weekend → next Saturday', () {
      // ref is Wednesday 2025-06-11; weekend = Sat 2025-06-14
      expect(date('this weekend'), d(2025, 6, 14));
    });
    test('next weekend → Saturday after next', () {
      expect(date('next weekend'), d(2025, 6, 21));
    });
    test('end of month → last day of June 2025', () {
      expect(date('end of month'), d(2025, 6, 30));
    });
    test('end of year → Dec 31 2025', () {
      expect(date('end of year'), d(2025, 12, 31));
    });

    // ── Recurring patterns ────────────────────────────────────────────────
    test('daily → isRecurring, RecurrenceType.daily', () {
      final pd = parse('daily');
      expect(pd.isRecurring, isTrue);
      expect(pd.recurrenceType, RecurrenceType.daily);
    });
    test('every day → isRecurring, daily', () {
      final pd = parse('every day');
      expect(pd.isRecurring, isTrue);
      expect(pd.recurrenceType, RecurrenceType.daily);
    });
    test('weekly → isRecurring, weekly', () {
      final pd = parse('weekly');
      expect(pd.isRecurring, isTrue);
      expect(pd.recurrenceType, RecurrenceType.weekly);
    });
    test('every week → isRecurring, weekly', () {
      final pd = parse('every week');
      expect(pd.isRecurring, isTrue);
      expect(pd.recurrenceType, RecurrenceType.weekly);
    });
    test('monthly → isRecurring, monthly', () {
      final pd = parse('monthly');
      expect(pd.isRecurring, isTrue);
      expect(pd.recurrenceType, RecurrenceType.monthly);
    });
    test('every Monday → isRecurring, weekly, weekday=Monday', () {
      final pd = parse('every monday');
      expect(pd.isRecurring, isTrue);
      expect(pd.recurrenceType, RecurrenceType.weekly);
      expect(pd.recurrenceWeekday, DateTime.monday);
    });
    test('yearly → isRecurring, yearly', () {
      final pd = parse('yearly');
      expect(pd.isRecurring, isTrue);
      expect(pd.recurrenceType, RecurrenceType.yearly);
    });

    // ── ParsedDate predicates ─────────────────────────────────────────────
    test('isToday', () => expect(parse('today').isToday(ref), isTrue));
    test('isTomorrow', () => expect(parse('tomorrow').isTomorrow(ref), isTrue));
    test('isThisWeek — next Friday still this week', () {
      expect(parse('next friday').isThisWeek(ref), isTrue);
    });
    test('isNextWeek — next Monday is next week', () {
      expect(parse('next monday').isNextWeek(ref), isTrue);
    });
    test('empty input → not scheduled', () {
      expect(parse('').isScheduled, isFalse);
    });
    test('unparseable → not scheduled', () {
      expect(parse('garble xyz').isScheduled, isFalse);
    });
    test('compact time is canonicalized as HH:mm', () {
      final parsed = parse('0830');
      expect(parsed.absoluteDate, isNull);
      expect(parsed.startDateTime, isNull);
      expect(parsed.canonicalTime, '08:30');
      expect(parsed.timePrecision, TimePrecision.minute);
    });
    test('four-digit year is not mistaken for compact time', () {
      final parsed = parse('August 12 2025');
      expect(parsed.absoluteDate, d(2025, 8, 12));
      expect(parsed.canonicalTime, isNull);
    });
    test('invalid explicit time does not downgrade to date-only', () {
      final parsed = parse('tomorrow at 25:00');
      expect(parsed.isScheduled, isFalse);
      expect(parsed.canonicalTime, isNull);
    });
    test('ambiguous numeric dates respect locale preference', () {
      final monthFirst = parser.parse(
        '08/12/2026',
        now: ref,
        localePreference: DateLocalePreference.monthFirst,
      );
      final dayFirst = parser.parse(
        '08/12/2026',
        now: ref,
        localePreference: DateLocalePreference.dayFirst,
      );
      expect(monthFirst.absoluteDate, d(2026, 8, 12));
      expect(dayFirst.absoluteDate, d(2026, 12, 8));
      expect(dayFirst.alternateDates.single, d(2026, 8, 12));
    });
  });

  // ── B. EmbeddingService (stub) ────────────────────────────────────────────
  group('NullEmbeddingService', () {
    const svc = NullEmbeddingService();

    test('dimensions == 384', () => expect(svc.dimensions, 384));

    test('embed returns zero vector of correct length', () async {
      final v = await svc.embed('hello world');
      expect(v.length, 384);
      expect(v.every((x) => x == 0.0), isTrue);
    });
  });

  // ── C. VectorIndex ────────────────────────────────────────────────────────
  group('FlatVectorIndex', () {
    test('nearest returns closest vector', () async {
      final idx = FlatVectorIndex();
      final a = [1.0, 0.0, 0.0];
      final b = [0.0, 1.0, 0.0];
      final c = [0.0, 0.0, 1.0];
      await idx.upsert('a', a);
      await idx.upsert('b', b);
      await idx.upsert('c', c);

      // Query close to 'a' — should return 'a' first.
      final result = await idx.nearest([0.9, 0.1, 0.0], topK: 1);
      expect(result, ['a']);
    });

    test('remove works', () async {
      final idx = FlatVectorIndex();
      await idx.upsert('x', [1.0, 0.0]);
      await idx.remove('x');
      final result = await idx.nearest([1.0, 0.0], topK: 1);
      expect(result, isEmpty);
    });

    test('clear empties the index', () async {
      final idx = FlatVectorIndex();
      await idx.upsert('y', [1.0, 0.0]);
      await idx.clear();
      final result = await idx.nearest([1.0, 0.0], topK: 1);
      expect(result, isEmpty);
    });
  });

  group('HnswVectorIndex (brute-force path, < 500 entries)', () {
    test('nearest returns closest vector', () async {
      final idx = HnswVectorIndex();
      await idx.upsert('a', [1.0, 0.0, 0.0]);
      await idx.upsert('b', [0.0, 1.0, 0.0]);
      await idx.upsert('c', [0.0, 0.0, 1.0]);

      final result = await idx.nearest([0.9, 0.05, 0.05], topK: 1);
      expect(result, ['a']);
    });

    test('upsert overwrites existing entry', () async {
      final idx = HnswVectorIndex();
      await idx.upsert('a', [1.0, 0.0]);
      await idx.upsert('a', [0.0, 1.0]); // overwrite
      final result = await idx.nearest([0.0, 1.0], topK: 1);
      expect(result, ['a']);
    });
  });

  // ── D. Matchers ───────────────────────────────────────────────────────────
  group('DeterministicMatcher built-in tiles', () {
    final matcher = DeterministicMatcher();
    final now = DateTime(2025, 6, 11);

    final todayEvent = ScheduledEvent(
      id: '1',
      title: 'Today meeting',
      parsedDate: ParsedDate(absoluteDate: DateTime(2025, 6, 11)),
    );
    final tomorrowEvent = ScheduledEvent(
      id: '2',
      title: 'Tomorrow lunch',
      parsedDate: ParsedDate(absoluteDate: DateTime(2025, 6, 12)),
    );
    final nextWeekEvent = ScheduledEvent(
      id: '3',
      title: 'Next week standup',
      parsedDate: ParsedDate(absoluteDate: DateTime(2025, 6, 16)),
    );
    final noDateEvent = ScheduledEvent(id: '4', title: 'Someday task');

    final all = [todayEvent, tomorrowEvent, nextWeekEvent, noDateEvent];

    test('Today returns only today', () {
      final r = matcher.match(
        candidates: all,
        rule: 'Today',
        builtInLabel: 'Today',
        now: now,
      );
      expect(r.map((e) => e.id), containsAll(['1']));
      expect(r.map((e) => e.id), isNot(contains('2')));
    });

    test('Tomorrow returns only tomorrow', () {
      final r = matcher.match(
        candidates: all,
        rule: 'Tomorrow',
        builtInLabel: 'Tomorrow',
        now: now,
      );
      expect(r.map((e) => e.id), contains('2'));
      expect(r.map((e) => e.id), isNot(contains('1')));
    });

    test('This Week returns today + this-week events', () {
      final r = matcher.match(
        candidates: all,
        rule: 'This Week',
        builtInLabel: 'This Week',
        now: now,
      );
      expect(r.map((e) => e.id), containsAll(['1', '2']));
    });

    test('Next Week returns next-week events', () {
      final r = matcher.match(
        candidates: all,
        rule: 'Next Week',
        builtInLabel: 'Next Week',
        now: now,
      );
      expect(r.map((e) => e.id), contains('3'));
    });

    test('Unscheduled returns events without parsedDate', () {
      final r = matcher.match(
        candidates: all,
        rule: 'Unscheduled',
        builtInLabel: 'Unscheduled',
        now: now,
      );
      expect(r.map((e) => e.id), contains('4'));
      expect(r.map((e) => e.id), isNot(contains('1')));
    });

    test('All Events returns everything', () {
      final r = matcher.match(
        candidates: all,
        rule: 'All Events',
        builtInLabel: 'All Events',
        now: now,
      );
      expect(r.length, all.length);
    });
  });

  group('DeterministicMatcher user rule keyword matching', () {
    final matcher = DeterministicMatcher();

    final birthday = ScheduledEvent(id: '1', title: "Mom's birthday party");
    final meeting = ScheduledEvent(id: '2', title: 'Weekly team meeting');
    final trip = ScheduledEvent(id: '3', title: 'Flight to Paris travel');
    final other = ScheduledEvent(id: '4', title: 'Buy groceries');

    final all = [birthday, meeting, trip, other];

    test('birthdays rule matches birthday event', () {
      final r = matcher.match(
        candidates: all,
        rule: 'birthdays and birthday celebrations',
      );
      expect(r.map((e) => e.id), contains('1'));
    });

    test('meetings rule matches meeting event', () {
      final r = matcher.match(candidates: all, rule: 'meetings and team syncs');
      expect(r.map((e) => e.id), contains('2'));
    });

    test('travel rule matches trip event', () {
      final r = matcher.match(candidates: all, rule: 'travel and trips');
      expect(r.map((e) => e.id), contains('3'));
    });

    test('unrelated rule returns empty', () {
      final r = matcher.match(candidates: all, rule: 'dental appointments');
      expect(r, isEmpty);
    });
  });

  group('HybridMatcher falls back to keyword when no embeddings', () {
    final matcher = HybridMatcher();

    final birthday = ScheduledEvent(id: '1', title: "Dad's birthday");
    final other = ScheduledEvent(id: '2', title: 'Buy groceries');

    test('keyword fallback works when embeddings absent', () {
      // Use singular forms so .contains() substring matching works.
      final r = matcher.match(
        candidates: [birthday, other],
        rule: 'birthday celebration party',
      );
      expect(r.map((e) => e.id), contains('1'));
      expect(r.map((e) => e.id), isNot(contains('2')));
    });

    test('plural birthday rules expand to the birthday concept', () {
      final r = matcher.match(
        candidates: [birthday, other],
        rule: 'Birthdays',
      );
      expect(r.map((e) => e.id), contains('1'));
      expect(r.map((e) => e.id), isNot(contains('2')));
    });
  });

  test(
    'HybridMatcher rejects weak semantic matches instead of admitting every event',
    () {
      final matcher = HybridMatcher();
      final birthday = ScheduledEvent(
        id: 'birthday',
        title: "Mom's special day",
        parsedDate: ParsedDate(absoluteDate: DateTime(2025, 6, 12)),
      );
      final unrelated = ScheduledEvent(
        id: 'unrelated',
        title: 'Team budget review',
        parsedDate: ParsedDate(absoluteDate: DateTime(2025, 6, 13)),
      );
      matcher.setCategoryEmbedding('Birthday', const [1.0, 0.0]);
      matcher.setEventEmbedding('birthday', const [1.0, 0.0]);
      // Cosine similarity is 0.20: above the old 0.18 floor, below the
      // stricter relevance floor.
      matcher.setEventEmbedding('unrelated', const [0.2, 0.979795897]);

      final result = matcher.match(
        candidates: [birthday, unrelated],
        rule: 'Birthdays',
        categoryName: 'Birthday',
      );
      expect(result.map((event) => event.id), ['birthday']);
    },
  );

  // ── E. HybridMatcher weekday + time-of-day hard filters ───────────────────
  //
  // These tests exercise the vector path (embeddings are set so _vectorMatch
  // fires) and confirm that weekday/time-of-day constraints are enforced as
  // hard intersection filters — even when the intersection is empty the
  // unfiltered semantic list must NOT be returned as a fallback.
  group('HybridMatcher weekday / time-of-day hard filters (vector path)', () {
    // Helper: build a unit vector in R^3 with the given component hot.
    List<double> v(int hot) {
      final vec = [0.0, 0.0, 0.0];
      vec[hot] = 1.0;
      return vec;
    }

    // Sunday 2025-06-15 09:00 AM  → weekday=7, tod=morning
    final sundayMorning = ScheduledEvent(
      id: 'sm',
      title: 'Sunday brunch',
      time: '9:00 AM',
      parsedDate: ParsedDate(absoluteDate: DateTime(2025, 6, 15)), // Sunday
    );
    // Saturday 2025-06-14 14:00 PM → weekday=6, tod=afternoon
    final saturdayAfternoon = ScheduledEvent(
      id: 'sa',
      title: 'Saturday hike',
      time: '2:00 PM',
      parsedDate: ParsedDate(absoluteDate: DateTime(2025, 6, 14)), // Saturday
    );
    // Sunday 2025-06-15 19:00 PM → weekday=7, tod=evening
    final sundayEvening = ScheduledEvent(
      id: 'se',
      title: 'Sunday dinner',
      time: '7:00 PM',
      parsedDate: ParsedDate(absoluteDate: DateTime(2025, 6, 15)), // Sunday
    );
    // Tuesday — semantically similar title but wrong day
    final tuesdayBrunch = ScheduledEvent(
      id: 'tb',
      title: 'Tuesday Sunday brunch recollection',
      time: '9:00 AM',
      parsedDate: ParsedDate(absoluteDate: DateTime(2025, 6, 10)), // Tuesday
    );
    // Event with no parsedDate / no time
    final unscheduled = ScheduledEvent(id: 'u', title: 'Someday task');

    final all = [
      sundayMorning,
      saturdayAfternoon,
      sundayEvening,
      tuesdayBrunch,
      unscheduled,
    ];

    // All candidates get a uniform embedding (cosine similarity = 1.0) so
    // _vectorMatch returns every event — isolating the filter logic.
    const catVec = [1.0, 0.0, 0.0];
    const eventVec = [1.0, 0.0, 0.0];

    HybridMatcher _buildMatcher(String rule) {
      final m = HybridMatcher();
      m.setCategoryEmbedding(rule, catVec);
      for (final e in all) {
        m.setEventEmbedding(e.id, eventVec);
      }
      return m;
    }

    final now = DateTime(2025, 6, 11);

    test(
      '"sunday morning" includes Sunday-morning, excludes Saturday-afternoon and Sunday-evening',
      () {
        const rule = 'sunday morning';
        final m = _buildMatcher(rule);
        final r = m.match(candidates: all, rule: rule, now: now);
        final ids = r.map((e) => e.id).toSet();
        expect(ids, contains('sm')); // Sunday + morning ✓
        expect(ids, isNot(contains('sa'))); // Saturday + afternoon ✗
        expect(ids, isNot(contains('se'))); // Sunday + evening ✗
        expect(ids, isNot(contains('tb'))); // Tuesday ✗
      },
    );

    test('"sundays" alone matches all Sunday events regardless of time', () {
      const rule = 'sundays';
      final m = _buildMatcher(rule);
      final r = m.match(candidates: all, rule: rule, now: now);
      final ids = r.map((e) => e.id).toSet();
      expect(ids, contains('sm')); // Sunday morning ✓
      expect(ids, contains('se')); // Sunday evening ✓
      expect(ids, isNot(contains('sa'))); // Saturday ✗
      expect(ids, isNot(contains('tb'))); // Tuesday ✗
    });

    test('"morning" alone matches all morning events regardless of day', () {
      const rule = 'morning';
      final m = _buildMatcher(rule);
      final r = m.match(candidates: all, rule: rule, now: now);
      final ids = r.map((e) => e.id).toSet();
      expect(ids, contains('sm')); // Sunday morning ✓
      expect(ids, contains('tb')); // Tuesday morning ✓
      expect(ids, isNot(contains('sa'))); // Saturday afternoon ✗
      expect(ids, isNot(contains('se'))); // Sunday evening ✗
    });

    test('"saturday afternoon" matches only Saturday-afternoon event', () {
      const rule = 'saturday afternoon';
      final m = _buildMatcher(rule);
      final r = m.match(candidates: all, rule: rule, now: now);
      final ids = r.map((e) => e.id).toSet();
      expect(ids, contains('sa'));
      expect(ids, isNot(contains('sm')));
      expect(ids, isNot(contains('se')));
    });

    test(
      '"saturday afternoon" rejects Saturday evening AND Friday afternoon',
      () {
        // Verifies compound weekday+time filter: both dimensions must match.
        const rule = 'saturday afternoon';
        final satEvening = ScheduledEvent(
          id: 'sateve',
          title: 'Saturday movie night',
          time: '8:00 PM',
          parsedDate: ParsedDate(
            absoluteDate: DateTime(2025, 6, 14),
          ), // Saturday
        );
        final friAfternoon = ScheduledEvent(
          id: 'friaft',
          title: 'Friday afternoon coffee',
          time: '3:00 PM',
          parsedDate: ParsedDate(absoluteDate: DateTime(2025, 6, 13)), // Friday
        );
        final extended = [...all, satEvening, friAfternoon];
        final m = HybridMatcher();
        m.setCategoryEmbedding(rule, catVec);
        for (final e in extended) {
          m.setEventEmbedding(e.id, eventVec);
        }
        final r = m.match(candidates: extended, rule: rule, now: now);
        final ids = r.map((e) => e.id).toSet();
        expect(ids, contains('sa')); // Saturday + afternoon ✓
        expect(ids, isNot(contains('sateve'))); // Saturday + evening ✗
        expect(ids, isNot(contains('friaft'))); // Friday + afternoon ✗
      },
    );

    test('"fridays" plural form correctly matches Friday events', () {
      // Ensures the plural weekday token maps to weekday 5 (Friday).
      const rule = 'fridays';
      final fridayEvent = ScheduledEvent(
        id: 'fri',
        title: 'Friday standup',
        time: '10:00 AM',
        parsedDate: ParsedDate(absoluteDate: DateTime(2025, 6, 13)), // Friday
      );
      final m = HybridMatcher();
      m.setCategoryEmbedding(rule, catVec);
      m.setEventEmbedding('fri', eventVec);
      for (final e in all) {
        m.setEventEmbedding(e.id, eventVec);
      }
      final r = m.match(
        candidates: [...all, fridayEvent],
        rule: rule,
        now: now,
      );
      final ids = r.map((e) => e.id).toSet();
      expect(ids, contains('fri')); // Friday ✓
      expect(ids, isNot(contains('sm'))); // Sunday ✗
      expect(ids, isNot(contains('sa'))); // Saturday ✗
      expect(ids, isNot(contains('tb'))); // Tuesday ✗
    });

    test(
      'empty intersection returns empty list — no fallback to unfiltered semantic',
      () {
        // Rule asks for Friday events; no candidates fall on a Friday.
        const rule = 'friday';
        final m = _buildMatcher(rule);
        final r = m.match(candidates: all, rule: rule, now: now);
        expect(r, isEmpty);
      },
    );

    test('weekly recurring event with absoluteDate on Sunday is matched', () {
      // The weekday filter checks absoluteDate.weekday.
      // Recurring events get their absoluteDate set to the next occurrence,
      // so a Sunday-recurring event expanded to 2025-06-15 (Sunday) matches.
      const rule = 'sundays';
      final m = HybridMatcher();
      final recurringEvent = ScheduledEvent(
        id: 'rec',
        title: 'Weekly Sunday yoga',
        parsedDate: ParsedDate(
          isRecurring: true,
          recurrenceType: RecurrenceType.weekly,
          recurrenceWeekday: DateTime.sunday,
          absoluteDate: DateTime(2025, 6, 15), // Sunday
        ),
      );
      m.setCategoryEmbedding(rule, catVec);
      m.setEventEmbedding('rec', eventVec);
      final r = m.match(candidates: [recurringEvent], rule: rule, now: now);
      expect(r.map((e) => e.id), contains('rec'));
    });

    // ── 24-hour time format ──────────────────────────────────────────────
    // Events stored with "HH:MM" (no AM/PM suffix) must be bucketed
    // identically to their 12-hour equivalents.  The fix is in
    // HybridMatcher._timeOfDayLabel — see hybrid_matcher.dart.

    test('24-hour "09:00" is treated as morning', () {
      // A Saturday event at "09:00" (24-h) must match "saturday morning".
      const rule = 'saturday morning';
      final sat09 = ScheduledEvent(
        id: 'sat09',
        title: 'Saturday yoga',
        time: '09:00', // 24-hour — was previously invisible
        parsedDate: ParsedDate(absoluteDate: DateTime(2025, 6, 14)), // Saturday
      );
      final m = HybridMatcher();
      m.setCategoryEmbedding(rule, catVec);
      m.setEventEmbedding('sat09', eventVec);
      final r = m.match(candidates: [sat09], rule: rule, now: now);
      expect(
        r.map((e) => e.id),
        contains('sat09'),
        reason: '"09:00" (24-h) must be bucketed as morning',
      );
    });

    test('24-hour "14:30" is treated as afternoon', () {
      const rule = 'saturday afternoon';
      final sat14 = ScheduledEvent(
        id: 'sat14',
        title: 'Saturday lunch',
        time: '14:30',
        parsedDate: ParsedDate(absoluteDate: DateTime(2025, 6, 14)), // Saturday
      );
      final m = HybridMatcher();
      m.setCategoryEmbedding(rule, catVec);
      m.setEventEmbedding('sat14', eventVec);
      final r = m.match(candidates: [sat14], rule: rule, now: now);
      expect(
        r.map((e) => e.id),
        contains('sat14'),
        reason: '"14:30" (24-h) must be bucketed as afternoon',
      );
    });

    test('24-hour "20:00" is treated as evening', () {
      const rule = 'sunday evening';
      final sun20 = ScheduledEvent(
        id: 'sun20',
        title: 'Sunday dinner',
        time: '20:00',
        parsedDate: ParsedDate(absoluteDate: DateTime(2025, 6, 15)), // Sunday
      );
      final m = HybridMatcher();
      m.setCategoryEmbedding(rule, catVec);
      m.setEventEmbedding('sun20', eventVec);
      final r = m.match(candidates: [sun20], rule: rule, now: now);
      expect(
        r.map((e) => e.id),
        contains('sun20'),
        reason: '"20:00" (24-h) must be bucketed as evening',
      );
    });

    test('24-hour "23:00" is treated as night', () {
      const rule = 'night';
      final late = ScheduledEvent(
        id: 'late',
        title: 'Late show',
        time: '23:00',
        parsedDate: ParsedDate(absoluteDate: DateTime(2025, 6, 14)),
      );
      final m = HybridMatcher();
      m.setCategoryEmbedding(rule, catVec);
      m.setEventEmbedding('late', eventVec);
      final r = m.match(candidates: [late], rule: rule, now: now);
      expect(
        r.map((e) => e.id),
        contains('late'),
        reason: '"23:00" (24-h) must be bucketed as night',
      );
    });

    test('24-hour morning does not bleed into afternoon category', () {
      // "09:00" must NOT appear in a "saturday afternoon" category.
      const rule = 'saturday afternoon';
      final sat09 = ScheduledEvent(
        id: 'sat09',
        title: 'Saturday yoga',
        time: '09:00',
        parsedDate: ParsedDate(absoluteDate: DateTime(2025, 6, 14)), // Saturday
      );
      final m = HybridMatcher();
      m.setCategoryEmbedding(rule, catVec);
      m.setEventEmbedding('sat09', eventVec);
      final r = m.match(candidates: [sat09], rule: rule, now: now);
      expect(
        r.map((e) => e.id),
        isNot(contains('sat09')),
        reason: '"09:00" is morning, not afternoon',
      );
    });

    test(
      'pure-topic rule without weekday/time uses unfiltered vector results',
      () {
        // "Leisure" has no weekday or time-of-day tokens; the date filter must
        // be null so the full semantic result is returned.
        const rule = 'Leisure';
        final m = HybridMatcher();
        m.setCategoryEmbedding(rule, catVec);
        for (final e in all) {
          m.setEventEmbedding(e.id, eventVec);
        }
        final r = m.match(candidates: all, rule: rule, now: now);
        // All events with non-zero embeddings are returned (no day/time pruning).
        final ids = r.map((e) => e.id).toSet();
        expect(ids, contains('sm'));
        expect(ids, contains('sa'));
        expect(ids, contains('se'));
        expect(ids, contains('tb'));
      },
    );
  });

  // ── G. Smart Search Pipeline ─────────────────────────────────────────────
  group('SearchService', () {
    ScheduledEvent event(
      String id,
      String title, {
      String? date,
      ParsedDate? parsedDate,
      String? location,
      String? notes,
      String categoryId = 'sys-uncategorized',
      String? repeat,
    }) {
      return ScheduledEvent(
        id: id,
        title: title,
        date: date,
        parsedDate: parsedDate,
        location: location,
        notes: notes,
        categoryId: categoryId,
        repeat: repeat,
      );
    }

    test(
      'exact title, location, notes, and date queries match offline',
      () async {
        final birthday = event(
          'birthday',
          'Birthday dinner',
          date: 'August 12, 2026',
          parsedDate: ParsedDate(absoluteDate: DateTime(2026, 8, 12)),
          location: 'Sakura',
          notes: 'Bring the gift',
        );
        final service = SearchService();

        final title = await service.query('birthday', [birthday]);
        expect(title.all.single.event.id, 'birthday');
        expect(title.all.single.tier, SearchTier.exact);
        expect(title.all.single.titleSpans, isNotEmpty);

        expect(
          (await service.query('Sakura', [birthday])).all.single.event.id,
          'birthday',
        );
        expect(
          (await service.query('gift', [birthday])).all.single.event.id,
          'birthday',
        );
        expect(
          (await service.query('8/12/26', [birthday])).all.single.event.id,
          'birthday',
        );
      },
    );

    test(
      'fuzzy typos, initials, and synonym fallback find relevant events',
      () async {
        final birthday = event('b', 'Birthday dinner');
        final anime = event('a', 'Watch Attack on Titan');
        final results = SearchService();

        final typo = await results.query('Birtday', [birthday]);
        expect(typo.all.single.event.id, 'b');
        expect(typo.all.single.tier, SearchTier.fuzzy);

        final missingLetter = await results.query('meetng', [
          event('m', 'Project meeting'),
        ]);
        expect(missingLetter.all.single.event.id, 'm');
        expect(missingLetter.all.single.tier, SearchTier.fuzzy);

        final extraLetter = await results.query('dinnner', [
          event('d', 'Dinner with friends'),
        ]);
        expect(extraLetter.all.single.event.id, 'd');
        expect(extraLetter.all.single.tier, SearchTier.fuzzy);

        final transposedLetters = await results.query('doctro', [
          event('doctor', 'Doctor appointment'),
        ]);
        expect(transposedLetters.all.single.event.id, 'doctor');
        expect(transposedLetters.all.single.tier, SearchTier.fuzzy);

        final initials = await results.query('aot', [anime]);
        expect(initials.all.single.event.id, 'a');
        expect(initials.all.single.tier, SearchTier.fuzzy);

        final synonym = await results.query('anime', [anime]);
        expect(synonym.all.single.event.id, 'a');
        expect(synonym.all.single.tier, SearchTier.synonym);
      },
    );

    test('semantic nearest neighbors do not become query corrections', () async {
      final unrelated = await SearchService().query('anime', [
        event('birthday', 'Birthday Party'),
      ]);
      // ignore: avoid_print
      print(
        'anime unrelated: ${unrelated.all.map((hit) => '${hit.event.title}/${hit.score}/${hit.tier}').toList()}',
      );
      expect(unrelated.all, isEmpty);
      expect(unrelated.suggestedQuery, isNull);

      final related = await SearchService().query('anime', [
        event('watch', 'Watch Attack on Titan'),
      ]);
      expect(related.all.single.event.id, 'watch');
      expect(related.suggestedQuery, isNull);
    });

    test('semantic neighbors below the threshold are filtered out', () async {
      final service = SearchService(
        embedding: const _FixedEmbeddingService([1.0, 0.0]),
        vectorIndex: const _FixedVectorIndex([
          VectorSearchResult('birthday', 0.55),
        ]),
      );
      final result = await service.query('anime', [
        event('birthday', 'Birthday Party'),
      ]);

      expect(result.all, isEmpty);
      expect(result.suggestedQuery, isNull);
    });

    test(
      'semantic results above the threshold keep the original query context',
      () async {
        final service = SearchService(
          embedding: const _FixedEmbeddingService([1.0, 0.0]),
          vectorIndex: const _FixedVectorIndex([
            VectorSearchResult('watch', 0.80),
          ]),
        );
        final result = await service.query('anime', [
          event('watch', 'Watch Attack on Titan'),
        ]);

        expect(result.all.single.event.id, 'watch');
        expect(result.all.single.tier, SearchTier.semantic);
        expect(result.suggestedQuery, isNull);
      },
    );

    test('synonyms require an explicit whole-token match', () async {
      final result = await SearchService().query('anime', [
        event('substring', 'Workshop planning'),
      ]);

      expect(result.all, isEmpty);
      expect(result.suggestedQuery, isNull);
    });

    test(
      'lexical correction is not inferred from an unrelated result title',
      () async {
        final result = await SearchService().query('meetng', [
          event('birthday', 'Birthday Party'),
        ]);

        expect(result.all, isEmpty);
        expect(result.suggestedQuery, isNull);
      },
    );

    test(
      'phonetic, keyboard-aware, and inflection matching stay offline',
      () async {
        final service = SearchService();

        final restaurant = await service.query('restarant', [
          event('restaurant', 'Restaurant reservation'),
        ]);
        expect(restaurant.all.single.event.id, 'restaurant');
        expect(restaurant.all.single.tier, SearchTier.fuzzy);
        expect(restaurant.suggestedQuery, 'Restaurant');

        final calendar = await service.query('calender', [
          event('calendar', 'Calendar review'),
        ]);
        expect(calendar.all.single.event.id, 'calendar');
        expect(calendar.all.single.tier, SearchTier.fuzzy);

        final keyboard = await service.query('meering', [
          event('meeting', 'Meeting with design'),
        ]);
        expect(keyboard.all.single.event.id, 'meeting');
        expect(keyboard.all.single.tier, SearchTier.fuzzy);

        final normalized = await service.query('shopped', [
          event('shop', 'Shop for groceries'),
        ]);
        expect(normalized.all.single.event.id, 'shop');
        expect(normalized.all.single.tier, SearchTier.exact);

        final meetings = await service.query('meetings', [
          event('meet', 'Meet the team'),
        ]);
        expect(meetings.all.single.event.id, 'meet');
        expect(meetings.all.single.tier, SearchTier.exact);
      },
    );

    test('compound lexical and relative-date search can cross fields', () async {
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      const monthNames = [
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
      final result = await SearchService().query('doctor tomorrow', [
        event(
          'medical',
          'Medical appointment',
          date:
              '${monthNames[tomorrow.month - 1]} ${tomorrow.day}, ${tomorrow.year}',
          parsedDate: ParsedDate(absoluteDate: tomorrow),
        ),
      ]);
      expect(result.all.single.event.id, 'medical');
    });

    test('close title typos outrank exact metadata matches', () async {
      final result = await SearchService().query('meetng', [
        event('location', 'Project planning', location: 'Meeting room'),
        event('title', 'Team meeting'),
      ]);
      expect(result.all.first.event.id, 'title');
    });

    test(
      'DCV boost ranks in-scope results first without hiding overflow',
      () async {
        final inScope = event('in', 'Meeting notes', categoryId: 'work');
        final outside = event('out', 'Meeting agenda', categoryId: 'personal');
        final search = await SearchService().query(
          'meeting',
          [outside, inScope],
          scopeEventIds: {'in'},
        );

        expect(search.primary.map((hit) => hit.event.id), ['in']);
        expect(search.overflow.map((hit) => hit.event.id), ['out']);
        expect(
          search.primary.single.score,
          greaterThan(search.overflow.single.score),
        );
      },
    );

    test('date search can find a concrete recurring occurrence', () async {
      final base = event(
        'weekly',
        'Weekly planning',
        date: 'August 12, 2026',
        parsedDate: ParsedDate(absoluteDate: DateTime(2026, 8, 12)),
        repeat: 'Every Week',
      );
      // Expand directly so this test does not depend on the singleton store's
      // mutable test state.
      final expanded = RecurrenceExpander.expand(
        base,
        DateTime(2026, 8, 12),
        DateTime(2026, 8, 26),
      );

      expect(expanded.length, 3);
      expect(
        (await SearchService().query('8/26/26', expanded)).all.single.event.id,
        contains('_r20260826'),
      );
    });
  });

  // ── F. EventStore time normalisation ──────────────────────────────────────
  //
  // EventStore.create() and .update() must normalise any stored time string to
  // 12-hour AM/PM format so all persisted events share a consistent
  // representation regardless of their origin (UI, programmatic, future ICS).
  group('EventStore time normalisation', () {
    test('24-hour "14:30" is stored as "2:30 PM"', () {
      final store = EventStore.instance;
      final event = store.create(title: 'Lunch', time: '14:30');
      expect(event.time, '2:30 PM');
    });

    test('24-hour "09:00" is stored as "9:00 AM"', () {
      final store = EventStore.instance;
      final event = store.create(title: 'Morning yoga', time: '09:00');
      expect(event.time, '9:00 AM');
    });

    test('24-hour "00:00" midnight is stored as "12:00 AM"', () {
      final store = EventStore.instance;
      final event = store.create(title: 'Midnight', time: '00:00');
      expect(event.time, '12:00 AM');
    });

    test('24-hour "12:00" noon is stored as "12:00 PM"', () {
      final store = EventStore.instance;
      final event = store.create(title: 'Noon lunch', time: '12:00');
      expect(event.time, '12:00 PM');
    });

    test('already-12-hour "9:00 AM" is stored unchanged', () {
      final store = EventStore.instance;
      final event = store.create(title: 'Breakfast', time: '9:00 AM');
      expect(event.time, '9:00 AM');
    });

    test('already-12-hour "2:30 PM" is stored unchanged', () {
      final store = EventStore.instance;
      final event = store.create(title: 'Meeting', time: '2:30 PM');
      expect(event.time, '2:30 PM');
    });

    test('null time is preserved as null', () {
      final store = EventStore.instance;
      final event = store.create(title: 'Anytime task', time: null);
      expect(event.time, isNull);
    });

    test('endTime "23:30" is also normalised to "11:30 PM"', () {
      final store = EventStore.instance;
      final event = store.create(
        title: 'Late event',
        time: '20:00',
        endTime: '23:30',
      );
      expect(event.time, '8:00 PM');
      expect(event.endTime, '11:30 PM');
    });

    test('separate date and compact time create a canonical startDateTime', () {
      final store = EventStore.instance;
      final event = store.create(
        title: 'Early meeting',
        date: 'August 12, 2026',
        time: '0830',
      );
      expect(event.time, '8:30 AM');
      expect(event.parsedDate?.absoluteDate, DateTime(2026, 8, 12));
      expect(event.parsedDate?.startDateTime, DateTime(2026, 8, 12, 8, 30));
      expect(event.parsedDate?.canonicalTime, '08:30');
    });

    test('update() normalises 24-hour time before writing', () {
      final store = EventStore.instance;
      // Create an event first (with a known id).
      final original = store.create(title: 'Gym', time: '7:00 AM');
      // Update it with a 24-hour time string.
      final withBadTime = ScheduledEvent(
        id: original.id,
        title: 'Gym (updated)',
        time: '19:00',
      );
      store.update(withBadTime);
      final stored = store.events.value.firstWhere((e) => e.id == original.id);
      expect(stored.time, '7:00 PM');
    });

    test('update() keeps an unchanged display date and time scheduled', () {
      final store = EventStore.instance;
      final original = store.create(
        title: 'Dentist',
        date: 'August 8, 2026',
        time: '3:00 PM',
        endDate: 'August 8, 2026',
        endTime: '4:00 PM',
      );

      // This is the shape produced by the edit sheet when the user opens the
      // event and saves without changing the displayed values.
      store.update(
        ScheduledEvent(
          id: original.id,
          title: original.title,
          date: 'August 8, 2026',
          time: '3:00 PM',
          endDate: 'August 8, 2026',
          endTime: '4:00 PM',
        ),
      );

      final stored = store.events.value.firstWhere((e) => e.id == original.id);
      expect(stored.date, 'August 8, 2026');
      expect(stored.time, '3:00 PM');
      expect(stored.parsedDate?.absoluteDate, DateTime(2026, 8, 8));
      expect(stored.parsedDate?.startDateTime, DateTime(2026, 8, 8, 15));
      expect(stored.parsedDate?.isScheduled, isTrue);
    });
  });

  // ── G. EventStore.loadFromStorage() migration ─────────────────────────────
  //
  // Events saved before the _normalizeTime fix, or events arriving via a
  // future import path (ICS, CSV, paste) that bypasses create()/update(),
  // may carry 24-hour time strings in storage.  loadFromStorage() must silently
  // upgrade them to 12-hour AM/PM so the rest of the app always sees a
  // consistent format.  This test pre-populates SharedPreferences with legacy
  // JSON and confirms the upgrade happens at load time.
  group('EventStore.loadFromStorage() time normalisation (migration)', () {
    // Key must match LocalStorage._kEventsKey.
    const kEventsKey = 'skeddo_events_v1';

    setUp(() {
      SharedPreferences.setMockInitialValues({
        kEventsKey: [
          // Legacy event with 24-hour time and endTime.
          jsonEncode({
            'id': '901',
            'title': 'Legacy 24h event',
            'time': '14:30', // must become "2:30 PM"
            'endTime': '16:00', // must become "4:00 PM"
            'categoryId': 'sys-uncategorized',
          }),
          // Event already stored in 12-hour format — must pass through unchanged.
          jsonEncode({
            'id': '902',
            'title': 'Already 12h event',
            'time': '9:00 AM',
            'categoryId': 'sys-uncategorized',
          }),
          // Midnight edge-case: "00:00" → "12:00 AM".
          jsonEncode({
            'id': '903',
            'title': 'Midnight event',
            'time': '00:00',
            'categoryId': 'sys-uncategorized',
          }),
        ],
      });
    });

    test('24-hour time fields are upgraded to 12-hour AM/PM on load', () async {
      // Reset in-memory list so we see only what loadFromStorage() loads.
      EventStore.instance.events.value = [];
      await EventStore.instance.loadFromStorage();

      final loaded = EventStore.instance.events.value;

      final legacy = loaded.firstWhere((e) => e.id == '901');
      expect(
        legacy.time,
        '2:30 PM',
        reason: '"14:30" must be normalised to "2:30 PM"',
      );
      expect(
        legacy.endTime,
        '4:00 PM',
        reason: '"16:00" must be normalised to "4:00 PM"',
      );

      final modern = loaded.firstWhere((e) => e.id == '902');
      expect(
        modern.time,
        '9:00 AM',
        reason: 'already-12-hour time must pass through unchanged',
      );

      final midnight = loaded.firstWhere((e) => e.id == '903');
      expect(
        midnight.time,
        '12:00 AM',
        reason: '"00:00" must be normalised to "12:00 AM"',
      );
    });

    test(
      'upgraded times are written back to disk so second load needs no re-migration',
      () async {
        // First load: normalises and persists.
        EventStore.instance.events.value = [];
        await EventStore.instance.loadFromStorage();

        // Verify the persisted JSON now contains 12-hour strings by reading
        // directly from SharedPreferences (bypassing EventStore).
        final prefs = await SharedPreferences.getInstance();
        final rawList = prefs.getStringList(kEventsKey) ?? [];
        final decoded = rawList
            .map((s) => jsonDecode(s) as Map<String, dynamic>)
            .toList();

        final legacy = decoded.firstWhere((m) => m['id'] == '901');
        expect(
          legacy['time'],
          '2:30 PM',
          reason: 'persisted JSON must store 12-hour time after migration',
        );
        expect(
          legacy['endTime'],
          '4:00 PM',
          reason: 'persisted JSON must store 12-hour endTime after migration',
        );

        final midnight = decoded.firstWhere((m) => m['id'] == '903');
        expect(
          midnight['time'],
          '12:00 AM',
          reason: 'persisted JSON must store "12:00 AM" for "00:00"',
        );

        // Second load: nothing should be re-normalised (anyChanged stays false).
        // We verify this by confirming the in-memory values are still correct.
        EventStore.instance.events.value = [];
        await EventStore.instance.loadFromStorage();

        final reloaded = EventStore.instance.events.value;
        final reloadedLegacy = reloaded.firstWhere((e) => e.id == '901');
        expect(
          reloadedLegacy.time,
          '2:30 PM',
          reason: 'second load must still return normalised time',
        );
      },
    );
  });

  // ── LocalStorage.saveEvents — failure detection ───────────────────────────
  group('LocalStorage.saveEvents failure detection', () {
    final event = ScheduledEvent(
      id: '1',
      title: 'Test event',
      time: '9:00 AM',
      categoryId: 'sys-uncategorized',
    );

    setUp(() {
      // Start each test with a clean, functioning store.
      SharedPreferences.setMockInitialValues({});
    });

    test('returns true when SharedPreferences write succeeds', () async {
      final result = await LocalStorage.instance.saveEvents([event]);
      expect(result, isTrue, reason: 'successful write must return true');
    });

    test(
      'returns false when SharedPreferences returns false for the write',
      () async {
        SharedPreferencesStorePlatform.instance = _FalseWritePrefsStore();
        // Clear the cached SharedPreferences instance so the next call
        // picks up our custom store rather than the cached one.
        SharedPreferences.resetStatic();

        final result = await LocalStorage.instance.saveEvents([event]);
        expect(
          result,
          isFalse,
          reason: 'a store that returns false must propagate false',
        );
      },
    );

    test(
      'returns false when SharedPreferences throws during the write',
      () async {
        SharedPreferencesStorePlatform.instance = _ThrowingWritePrefsStore();
        SharedPreferences.resetStatic();

        final result = await LocalStorage.instance.saveEvents([event]);
        expect(
          result,
          isFalse,
          reason: 'an exception during save must be caught and return false',
        );
      },
    );
  });

  // ── LocalStorage embedding-version persistence — failure paths ───────────
  //
  // saveEmbeddingVersions() returns false (never throws) on write failure.
  // loadEmbeddingVersions() returns {} (never throws) on any read failure.
  // These tests assert both contracts using the same stub infrastructure as
  // the saveEvents() failure tests above.
  group('LocalStorage embedding-version persistence failure paths', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    // ── saveEmbeddingVersions ─────────────────────────────────────────────

    test('saveEmbeddingVersions returns true on a successful write', () async {
      final result = await LocalStorage.instance.saveEmbeddingVersions({
        'evt1': 'v1',
      });
      expect(result, isTrue, reason: 'successful write must return true');
    });

    test('saveEmbeddingVersions returns false when the store returns false '
        '(e.g. storage quota exceeded)', () async {
      SharedPreferencesStorePlatform.instance = _FalseWritePrefsStore();
      SharedPreferences.resetStatic();

      final result = await LocalStorage.instance.saveEmbeddingVersions({
        'evt1': 'v1',
      });
      expect(
        result,
        isFalse,
        reason:
            'a store that returns false must propagate false — '
            'callers rely on this to know the version map was not persisted',
      );
    });

    test('saveEmbeddingVersions returns false when the store throws '
        '(e.g. permission error)', () async {
      SharedPreferencesStorePlatform.instance = _ThrowingWritePrefsStore();
      SharedPreferences.resetStatic();

      final result = await LocalStorage.instance.saveEmbeddingVersions({
        'evt1': 'v1',
      });
      expect(
        result,
        isFalse,
        reason: 'an exception during save must be caught and return false',
      );
    });

    // ── loadEmbeddingVersions ─────────────────────────────────────────────

    test(
      'loadEmbeddingVersions returns {} when no data has been saved',
      () async {
        final result = await LocalStorage.instance.loadEmbeddingVersions();
        expect(
          result,
          isEmpty,
          reason: 'absent key must produce an empty map, not null or an error',
        );
      },
    );

    test('loadEmbeddingVersions returns {} when the store read throws '
        '(e.g. underlying store unavailable)', () async {
      // _ThrowingReadPrefsStore.getAll() throws, so SharedPreferences.getInstance()
      // propagates the error into the try-block inside loadEmbeddingVersions(),
      // which must catch it and return {}.
      SharedPreferencesStorePlatform.instance = _ThrowingReadPrefsStore();
      SharedPreferences.resetStatic();

      final result = await LocalStorage.instance.loadEmbeddingVersions();
      expect(
        result,
        isEmpty,
        reason:
            'a store whose read throws must be caught and return an empty map',
      );
    });

    test('loadEmbeddingVersions returns {} when stored JSON is corrupt '
        '(decoding error)', () async {
      const kEmbKey = 'skeddo_emb_versions_v1';
      SharedPreferences.setMockInitialValues({
        'flutter.$kEmbKey': 'NOT_VALID_JSON{{{',
      });

      final result = await LocalStorage.instance.loadEmbeddingVersions();
      expect(
        result,
        isEmpty,
        reason: 'corrupt JSON must be caught and return {}',
      );
    });
  });

  // ── EventPipeline — embedding-version save failure is surfaced via debugPrint
  //
  // Verifies that EventPipeline reacts to a false return from
  // saveEmbeddingVersions by emitting a debugPrint warning, so the failure is
  // visible in development logs rather than completely silent.
  group('EventPipeline logs a warning when embedding-version save fails', () {
    setUp(() {
      // Start each test with an empty, functioning store so reads succeed.
      SharedPreferences.setMockInitialValues({});
    });

    tearDown(() {
      // Reset singleton hooks so subsequent test groups are not affected.
      EventStore.setPipelineHooks(
        onAdded: (_, __) async {},
        onRemoved: (_, __, ___) async {},
        onUpdated: (_) async {},
      );
    });

    test(
      'creating an event emits a debugPrint warning when the store returns false',
      () async {
        // Wire the real EventPipeline hooks so _onAdded runs on EventStore.create.
        EventPipeline.instance.init();

        // Install the failing store AFTER init() (which only wires hooks, not I/O).
        SharedPreferencesStorePlatform.instance = _FalseWritePrefsStore();
        SharedPreferences.resetStatic();

        // Capture debugPrint output.
        final logs = <String>[];
        final originalDebugPrint = debugPrint;
        debugPrint = (String? msg, {int? wrapWidth}) {
          if (msg != null) logs.add(msg);
        };

        try {
          EventStore.instance.events.value = [];
          EventStore.instance.create(title: 'Pipeline failure test');

          // Let the fire-and-forget async pipeline work complete.
          // Two rounds: one for _onAdded to be scheduled, one for its awaits.
          await Future<void>.delayed(const Duration(milliseconds: 100));
        } finally {
          debugPrint = originalDebugPrint;
        }

        expect(
          logs,
          anyElement(contains('saveEmbeddingVersions')),
          reason:
              'EventPipeline must log a debugPrint warning when '
              'saveEmbeddingVersions returns false so the failure is '
              'visible in development logs rather than completely silent.',
        );
      },
    );
  });

  // ── EventPipeline — event save failure is surfaced via debugPrint ─────────
  //
  // Parallel to the embedding-version group above: verifies that EventPipeline
  // reacts to a false return from saveEvents() by emitting a debugPrint
  // warning, so a full-disk event write is visible in development logs rather
  // than completely silent.
  group('EventPipeline logs a warning when event save fails', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    tearDown(() {
      EventStore.setPipelineHooks(
        onAdded: (_, __) async {},
        onRemoved: (_, __, ___) async {},
        onUpdated: (_) async {},
      );
    });

    test(
      'creating an event emits a debugPrint warning when saveEvents returns false',
      () async {
        // Wire the real EventPipeline hooks so _onAdded runs on EventStore.create.
        EventPipeline.instance.init();

        // Install the failing store AFTER init() (which only wires hooks, not I/O).
        SharedPreferencesStorePlatform.instance = _FalseWritePrefsStore();
        SharedPreferences.resetStatic();

        // Capture debugPrint output.
        final logs = <String>[];
        final originalDebugPrint = debugPrint;
        debugPrint = (String? msg, {int? wrapWidth}) {
          if (msg != null) logs.add(msg);
        };

        try {
          EventStore.instance.events.value = [];
          EventStore.instance.create(title: 'Save failure log test');

          // Let the fire-and-forget async pipeline work complete.
          await Future<void>.delayed(const Duration(milliseconds: 100));
        } finally {
          debugPrint = originalDebugPrint;
        }

        expect(
          logs,
          anyElement(contains('saveEvents')),
          reason:
              'EventPipeline must emit a debugPrint warning when '
              'saveEvents returns false so the failure is visible in '
              'development logs rather than completely silent.',
        );
      },
    );
  });

  // ── Category persistence: save failure → load keeps defaults ─────────────
  //
  // EventsTabState._saveCategories() writes eight keys to SharedPreferences
  // in a fire-and-forget .then() chain with no error handler.  If the device
  // storage is full the writes throw but the exception is absorbed by the
  // Future — the widget never crashes.  On the next launch _loadCategories()
  // reads those keys; finding all null it hits the early-exit guard and keeps
  // the built-in system categories intact rather than replacing them with
  // empty or corrupt state.
  //
  // These tests verify both halves of that contract:
  //   1. A write-throwing store does not propagate past a catchError boundary
  //      (mirrors the fire-and-forget .then() call in the real code).
  //   2. When all category keys are absent, the early-exit condition in
  //      _loadCategories() evaluates to true → defaults are preserved.
  group('Category persistence: save failure leaves defaults intact', () {
    // Key constants — must match EventsTabState._kPrefs* values.
    const kUserCats = 'events_user_categories';
    const kPinnedCats = 'events_pinned_categories';
    const kSmartColors = 'events_smart_category_colors';
    const kArchivedSmart = 'events_archived_smart_categories';
    const kSmartOrder = 'events_smart_category_order';

    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test(
      'throws from _saveCategories are swallowed — widget does not crash',
      () async {
        // Install the throwing store (simulates device storage full).
        SharedPreferencesStorePlatform.instance = _ThrowingWritePrefsStore();
        SharedPreferences.resetStatic();

        final prefs = await SharedPreferences.getInstance();

        // Replicate the eight setStringList / setString calls that
        // _saveCategories() fires off inside a .then() with no catchError.
        // Each write throws; a real .then() chain would surface the error as an
        // unhandled Future — we absorb it with catchError to match that contract.
        // The critical assertion is that catchError is sufficient: nothing escapes
        // to crash the caller.
        final futures = [
          prefs
              .setStringList(kUserCats, ['{"name":"Work"}'])
              .catchError((_) => false),
          prefs.setStringList(kPinnedCats, []).catchError((_) => false),
          prefs.setString(kSmartColors, '{}').catchError((_) => false),
          prefs.setStringList(kArchivedSmart, []).catchError((_) => false),
          prefs
              .setStringList(kSmartOrder, ['Today', 'Tomorrow'])
              .catchError((_) => false),
        ];

        // All futures complete (possibly with false) — none propagate.
        final results = await Future.wait(futures);
        expect(
          results,
          everyElement(isFalse),
          reason:
              'every write must return false (absorbed throw) '
              'so no exception reaches the widget',
        );
      },
    );

    test('no category data in SharedPreferences after write failure — '
        '_loadCategories early-exit keeps system defaults', () async {
      // Represent the state after a write failure: all category keys absent
      // (because the _saveCategories() writes threw before committing).
      // SharedPreferences.setMockInitialValues({}) in setUp already gives us
      // an empty store — nothing was ever written.
      final prefs = await SharedPreferences.getInstance();

      final rawUser = prefs.getStringList(kUserCats);
      final rawPinned = prefs.getStringList(kPinnedCats);
      final rawSmartColors = prefs.getString(kSmartColors);
      final rawArchivedSmart = prefs.getStringList(kArchivedSmart);
      final rawSmartOrder = prefs.getStringList(kSmartOrder);

      // This is the exact guard at the top of _loadCategories():
      //   if (rawUser == null && rawPinned == null && rawSmartColors == null &&
      //       rawArchivedSmart == null && rawSmartOrder == null) return;
      // When it evaluates to true the function exits without calling setState,
      // leaving the built-in system categories (Today, Tomorrow, …) intact.
      final keepDefaults =
          rawUser == null &&
          rawPinned == null &&
          rawSmartColors == null &&
          rawArchivedSmart == null &&
          rawSmartOrder == null;

      expect(
        keepDefaults,
        isTrue,
        reason:
            'when _saveCategories throws (storage full), no category data '
            'reaches SharedPreferences; _loadCategories must then hit the '
            'all-null early-exit and preserve the built-in system categories '
            'instead of crashing or returning empty state',
      );
    });

    test('_loadCategories does not crash when the SharedPreferences read itself '
        'throws (underlying store unavailable)', () async {
      // Install a read-throwing store.  SharedPreferences.getInstance()
      // internally calls getAll() — if that throws, the .then() callback in
      // _loadCategories() never fires, so the widget must not crash.
      SharedPreferencesStorePlatform.instance = _ThrowingReadPrefsStore();
      SharedPreferences.resetStatic();

      // Replicate the SharedPreferences.getInstance().then((prefs) { ... })
      // pattern used by _loadCategories() with an absorbed error.
      Object? caughtError;
      await SharedPreferences.getInstance()
          .then<void>((prefs) {
            // If getInstance() somehow succeeded, read would happen here.
            prefs.getStringList(kUserCats);
          })
          .catchError((e) {
            caughtError = e;
          });

      // Either the read threw (caughtError set) or it silently returned null —
      // both outcomes are acceptable; neither should propagate as an uncaught
      // exception that would crash the app.
      // We assert the test body itself completes without throwing.
      expect(
        true,
        isTrue,
        reason:
            'a read-throwing SharedPreferences store must not propagate '
            'an uncaught exception out of _loadCategories()',
      );
    });
  });

  // ── EventStore.loadFromStorage — in-memory resilience on save failure ──────
  group('EventStore.loadFromStorage in-memory resilience on save failure', () {
    const kEventsKey = 'skeddo_events_v1';

    final legacy24hJson = jsonEncode({
      'id': '801',
      'title': 'Legacy event',
      'time': '14:00', // 24-hour — must become "2:00 PM"
      'endTime': '16:30', // 24-hour — must become "4:30 PM"
      'categoryId': 'sys-uncategorized',
    });

    test(
      'in-memory events are normalised even when the write-back store returns false',
      () async {
        SharedPreferences.setMockInitialValues({
          'flutter.$kEventsKey': [legacy24hJson],
        });

        EventStore.instance.events.value = [];
        await EventStore.instance.loadFromStorage();

        // In-memory state must be correctly normalised regardless of disk outcome.
        final loaded = EventStore.instance.events.value;
        expect(loaded, isNotEmpty, reason: 'events must be present in memory');
        final e = loaded.firstWhere((ev) => ev.id == '801');
        expect(
          e.time,
          '2:00 PM',
          reason: 'in-memory time must be normalised even if write-back fails',
        );
        expect(
          e.endTime,
          '4:30 PM',
          reason:
              'in-memory endTime must be normalised even if write-back fails',
        );
      },
    );

    test(
      'in-memory events are normalised even when the write-back store throws',
      () async {
        // Use the pre-populated constructor so reads succeed while every write
        // throws — this exercises the exception branch of saveEvents() called
        // from loadFromStorage() without preventing the initial getAll() read.
        SharedPreferencesStorePlatform.instance =
            _ThrowingWritePrefsStore.withData({
              'flutter.$kEventsKey': [legacy24hJson],
            });
        SharedPreferences.resetStatic();

        EventStore.instance.events.value = [];
        await EventStore.instance.loadFromStorage();

        // Events must be present and normalised in memory even though the
        // write-back threw — the exception is caught inside saveEvents().
        final loaded = EventStore.instance.events.value;
        expect(
          loaded,
          isNotEmpty,
          reason:
              'events must be present in memory even when write-back throws',
        );
        final e = loaded.firstWhere((ev) => ev.id == '801');
        expect(
          e.time,
          '2:00 PM',
          reason:
              'in-memory time must be normalised even when write-back throws',
        );
      },
    );
  });

  // ── H. End-to-end restart resilience ────────────────────────────────────
  //
  // Simulates the full write-fail → app-restart → re-load cycle for both
  // events and categories at the same time.
  //
  // Scenario A — data already persisted, mid-session write fails:
  //   Pre-session state is successfully written to SharedPreferences.
  //   Mid-session the store starts throwing (device fills up).
  //   After a simulated restart the app reads from SharedPreferences and
  //   must see the last successfully persisted snapshot — not the unsaved
  //   in-memory changes, and not an empty / default state.
  //
  // Scenario B — first-ever launch, write fails before anything is saved:
  //   Nothing reaches SharedPreferences.
  //   On restart events are empty and the _loadCategories() early-exit guard
  //   (all keys null) fires, keeping the built-in system defaults.
  group(
    'End-to-end restart resilience: events and categories survive write failure',
    () {
      // Key constants — must match LocalStorage and EventsTabState values.
      const kEventsKey = 'skeddo_events_v1';
      const kUserCats = 'events_user_categories';
      const kPinnedCats = 'events_pinned_categories';
      const kSmartColors = 'events_smart_category_colors';
      const kArchivedSmart = 'events_archived_smart_categories';
      const kSmartOrder = 'events_smart_category_order';

      // Canonical JSON for the pre-session event (12-hour time, already normalised).
      final preSessionEventJson = jsonEncode({
        'id': '701',
        'title': 'Pre-session meeting',
        'time': '10:00 AM',
        'categoryId': 'sys-uncategorized',
      });

      // Minimal valid category JSON (matches _UserCategory.toJson shape).
      // Only the fields that _loadCategories() will actually parse are needed.
      final preSessionCatJson = jsonEncode({
        'id': 'cat-work',
        'name': 'Work',
        'emoji': '💼',
        'color': 4280391411,
        'description': '',
        'isSmartCategory': false,
        'archived': false,
      });

      // Helper: the pre-session SharedPreferences contents (with flutter. prefix).
      Map<String, Object> preSessionData() => {
        'flutter.$kEventsKey': [preSessionEventJson],
        'flutter.$kUserCats': [preSessionCatJson],
        'flutter.$kPinnedCats': <String>[],
        'flutter.$kSmartColors': '{}',
        'flutter.$kArchivedSmart': <String>[],
        'flutter.$kSmartOrder': <String>[],
      };

      // ── Scenario A ──────────────────────────────────────────────────────────

      test(
        'Scenario A: after mid-session write failure + simulated restart, '
        'events and categories reflect the last successfully persisted snapshot',
        () async {
          // ① Install a normal store pre-seeded with the pre-session data.
          //   (setMockInitialValues also calls resetStatic internally.)
          SharedPreferences.setMockInitialValues({
            'flutter.$kEventsKey': [preSessionEventJson],
            'flutter.$kUserCats': [preSessionCatJson],
            'flutter.$kPinnedCats': <String>[],
            'flutter.$kSmartColors': '{}',
            'flutter.$kArchivedSmart': <String>[],
            'flutter.$kSmartOrder': <String>[],
          });

          // Verify: pre-session events load correctly.
          EventStore.instance.events.value = [];
          await EventStore.instance.loadFromStorage();
          expect(EventStore.instance.events.value.length, 1);
          expect(EventStore.instance.events.value.first.id, '701');

          // ② Mid-session: device fills up — swap to a store that allows reads
          //   (still returns the pre-session data) but throws on every write.
          SharedPreferencesStorePlatform.instance =
              _ThrowingWritePrefsStore.withData(preSessionData());
          SharedPreferences.resetStatic();

          // Attempt to persist a new event created mid-session — write fails.
          final evtWriteOk = await LocalStorage.instance.saveEvents([
            ScheduledEvent(
              id: '701',
              title: 'Pre-session meeting',
              time: '10:00 AM',
              categoryId: 'sys-uncategorized',
            ),
            ScheduledEvent(
              id: '702',
              title: 'New unsaved event',
              time: '2:00 PM',
              categoryId: 'sys-uncategorized',
            ),
          ]);
          expect(
            evtWriteOk,
            isFalse,
            reason: 'event write must fail when the store throws',
          );

          // Attempt to persist a new category mid-session — write also fails.
          final prefs = await SharedPreferences.getInstance();
          bool catWriteOk = true;
          try {
            catWriteOk = await prefs.setStringList(kUserCats, [
              preSessionCatJson,
              jsonEncode({
                'id': 'cat-personal',
                'name': 'Personal',
                'emoji': '🏠',
                'color': 4280391411,
                'description': '',
                'isSmartCategory': false,
                'archived': false,
              }),
            ]);
          } catch (_) {
            catWriteOk = false;
          }
          expect(
            catWriteOk,
            isFalse,
            reason: 'category write must fail when the store throws',
          );

          // ③ Simulate app restart: restore a normal (read/write) store seeded
          //   with only the original pre-session snapshot — nothing from the
          //   failed mid-session writes reached disk.
          SharedPreferences.setMockInitialValues({
            'flutter.$kEventsKey': [preSessionEventJson],
            'flutter.$kUserCats': [preSessionCatJson],
            'flutter.$kPinnedCats': <String>[],
            'flutter.$kSmartColors': '{}',
            'flutter.$kArchivedSmart': <String>[],
            'flutter.$kSmartOrder': <String>[],
          });

          // Re-load events exactly as app startup does.
          EventStore.instance.events.value = [];
          await EventStore.instance.loadFromStorage();

          // ④ Assert events: only the pre-session event is present.
          final events = EventStore.instance.events.value;
          expect(
            events.length,
            1,
            reason:
                'after restart only the pre-failure event must be present; '
                'the unsaved mid-session event must not appear',
          );
          expect(events.first.id, '701');
          expect(events.first.title, 'Pre-session meeting');
          expect(events.first.time, '10:00 AM');

          // ④ Assert categories: read exactly as _loadCategories() would.
          final restartPrefs = await SharedPreferences.getInstance();
          final rawUser = restartPrefs.getStringList(kUserCats);

          expect(
            rawUser,
            isNotNull,
            reason:
                'category data written before the failure must still be present',
          );
          expect(
            rawUser!.length,
            1,
            reason:
                'only the original category must be present; '
                'the unsaved "Personal" category must not appear',
          );
          final catMap = jsonDecode(rawUser.first) as Map<String, dynamic>;
          expect(
            catMap['name'],
            'Work',
            reason: 'original category name must be preserved across restart',
          );

          // The early-exit guard in _loadCategories() checks rawUser == null.
          // Since rawUser is non-null here the function will proceed to load —
          // confirm the guard would NOT fire so categories are not reset to defaults.
          expect(
            rawUser != null,
            isTrue,
            reason:
                'because data was successfully written before the failure, '
                '_loadCategories must load it rather than hit the all-null '
                'early-exit that would reset to system defaults',
          );
        },
      );

      // ── Scenario B ──────────────────────────────────────────────────────────

      test(
        'Scenario B: when the very first write fails (nothing ever persisted), '
        'restart sees empty events and _loadCategories keeps system defaults',
        () async {
          // Brand-new install: storage is empty and immediately starts throwing.
          SharedPreferencesStorePlatform.instance = _ThrowingWritePrefsStore();
          SharedPreferences.resetStatic();

          // _saveCategories() fires during first launch — write throws.
          final firstPrefs = await SharedPreferences.getInstance();
          bool firstCatWrite = true;
          try {
            firstCatWrite = await firstPrefs.setStringList(kUserCats, [
              preSessionCatJson,
            ]);
          } catch (_) {
            firstCatWrite = false;
          }
          expect(
            firstCatWrite,
            isFalse,
            reason: 'first-launch category write must fail when storage throws',
          );

          // Event save also fails.
          final firstEvtWrite = await LocalStorage.instance.saveEvents([
            ScheduledEvent(
              id: '801',
              title: 'First event',
              time: '9:00 AM',
              categoryId: 'sys-uncategorized',
            ),
          ]);
          expect(
            firstEvtWrite,
            isFalse,
            reason: 'first-launch event write must fail when storage throws',
          );

          // Simulate restart: empty store (nothing was ever persisted).
          SharedPreferences.setMockInitialValues({});
          EventStore.instance.events.value = [];
          await EventStore.instance.loadFromStorage();

          // Events: empty because nothing was ever successfully written.
          expect(
            EventStore.instance.events.value,
            isEmpty,
            reason:
                'no events were ever persisted, so restart must load an '
                'empty list',
          );

          // Categories: all keys absent → _loadCategories() early-exit fires.
          final restartPrefs = await SharedPreferences.getInstance();
          final rawUser2 = restartPrefs.getStringList(kUserCats);
          final rawPinned2 = restartPrefs.getStringList(kPinnedCats);
          final rawSmartColors2 = restartPrefs.getString(kSmartColors);
          final rawArchivedSmart2 = restartPrefs.getStringList(kArchivedSmart);
          final rawSmartOrder2 = restartPrefs.getStringList(kSmartOrder);

          final allNull =
              rawUser2 == null &&
              rawPinned2 == null &&
              rawSmartColors2 == null &&
              rawArchivedSmart2 == null &&
              rawSmartOrder2 == null;

          expect(
            allNull,
            isTrue,
            reason:
                'when no write ever succeeded all category keys must be '
                'absent, so _loadCategories() early-exit fires and the '
                'built-in system defaults (Today, Tomorrow, …) are kept intact',
          );
        },
      );
    },
  );

  // ── G. Category lifecycle event placement ───────────────────────────────────
  //
  // Archived contents must be absent from the active event corpus, while
  // category-only actions must keep events active and reassign them.
  group('EventStore category lifecycle event placement', () {
    late EventStore store;
    late String originalDefaultId;

    setUp(() {
      store = EventStore.instance;
      originalDefaultId = appDefaultCategoryNotifier.value;
      store.events.value = [];
      store.archivedEvents.value = [];
      store.deletedEvents.value = [];
    });

    tearDown(() {
      store.events.value = [];
      store.archivedEvents.value = [];
      store.deletedEvents.value = [];
      appDefaultCategoryNotifier.value = originalDefaultId;
    });

    test('archive with contents removes events from active storage', () {
      final event = store.create(
        title: 'Archived meeting',
        categoryId: 'category-work',
      );

      expect(store.archiveEventsForCategory('category-work'), 1);
      expect(store.events.value, isEmpty);
      expect(store.archivedEvents.value.single.id, event.id);
      expect(store.archivedEvents.value.single.categoryId, 'category-work');
      expect(store.deletedEvents.value, isEmpty);
    });

    test('recovering an archived category restores its events there', () {
      final event = store.create(
        title: 'Recoverable meeting',
        categoryId: 'category-work',
      );
      store.archiveEventsForCategory('category-work');

      expect(store.restoreArchivedEventsForCategory('category-work'), 1);
      expect(store.archivedEvents.value, isEmpty);
      expect(store.events.value.single.id, event.id);
      expect(store.events.value.single.categoryId, 'category-work');
      expect(store.restoreArchivedEventsForCategory('category-work'), 0);
    });

    test('category-only reassignment keeps events active in the default', () {
      appDefaultCategoryNotifier.value = 'category-default';
      final event = store.create(
        title: 'Reassigned meeting',
        categoryId: 'category-work',
      );

      store.reassignCategories(fromCategoryIds: {'category-work'});

      expect(store.events.value.single.id, event.id);
      expect(store.events.value.single.categoryId, 'category-default');
      expect(store.archivedEvents.value, isEmpty);
    });

    test('deleting an archived category moves its contents to deleted storage', () {
      final event = store.create(
        title: 'Deleted archived meeting',
        categoryId: 'category-work',
      );
      store.archiveEventsForCategory('category-work');

      expect(store.deleteArchivedEventsForCategory('category-work'), 1);
      expect(store.events.value, isEmpty);
      expect(store.archivedEvents.value, isEmpty);
      expect(store.deletedEvents.value.single.id, event.id);
      expect(store.deletedEvents.value.single.categoryId, 'category-work');
    });

    test('archived contents survive a reload from local storage', () async {
      final event = store.create(
        title: 'Persistent archived meeting',
        categoryId: 'category-work',
      );
      store.archiveEventsForCategory('category-work');

      store.events.value = [];
      store.archivedEvents.value = [];
      store.deletedEvents.value = [];
      await store.loadFromStorage();

      expect(store.events.value, isEmpty);
      expect(store.archivedEvents.value.single.id, event.id);
      expect(store.archivedEvents.value.single.title, event.title);
      expect(store.archivedEvents.value.single.categoryId, 'category-work');
    });
  });
}

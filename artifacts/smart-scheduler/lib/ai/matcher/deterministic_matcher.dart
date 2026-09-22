import '../interfaces.dart';
import '../../services/event_model.dart';

// ─────────────────────────────────────────────────────────────────────────────
// DeterministicMatcher — Phase 1 implementation of SmartCategoryMatcher.
//
// Combines two signals:
//   1. Date-range filtering (for built-in smart tiles and date-based concepts
//      in user Smart Category descriptions).
//   2. Keyword matching (for semantic concepts in user Smart Category
//      descriptions — e.g., "Birthdays", "Travel", "Meetings").
//
// Phase 2 replaces signal #2 with vector cosine similarity via HybridMatcher,
// while keeping the date-range signal unchanged.
// ─────────────────────────────────────────────────────────────────────────────
class DeterministicMatcher implements SmartCategoryMatcher {
  // Words too common to be useful as keywords.
  static const _stopWords = {
    'a',
    'an',
    'the',
    'and',
    'or',
    'but',
    'in',
    'on',
    'at',
    'to',
    'for',
    'of',
    'with',
    'by',
    'from',
    'as',
    'is',
    'was',
    'are',
    'were',
    'be',
    'been',
    'being',
    'have',
    'has',
    'had',
    'do',
    'does',
    'did',
    'will',
    'would',
    'could',
    'should',
    'may',
    'might',
    'must',
    'shall',
    'can',
    'not',
    'no',
    'nor',
    'so',
    'yet',
    'both',
    'either',
    'neither',
    'any',
    'all',
    'each',
    'every',
    'some',
    'my',
    'your',
    'his',
    'her',
    'its',
    'our',
    'their',
    'this',
    'that',
    'these',
    'those',
    'i',
    'me',
    'we',
    'you',
    'he',
    'she',
    'it',
    'they',
    'them',
    'us',
    'who',
    'what',
    'when',
    'where',
    'how',
    'which',
    'event',
    'events',
  };

  @override
  List<ScheduledEvent> match({
    required List<ScheduledEvent> candidates,
    required String rule,
    String? builtInLabel,
    String? categoryName, // unused in keyword-only matcher; present for interface compat
    DateTime? now,
  }) {
    final ref = now ?? DateTime.now();

    // ── Built-in smart tiles — date-range filtering ───────────────────────
    if (builtInLabel != null) {
      return _matchBuiltIn(candidates, builtInLabel, ref);
    }

    // ── User Smart Categories — keyword + date hybrid ─────────────────────
    return _matchUserRule(candidates, rule, ref);
  }

  // ── Built-in tile matching ─────────────────────────────────────────────────

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
        // Completion tracking is not yet implemented — return empty list.
        return [];
      default:
        return [];
    }
  }

  // ── User Smart Category matching ───────────────────────────────────────────

  List<ScheduledEvent> _matchUserRule(
    List<ScheduledEvent> candidates,
    String rule,
    DateTime ref,
  ) {
    if (rule.trim().isEmpty) return [];

    // Extract meaningful keywords from the rule description.
    final keywords = _extractKeywords(rule);
    if (keywords.isEmpty) return [];

    // Score each event by how many keywords appear in its searchable text.
    final scored = <ScheduledEvent, int>{};
    for (final event in candidates) {
      final haystack = _eventText(event).toLowerCase();
      var score = 0;
      for (final kw in keywords) {
        if (haystack.contains(kw)) score++;
      }
      if (score > 0) scored[event] = score;
    }

    // Return events sorted by score descending (highest relevance first).
    final matched = scored.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return matched.map((e) => e.key).toList();
  }

  // ── Keyword extraction ─────────────────────────────────────────────────────

  // When a rule keyword belongs to one of these groups, all other words in the
  // group are added to the keyword set so semantically related concepts are
  // bridged (e.g. "eat" → "lunch", "dinner").
  static const _kSynonymGroups = <Set<String>>[
    {'eat', 'eating', 'food', 'meal', 'lunch', 'dinner', 'breakfast',
     'brunch', 'snack', 'restaurant', 'cafe', 'dining', 'grocery',
     'groceries', 'supper'},
    {'exercise', 'workout', 'gym', 'run', 'running', 'yoga', 'swim',
     'swimming', 'fitness', 'sport', 'sports', 'training', 'cycling',
     'hike', 'hiking', 'walk', 'walking', 'jog', 'jogging'},
    {'meeting', 'call', 'conference', 'sync', 'standup', 'interview',
     'review', 'presentation', 'demo', 'work', 'office', 'client'},
    {'birthday', 'bday', 'anniversary', 'celebrate', 'celebration', 'party',
     'bash', 'gathering'},
    {'travel', 'trip', 'flight', 'hotel', 'vacation', 'holiday', 'journey',
     'airbnb', 'airport'},
    {'doctor', 'appointment', 'medical', 'dentist', 'hospital', 'clinic',
     'health', 'checkup', 'therapy', 'physio'},
    {'family', 'kids', 'children', 'school', 'pickup', 'dropoff',
     'parent', 'son', 'daughter'},
    {'shop', 'shopping', 'store', 'mall', 'buy', 'purchase', 'errands',
     'market'},
    // Entertainment / media
    {'anime', 'manga', 'cartoon', 'animation', 'animated', 'series',
     'episode', 'watch', 'stream', 'streaming'},
    {'movie', 'film', 'cinema', 'theater', 'theatre', 'screening'},
    {'music', 'concert', 'gig', 'band', 'album', 'song', 'playlist',
     'listen', 'festival', 'performance'},
    {'game', 'gaming', 'videogame', 'esport', 'play', 'playstation',
     'xbox', 'nintendo', 'steam'},
    // Leisure / hobbies
    {'book', 'reading', 'novel', 'library', 'read', 'chapter', 'fiction',
     'nonfiction', 'ebook'},
    {'hobby', 'craft', 'art', 'painting', 'drawing', 'knitting',
     'gardening', 'photography', 'photo', 'diy'},
    {'sleep', 'rest', 'nap', 'relax', 'meditation', 'spa', 'massage'},
    // Finance / admin
    {'finance', 'money', 'bank', 'budget', 'payment', 'bill', 'invoice',
     'salary', 'tax', 'invest', 'savings'},
    // Chores
    {'clean', 'cleaning', 'chores', 'laundry', 'tidy', 'dishes',
     'housework', 'vacuum', 'sweep'},
    // School / work projects
    {'project', 'deadline', 'submit', 'assignment', 'homework', 'report',
     'essay', 'thesis'},
    {'study', 'studying', 'learn', 'learning', 'course', 'class',
     'lecture', 'tutorial'},
  ];

  Set<String> _extractKeywords(String rule) {
    // Tokenise on non-alphanumeric characters, filter stopwords and short words.
    final base = rule
        .toLowerCase()
        .split(RegExp(r'[^a-z0-9]+'))
        .where((w) => w.length >= 3 && !_stopWords.contains(w))
        .toSet();
    // Expand to synonyms so rules like "Eat" match events titled "Lunch".
    final expanded = Set<String>.from(base);
    for (final kw in List<String>.from(base)) {
      final variants = <String>{kw};
      if (kw.endsWith('ies') && kw.length > 4) {
        variants.add('${kw.substring(0, kw.length - 3)}y');
      } else if (kw.endsWith('s') && !kw.endsWith('ss') && kw.length > 3) {
        variants.add(kw.substring(0, kw.length - 1));
      }
      expanded.addAll(variants);
      for (final group in _kSynonymGroups) {
        if (variants.any(group.contains)) {
          expanded.addAll(group);
          break;
        }
      }
    }
    return expanded;
  }

  // ── Searchable event text ──────────────────────────────────────────────────

  String _eventText(ScheduledEvent e) {
    return [
      e.title,
      if (e.date != null) e.date!,
      if (e.location != null) e.location!,
    ].join(' ');
  }
}

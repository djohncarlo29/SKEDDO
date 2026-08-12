import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'interfaces.dart';
import 'parsed_date.dart';
import 'date_parser/rule_based_date_parser.dart';
import 'embedding/null_embedding_service.dart';
import 'embedding/onnx_embedding_service.dart';
// dart:ffi (used by tflite_flutter) is incompatible with dart2js; use a no-op
// stub on web so the import compiles cleanly. The kIsWeb runtime guard in
// AIServices.init() ensures TFLiteEmbeddingService is never instantiated there.
import 'embedding/tflite_embedding_service.dart'
    if (dart.library.html) 'embedding/tflite_embedding_service_web.dart';
import 'vector_index/hnsw_vector_index.dart';
import 'matcher/hybrid_matcher.dart';
import 'smart_rule_parser.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AIServices — central service locator for all AI components.
//
// Phase 1 (web/fallback): RuleBasedDateParser + NullEmbeddingService +
//   HnswVectorIndex (brute-force path) + HybridMatcher (keyword fallback).
//
// Phase 2 (native): RuleBasedDateParser + OnnxEmbeddingService +
//   HnswVectorIndex (HNSW path once index > 500 entries) + HybridMatcher
//   (vector cosine similarity).
//
// Swap implementations by calling the set* methods once at startup — no
// other code changes needed.
//
// Usage:
//   await AIServices.init();               // call once in main()
//   final pd = AIServices.dateParser.parse('next Monday');
//   final vec = await AIServices.embedding.embed('birthday party');
//   final hits = AIServices.matcher.match(candidates: events, rule: 'birthdays');
//   await AIServices.embedCategory('Birthdays', 'birthday celebrations');
// ─────────────────────────────────────────────────────────────────────────────
class AIServices {
  AIServices._();

  // ── Phase 1 stub implementations (always available) ────────────────────────
  static const _nullEmbedding = NullEmbeddingService();

  // ── Phase 2 concrete implementations ──────────────────────────────────────
  static final _hnswIndex = HnswVectorIndex();
  static final _hybridMatcher = HybridMatcher();

  // ── Active implementations ─────────────────────────────────────────────────
  static DateParser _dateParser = RuleBasedDateParser();
  static DateLocalePreference _dateLocalePreference =
      DateLocalePreference.monthFirst;
  static EmbeddingService _embedding = _nullEmbedding;

  // ── Priority classification anchors ───────────────────────────────────────
  // One representative sentence per level (0=None … 3=High).
  // Embedded once after the model loads; cosine similarity selects the winner.
  static const _kPriorityAnchorTexts = [
    'casual personal note flexible optional no deadline no urgency',       // 0 None
    'minor errand routine task low importance not urgent can be deferred', // 1 Low
    'regular work meeting scheduled appointment important should not miss', // 2 Medium
    'critical deadline urgent must complete immediately high stakes essential', // 3 High
  ];
  static List<List<double>>? _priorityAnchors;

  // ── Initialization state ───────────────────────────────────────────────────
  static bool _initialized = false;

  /// Whether the AI stack (model + index) is fully ready.
  static bool get isReady => _initialized;

  // ── Getters ────────────────────────────────────────────────────────────────

  static DateParser get dateParser => _dateParser;
  static DateLocalePreference get dateLocalePreference => _dateLocalePreference;
  static EmbeddingService get embedding => _embedding;
  static VectorIndex get vectorIndex => _hnswIndex;
  static SmartCategoryMatcher get matcher => _hybridMatcher;
  static HybridMatcher get hybridMatcher => _hybridMatcher;

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  /// Initialise the AI stack.  Call once in main() after
  /// WidgetsFlutterBinding.ensureInitialized() and before runApp().
  ///
  /// On web: loads the HNSW index from SharedPreferences (fast).
  /// On native: additionally initialises the ONNX embedding model (~1-3 s on
  ///   first launch while the model asset is copied; instant thereafter).
  static Future<void> init() async {
    if (_initialized) return;

    // Load persisted HNSW index state from SharedPreferences.
    await _hnswIndex.load();

    // Initialise the embedding model.
    //
    // iOS/macOS: OnnxEmbeddingService — uses the bundled all-MiniLM-L6-v2.onnx
    //   model via flutter_onnxruntime.
    //
    // Android: TFLiteEmbeddingService — uses the same model in TFLite format
    //   (all-MiniLM-L6-v2.tflite) via tflite_flutter. The ONNX runtime's JNI
    //   layer causes an unrecoverable SIGSEGV on Android during session.run();
    //   TFLite's Android runtime is Google-maintained and stable.
    //
    // Web: NullEmbeddingService (no ML runtime available in browser).
    if (!kIsWeb) {
      if (Platform.isAndroid) {
        try {
          final tflite = TFLiteEmbeddingService();
          await tflite.init();
          _embedding = tflite;
        } catch (e, st) {
          // ignore: avoid_print
          print('[AIServices] TFLite init failed — falling back to keyword matching: $e\n$st');
          _embedding = _nullEmbedding;
        }
      } else {
        try {
          final onnx = OnnxEmbeddingService();
          await onnx.init();
          _embedding = onnx;
        } catch (e, st) {
          // ignore: avoid_print
          print('[AIServices] ONNX init failed — falling back to keyword matching: $e\n$st');
          _embedding = _nullEmbedding;
        }
      }
    }

    // Embed the priority anchors now that the model is loaded.
    // Runs after the model init block so _embedding is already set.
    await _initPriorityAnchors();

    _initialized = true;
  }

  /// Embed the four priority anchor texts.  Safe to call when _embedding is
  /// NullEmbeddingService — all-zero vectors will simply all tie at similarity
  /// 0.0 and classifyPriority will return 0 (None) for every event.
  static Future<void> _initPriorityAnchors() async {
    try {
      _priorityAnchors = await Future.wait(
        _kPriorityAnchorTexts.map((t) => _embedding.embed(t)),
      );
    } catch (_) {
      _priorityAnchors = null;
    }
  }

  /// Classify the priority of an already-embedded event (0=None … 3=High).
  /// Uses the event vector stored in the HNSW index and compares it against the
  /// four anchor vectors via cosine similarity (= dot product on L2-normalised
  /// vectors).  Returns 0 when anchors or the event vector are unavailable.
  static int classifyPriority(String eventId) {
    final anchors = _priorityAnchors;
    final vec = getEventVector(eventId);
    if (anchors == null || anchors.length < 4 || vec == null || vec.isEmpty) {
      return 0;
    }
    double bestScore = -2.0;
    int bestIdx = 0;
    for (int i = 0; i < anchors.length; i++) {
      final anchor = anchors[i];
      double dot = 0.0;
      final len = vec.length < anchor.length ? vec.length : anchor.length;
      for (int j = 0; j < len; j++) dot += vec[j] * anchor[j];
      if (dot > bestScore) {
        bestScore = dot;
        bestIdx = i;
      }
    }
    return bestIdx;
  }

  // ── Phase 2 swap points (for future model upgrades) ───────────────────────

  static void setDateParser(DateParser p) {
    _dateParser = p;
    if (p is RuleBasedDateParser) {
      p.localePreference = _dateLocalePreference;
    }
  }

  /// Update the shared preference used by normal app parsing flows.
  ///
  /// Callers can still pass a one-off [DateLocalePreference] to
  /// [DateParser.parse] when they need to override the app setting.
  static void setDateLocalePreference(DateLocalePreference preference) {
    _dateLocalePreference = preference;
    final parser = _dateParser;
    if (parser is RuleBasedDateParser) {
      parser.localePreference = preference;
    }
  }
  static void setEmbedding(EmbeddingService s) => _embedding = s;
  static void setMatcher(SmartCategoryMatcher m) {
    // HybridMatcher is wired internally; this exists for test injection only.
  }
  static void setVectorIndex(VectorIndex i) {
    // HnswVectorIndex is the concrete type; this exists for test injection.
  }

  // ── Embedding helpers ──────────────────────────────────────────────────────

  /// Evict a cached parsed rule so it is re-parsed on the next call to
  /// [parseAndRegisterRule].  Call this before re-parsing whenever the user
  /// edits a Smart Category's rule string, so the old Gemini result is not
  /// served if the user later reverts to the previous text.
  static void evictRule(String rule) => SmartRuleParser.evict(rule);

  /// Parse a Smart Category's rule string with Gemini and register the
  /// structured result in the matcher for improved compound-rule matching.
  ///
  /// Fire-and-forget safe; never throws.  Falls back to simple regex
  /// extraction automatically if Gemini is unavailable.
  static Future<void> parseAndRegisterRule(String rule) async {
    if (rule.trim().isEmpty) return;
    try {
      final parsed = await SmartRuleParser.parse(rule);
      _hybridMatcher.setParsedRule(rule, parsed);
    } catch (_) {}
  }

  /// Embed a Smart Category's description and register it for matching.
  /// Fire-and-forget safe; never throws.
  static Future<void> embedCategory(
    String categoryName,
    String description,
  ) async {
    if (description.trim().isEmpty) return;
    try {
      final vec = await _embedding.embed(description);
      _hybridMatcher.setCategoryEmbedding(categoryName, vec);
    } catch (_) {}
  }

  /// Embed an event and register it in both the vector index and the matcher.
  /// Returns true if embedding and index persistence both succeeded, false
  /// otherwise.  Callers should only persist the embedding version on true so
  /// a transient failure (model not yet ready, I/O error) forces a retry on
  /// the next startup rather than permanently marking the event as current.
  static Future<bool> embedEvent(String eventId, String text) async {
    if (text.trim().isEmpty) return false;
    try {
      final vec = await _embedding.embed(text);
      await _hnswIndex.upsert(eventId, vec);
      _hybridMatcher.setEventEmbedding(eventId, vec);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Return the stored embedding vector for [eventId], or null if not indexed.
  /// Used by EventPipeline to warm up the HybridMatcher on startup without
  /// re-embedding events already at the current text-builder version.
  static List<double>? getEventVector(String eventId) =>
      _hnswIndex.getVector(eventId);

  /// Remove an event from the vector index and matcher.
  static Future<void> removeEvent(String eventId) async {
    try {
      await _hnswIndex.remove(eventId);
      _hybridMatcher.removeEventEmbedding(eventId);
    } catch (_) {}
  }
}

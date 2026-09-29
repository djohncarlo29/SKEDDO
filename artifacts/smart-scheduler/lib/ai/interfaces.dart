import 'parsed_date.dart';
import '../services/event_model.dart';

// ─────────────────────────────────────────────────────────────────────────────
// DateParser
//
// Converts a free-text date/time string into a structured ParsedDate.
//
// Phase 1 implementation: RuleBasedDateParser (pure Dart, no model).
// Phase 2 implementation: ChronoDateParser (chrono_dart or equivalent).
//
// All business logic depends only on this interface — swapping
// implementations requires no changes outside AIServices.
// ─────────────────────────────────────────────────────────────────────────────
abstract class DateParser {
  /// Parse [input] relative to [now] (defaults to DateTime.now() when null).
  ParsedDate parse(
    String input, {
    DateTime? now,
    DateLocalePreference? localePreference,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// EmbeddingService
//
// Converts text to a dense float vector.
//
// Phase 1 implementation: NullEmbeddingService (zero vectors — pipeline
//   runs end-to-end with no model loaded).
// Phase 2 implementation: OnnxEmbeddingService (Nomic Embed Text or MiniLM,
//   quantized, running in a background isolate).
// ─────────────────────────────────────────────────────────────────────────────
abstract class EmbeddingService {
  /// Dimensionality of all vectors produced by this service.
  int get dimensions;

  /// Embed [text] and return a float vector of exactly [dimensions] elements.
  Future<List<double>> embed(String text);
}

// ─────────────────────────────────────────────────────────────────────────────
// VectorIndex
//
// Stores and queries high-dimensional float embeddings.
//
// Phase 1 implementation: FlatVectorIndex (brute-force cosine, in-memory).
// Phase 2 implementation: HnswVectorIndex (HNSW graph, persisted to SQLite).
// ─────────────────────────────────────────────────────────────────────────────
class VectorSearchResult {
  final String id;
  final double score;

  const VectorSearchResult(this.id, this.score);
}

abstract class VectorIndex {
  /// Add or update the embedding for [id].
  Future<void> upsert(String id, List<double> embedding);

  /// Remove the embedding for [id].
  Future<void> remove(String id);

  /// Return the [topK] nearest neighbor ids to [query], closest first.
  Future<List<String>> nearest(List<double> query, {int topK = 10});

  /// Return nearest neighbors with their cosine-similarity scores.
  ///
  /// Unlike [nearest], callers can reject weak nearest neighbors instead of
  /// treating the best available item as relevant by definition.
  Future<List<VectorSearchResult>> nearestScored(
    List<double> query, {
    int topK = 10,
  });

  /// Remove all stored embeddings.
  Future<void> clear();
}

// ─────────────────────────────────────────────────────────────────────────────
// SmartCategoryMatcher
//
// Scores events against a Smart Category rule and returns matching events
// in ranked order.
//
// Phase 1 implementation: DeterministicMatcher (keyword + date metadata).
// Phase 2 implementation: HybridMatcher (vector cosine + date metadata).
// ─────────────────────────────────────────────────────────────────────────────
abstract class SmartCategoryMatcher {
  /// Changes whenever category or event matching data is registered or
  /// removed.  Consumers can use this to invalidate derived count caches when
  /// asynchronous embedding work changes the match result without changing
  /// the candidate event list.
  int get revision => 0;

  /// Return events from [candidates] that match [rule], ranked by relevance.
  ///
  /// [builtInLabel] identifies built-in smart tiles ('Today', 'Tomorrow',
  /// 'This Week', etc.) so the matcher can apply date-range filtering rather
  /// than keyword extraction.  Pass null for user-created Smart Categories.
  List<ScheduledEvent> match({
    required List<ScheduledEvent> candidates,
    required String rule,
    String? builtInLabel,

    /// For user Smart Categories, pass the category name so the matcher can
    /// look up the stored embedding (which is keyed by name, not by rule text).
    String? categoryName,
    DateTime? now,
  });
}

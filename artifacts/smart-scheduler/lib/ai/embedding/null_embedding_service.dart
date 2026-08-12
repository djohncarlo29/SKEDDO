import '../interfaces.dart';

// ─────────────────────────────────────────────────────────────────────────────
// NullEmbeddingService — Phase 1 stub.
//
// Returns a zero vector for every input.  The event processing pipeline
// runs end-to-end without any model, and Phase 2 can swap this out with
// an ONNX-backed implementation without touching any other code.
// ─────────────────────────────────────────────────────────────────────────────
class NullEmbeddingService implements EmbeddingService {
  const NullEmbeddingService();

  /// Matches the dimension of Nomic Embed Text v1.5 / all-MiniLM-L6-v2
  /// so Phase 2 can store real embeddings without a schema migration.
  @override
  int get dimensions => 384;

  @override
  Future<List<double>> embed(String text) async => List.filled(dimensions, 0.0);
}

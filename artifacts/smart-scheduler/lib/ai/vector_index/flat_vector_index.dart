import 'dart:math' show sqrt;
import '../interfaces.dart';

// ─────────────────────────────────────────────────────────────────────────────
// FlatVectorIndex — Phase 1 stub.
//
// Brute-force cosine-similarity nearest-neighbor search across all stored
// embeddings.  Correct and adequate at small scale (≤ a few thousand events).
// Phase 2 swaps this for an HNSW implementation without changing any callers.
// ─────────────────────────────────────────────────────────────────────────────
class FlatVectorIndex implements VectorIndex {
  final _store = <String, List<double>>{};

  @override
  Future<void> upsert(String id, List<double> embedding) async {
    _store[id] = List.unmodifiable(embedding);
  }

  @override
  Future<void> remove(String id) async => _store.remove(id);

  @override
  Future<void> clear() async => _store.clear();

  @override
  Future<List<String>> nearest(List<double> query, {int topK = 10}) async {
    final scored = await nearestScored(query, topK: topK);
    return scored.map((result) => result.id).toList();
  }

  @override
  Future<List<VectorSearchResult>> nearestScored(
    List<double> query, {
    int topK = 10,
  }) async {
    if (_store.isEmpty) return [];

    final qNorm = _norm(query);
    if (qNorm == 0.0) return [];

    // Score every stored vector by cosine similarity.
    final scores = <VectorSearchResult>[];
    for (final entry in _store.entries) {
      final dot = _dot(query, entry.value);
      final vNorm = _norm(entry.value);
      if (vNorm == 0.0) continue;
      scores.add(VectorSearchResult(entry.key, dot / (qNorm * vNorm)));
    }

    scores.sort((a, b) => b.score.compareTo(a.score));
    return scores.take(topK).toList();
  }

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
}

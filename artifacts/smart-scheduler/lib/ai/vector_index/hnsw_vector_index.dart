import 'dart:convert';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import '../interfaces.dart';

// ─────────────────────────────────────────────────────────────────────────────
// HnswVectorIndex — Phase 2 approximate-nearest-neighbor index.
//
// Implements a minimal Hierarchical Navigable Small World (HNSW) graph:
//   • Probabilistic multi-layer structure (M neighbours per node per layer).
//   • Greedy best-first search from the top layer downwards.
//   • Falls back to brute-force for < 500 entries (always correct, fast).
//   • Persisted to SharedPreferences as a JSON blob; deserialized on startup.
//
// Parameters tuned for all-MiniLM-L6-v2 (384-d embeddings):
//   M = 16, efConstruction = 100, ef = 50
// ─────────────────────────────────────────────────────────────────────────────

/// A (distance, id) pair used in sorted candidate / result sets.
class _Candidate implements Comparable<_Candidate> {
  final double dist;
  final String id;
  _Candidate(this.dist, this.id);
  @override
  int compareTo(_Candidate other) {
    final c = dist.compareTo(other.dist);
    return c != 0 ? c : id.compareTo(other.id);
  }
}

class HnswVectorIndex implements VectorIndex {
  // ── HNSW hyper-parameters ──────────────────────────────────────────────────
  static const int _m = 16;
  static const int _mMax0 = 32; // layer-0 max (2×M)
  static const int _efConstruction = 100;
  static const int _ef = 50;

  static const int _flatFallbackThreshold = 500;
  static const String _kPrefsKey = 'skeddo_hnsw_v1';

  // ── Internal state ─────────────────────────────────────────────────────────
  final _vectors = <String, List<double>>{};
  // _graph[id] = list of layers; each layer = list of neighbour ids
  final _graph = <String, List<List<String>>>{};
  int _maxLayer = -1;
  String? _entryPoint;
  final _rng = Random();

  bool get _useBrute => _vectors.length < _flatFallbackThreshold;

  // ── Extra accessors ────────────────────────────────────────────────────────

  /// Return the stored embedding for [id], or null if not indexed.
  /// Used by EventPipeline to warm up the HybridMatcher on startup without
  /// re-embedding events that are already at the current text-builder version.
  List<double>? getVector(String id) => _vectors[id];

  // ── VectorIndex interface ──────────────────────────────────────────────────

  @override
  Future<void> upsert(String id, List<double> embedding) async {
    if (_vectors.containsKey(id)) await remove(id);
    _vectors[id] = List.unmodifiable(embedding);

    final level = _randomLevel();
    _graph[id] = List.generate(level + 1, (_) => <String>[]);

    if (_entryPoint == null || _useBrute) {
      if (_maxLayer < level) _maxLayer = level;
      _entryPoint ??= id;
      await _persist();
      return;
    }

    if (level > _maxLayer) _maxLayer = level;

    // Descend from top to level+1 (greedy ef=1) to find the entry point.
    var ep = _entryPoint!;
    for (var lc = _maxLayer; lc > level; lc--) {
      final res = _searchLayer([ep], embedding, 1, lc);
      if (res.isNotEmpty) ep = res.first.id;
    }

    // Insert from node's highest layer down to 0.
    for (var lc = min(level, _maxLayer); lc >= 0; lc--) {
      final mMax = lc == 0 ? _mMax0 : _m;
      final candidates = _searchLayer([ep], embedding, _efConstruction, lc);
      final neighbors = _selectNeighbors(id, candidates, mMax, embedding);
      _graph[id]![lc] = neighbors.map((c) => c.id).toList();
      for (final nb in neighbors) {
        final nbLayers = _graph[nb.id];
        if (nbLayers == null || lc >= nbLayers.length) continue;
        nbLayers[lc].add(id);
        if (nbLayers[lc].length > mMax) {
          final nbVec = _vectors[nb.id];
          if (nbVec != null) {
            final pruned = _selectNeighborIds(nb.id, nbLayers[lc], mMax, nbVec);
            nbLayers[lc]
              ..clear()
              ..addAll(pruned);
          }
        }
      }
      if (candidates.isNotEmpty) ep = candidates.first.id;
    }

    if (level > _maxLayer) {
      _maxLayer = level;
      _entryPoint = id;
    }

    await _persist();
  }

  @override
  Future<void> remove(String id) async {
    _vectors.remove(id);
    _graph.remove(id);
    for (final layers in _graph.values) {
      for (final layer in layers) {
        layer.remove(id);
      }
    }
    if (_entryPoint == id) {
      _entryPoint = _vectors.isEmpty ? null : _vectors.keys.first;
    }
    await _persist();
  }

  @override
  Future<void> clear() async {
    _vectors.clear();
    _graph.clear();
    _maxLayer = -1;
    _entryPoint = null;
    await _persist();
  }

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
    if (_vectors.isEmpty) return [];
    if (_useBrute) return _bruteNearestScored(query, topK);

    var ep = _entryPoint!;
    for (var lc = _maxLayer; lc > 0; lc--) {
      final res = _searchLayer([ep], query, 1, lc);
      if (res.isNotEmpty) ep = res.first.id;
    }
    final res = _searchLayer([ep], query, _ef, 0);
    return res
        .take(topK)
        .map(
          (candidate) => VectorSearchResult(candidate.id, 1.0 - candidate.dist),
        )
        .toList();
  }

  // ── HNSW core ─────────────────────────────────────────────────────────────

  /// Greedy best-first beam search at [layer], returns candidates sorted
  /// closest-first.
  List<_Candidate> _searchLayer(
    List<String> entryPoints,
    List<double> query,
    int ef,
    int layer,
  ) {
    final visited = <String>{};
    // Sorted lists: smallest distance first.
    final candidates = <_Candidate>[]; // candidates to expand
    final results = <_Candidate>[]; // best ef results so far

    void addCandidate(_Candidate c) {
      // Insert sorted.
      int lo = 0, hi = candidates.length;
      while (lo < hi) {
        final mid = (lo + hi) >> 1;
        if (candidates[mid].compareTo(c) <= 0)
          lo = mid + 1;
        else
          hi = mid;
      }
      candidates.insert(lo, c);
    }

    void addResult(_Candidate c) {
      int lo = 0, hi = results.length;
      while (lo < hi) {
        final mid = (lo + hi) >> 1;
        if (results[mid].compareTo(c) <= 0)
          lo = mid + 1;
        else
          hi = mid;
      }
      results.insert(lo, c);
      if (results.length > ef) results.removeLast();
    }

    for (final ep in entryPoints) {
      if (!_vectors.containsKey(ep)) continue;
      final d = _dist(query, _vectors[ep]!);
      final c = _Candidate(d, ep);
      addCandidate(c);
      addResult(c);
      visited.add(ep);
    }

    while (candidates.isNotEmpty) {
      final c = candidates.removeAt(0);
      final wDist = results.isEmpty ? double.infinity : results.last.dist;
      if (c.dist > wDist && results.length >= ef) break;

      final nbLayers = _graph[c.id];
      if (nbLayers == null || layer >= nbLayers.length) continue;
      for (final nbId in nbLayers[layer]) {
        if (visited.contains(nbId)) continue;
        visited.add(nbId);
        final nbVec = _vectors[nbId];
        if (nbVec == null) continue;
        final d = _dist(query, nbVec);
        final wDist2 = results.isEmpty ? double.infinity : results.last.dist;
        if (d < wDist2 || results.length < ef) {
          addCandidate(_Candidate(d, nbId));
          addResult(_Candidate(d, nbId));
        }
      }
    }
    return results;
  }

  List<_Candidate> _selectNeighbors(
    String id,
    List<_Candidate> candidates,
    int mMax,
    List<double> queryVec,
  ) {
    final filtered = candidates
        .where((c) => c.id != id && _vectors.containsKey(c.id))
        .toList();
    if (filtered.length <= mMax) return filtered;
    return filtered.sublist(0, mMax);
  }

  List<String> _selectNeighborIds(
    String id,
    List<String> nbIds,
    int mMax,
    List<double> nbVec,
  ) {
    final scored =
        nbIds
            .where((nid) => nid != id && _vectors.containsKey(nid))
            .map((nid) => _Candidate(_dist(nbVec, _vectors[nid]!), nid))
            .toList()
          ..sort();
    return scored.take(mMax).map((c) => c.id).toList();
  }

  int _randomLevel() {
    var level = 0;
    while (_rng.nextDouble() < 1.0 / _m && level < 16) {
      level++;
    }
    return level;
  }

  // ── Brute-force fallback ───────────────────────────────────────────────────

  List<VectorSearchResult> _bruteNearestScored(List<double> query, int topK) {
    final qNorm = _norm(query);
    if (qNorm == 0) return [];
    final scored = _vectors.entries.map((e) {
      final vNorm = _norm(e.value);
      if (vNorm == 0) return VectorSearchResult(e.key, 0.0);
      return VectorSearchResult(e.key, _dot(query, e.value) / (qNorm * vNorm));
    }).toList()..sort((a, b) => b.score.compareTo(a.score));
    return scored.take(topK).toList();
  }

  // ── Math ───────────────────────────────────────────────────────────────────

  static double _dist(List<double> a, List<double> b) {
    final aN = _norm(a), bN = _norm(b);
    if (aN == 0 || bN == 0) return 1.0;
    return 1.0 - _dot(a, b) / (aN * bN);
  }

  static double _dot(List<double> a, List<double> b) {
    var s = 0.0;
    final len = min(a.length, b.length);
    for (var i = 0; i < len; i++) {
      s += a[i] * b[i];
    }
    return s;
  }

  static double _norm(List<double> v) {
    var s = 0.0;
    for (final x in v) {
      s += x * x;
    }
    return sqrt(s);
  }

  // ── Persistence ────────────────────────────────────────────────────────────

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _kPrefsKey,
        jsonEncode({
          'vectors': _vectors,
          'graph': _graph.map((k, v) => MapEntry(k, v.map((l) => l).toList())),
          'maxLayer': _maxLayer,
          'entryPoint': _entryPoint,
        }),
      );
    } catch (_) {}
  }

  /// Load state from SharedPreferences. Call once at startup.
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kPrefsKey);
      if (raw == null) return;
      final j = jsonDecode(raw) as Map<String, dynamic>;

      final vecs = j['vectors'] as Map<String, dynamic>;
      for (final e in vecs.entries) {
        _vectors[e.key] = (e.value as List).cast<double>();
      }

      final graph = j['graph'] as Map<String, dynamic>;
      for (final e in graph.entries) {
        _graph[e.key] = (e.value as List)
            .map((layer) => (layer as List).cast<String>())
            .toList();
      }

      _maxLayer = (j['maxLayer'] as int?) ?? -1;
      _entryPoint = j['entryPoint'] as String?;
    } catch (_) {
      _vectors.clear();
      _graph.clear();
      _maxLayer = -1;
      _entryPoint = null;
    }
  }
}

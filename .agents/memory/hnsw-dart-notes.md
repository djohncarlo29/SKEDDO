---
name: HNSW Dart implementation notes
description: Pitfalls when implementing HNSW in Dart for Smart Scheduler.
---

## Key constraints

- `SplayTreeMap` from `dart:collection` triggers "method not defined" errors in the Flutter test runner even when the import is present — use a sorted `List<_Candidate>` (implements `Comparable`) instead. Much simpler and identical performance for index sizes < 500.
- `_graph[id]` is `List<List<String>>?` (nullable map lookup) — always check non-null before indexing with `!` or `??`.
- Brute-force path activates for `< 500 entries`; no HNSW graph traversal at that scale.
- `_Candidate` class with `Comparable` keeps the sorted-list code minimal and clearly expressed.

**Why:** SplayTreeMap from dart:collection compiles fine in the main app but fails in the test runner on Flutter 3.35.7 / Dart 3.8.x with a confusing "method not defined" message. Sorted List is the safe fallback.

**How to apply:** If re-implementing or extending the HNSW index, avoid SplayTreeMap; use sorted List insertion instead.

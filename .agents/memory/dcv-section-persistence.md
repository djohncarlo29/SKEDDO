---
name: DCV section persistence
description: Why Detailed Category View section edits must stay in memory and serialize their preference writes.
---

Detailed Category View section state is authoritative in the live Events tab. Do
not reload section maps from SharedPreferences during EventStore refreshes, and
serialize category saves from snapshots so older asynchronous writes cannot
overwrite a newly created or deleted section.

**Why:** Event-store notifications can arrive while a section edit is in
progress. Re-reading preferences at that point replaces valid in-memory edits
with stale data, while overlapping writes can persist the wrong snapshot.

**How to apply:** Update the live section maps first, snapshot them with the
other category state, and enqueue the complete preference write in mutation
order.
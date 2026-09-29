---
name: Smart Category count cache invalidation
description: How to keep user-created Smart Category tile counts synchronized with asynchronous matcher updates.
---

User-created Smart Category counts are derived data, not stored category metadata. The candidate event list can remain unchanged while the asynchronous matcher registers a new event embedding, category embedding, or parsed rule; that can change the match result without triggering an event-list identity change.

**Why:** A detail view that runs the matcher directly can show a newly matching event while a tile count cache still serves the earlier result.

**How to apply:** Any cached Smart Category count must invalidate on both event-list changes and matcher-state changes. Prefer a monotonic matcher revision (incremented when embeddings or parsed rules are registered/removed) as part of the cache key, plus explicit event-derived-cache clearing in the event-store listener for in-place notifications.
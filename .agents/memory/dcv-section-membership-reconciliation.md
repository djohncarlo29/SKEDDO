---
name: DCV section membership reconciliation
description: Keep newly-created Detailed Category View events attached to their logical section when section headers are reordered.
---

The Detailed Category View can assign a newly visible event to the first section locally before the parent-side persisted membership map has received that event ID. Before applying a section-header permutation, reconcile every currently visible but unassigned event into the current first section, then move names and event-ID lists together.

**Why:** Reordering from the stale parent map treats the new event as unassigned and the normalizer places it into whichever section becomes first, changing its logical section.

**How to apply:** Any path that reorders or deletes custom DCV sections must repair missing visible event IDs before transforming section indexes. Keep the event filter aligned with the DCV's actual built-in, smart-category, and standard-category filtering.
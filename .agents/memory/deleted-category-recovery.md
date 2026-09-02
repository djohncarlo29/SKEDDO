---
name: Deleted category recovery
description: Product rule for event placement when a deleted user category is recovered.
---

Recovering a deleted user category restores its saved section layout and any still-deleted events that were removed with that category. Events already recovered individually or reassigned by a category-only action stay where they are.

**Why:** Category-and-content deletion is a recoverable bundle; silently separating its events defeats the action label. Category-only deletion remains intentionally non-destructive to events.

**How to apply:** Preserve the original category ID on deleted event snapshots. Restore bundle events with the category, but restore individually recovered events to the current default. Permanent deletion removes remaining bundled snapshots.
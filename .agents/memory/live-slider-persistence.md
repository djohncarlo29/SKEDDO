---
name: Live slider persistence
description: Persistence rules for sliders whose live drag updates the same notifier used by their release callback.
---

When a slider updates its setting continuously during a drag, the release handler must persist unconditionally (or compare against the persisted value), not skip the write because the notifier already equals the snapped value.

**Why:** The live preview commonly reaches the final snapped value before the release callback. An equality guard against the in-memory notifier then suppresses the only persistence write, causing restart to restore an older value.

**How to apply:** Keep live preview updates separate from persistence. On gesture completion, normalize the final value, update the notifier if needed, and always enqueue a write of that exact normalized value.
---
name: AI cold-start embeddings
description: Preserve event embedding correctness while the local model initializes asynchronously after the first frame.
---

Do not persist or mark event embeddings current before `AIServices` finishes initialization. Return failure while only the null embedding service is available, then schedule the background event pass after initialization completes.

**Why:** Placeholder vectors can be persisted as if they were valid and then skipped by the version-based re-embedding pass, even after the real model loads.

**How to apply:** Keep model loading off the UI startup path, make early event create/update hooks retryable, and run a re-embedding pass after the model and stored events are both ready.

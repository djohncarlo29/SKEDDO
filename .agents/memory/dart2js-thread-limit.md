---
name: Dart2JS thread-limit retry
description: Flutter web release compilation can fail transiently when the container cannot create another Dart worker thread.
---

When Flutter web compilation fails with `Could not start thread DartWorker: 11`, treat it as a temporary resource-limit failure rather than a Dart source error.

**Why:** The managed preview workflow may hit the container thread limit during dart2js even when the same source compiles successfully on a subsequent run.

**How to apply:** Inspect the compiler output for the exact worker-thread message, retry the Flutter web build/workflow, and only investigate source changes if the retry reports a real analyzer or compiler diagnostic.
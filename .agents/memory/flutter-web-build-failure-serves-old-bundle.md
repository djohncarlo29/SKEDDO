---
name: Flutter web build failure serves old bundle
description: The Smart Scheduler web server can start even when flutter build web fails, leaving the previous compiled bundle visible.
---

The preview server must be treated as stale when the preceding Flutter web compilation fails; a successful server start does not prove the current Dart source was deployed.

**Why:** The development start script builds first but still launches the static server after a failed build, so preview behavior can reflect an older bundle and obscure the real compiler error.

**How to apply:** After Dart changes, inspect the workflow log for the explicit `Built build/web` line before diagnosing the rendered UI. Fix compilation errors and restart the managed workflow before taking a preview snapshot.
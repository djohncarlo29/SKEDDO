---
name: Shorebird release build verification
description: Distinguishes successful Android artifact creation from Shorebird release registration failures.
---

A Shorebird release command can successfully compile the AAB/APK and then fail during release registration when that version already exists. The generated artifact is still usable for direct device testing, but it is not evidence that a new Shorebird release was created.

**Why:** A duplicate version error after compilation can make a current source change appear absent if testing continues on the previously installed APK.

**How to apply:** Check for the generated APK/AAB immediately after the build step. If release registration reports an existing version, deliver or install the generated artifact for validation rather than assuming the build failed.
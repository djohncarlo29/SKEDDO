---
name: Pinned Flutter Dart tool path
description: The pinned Flutter executable is a wrapper; use its sibling cache SDK path for standalone Dart CLI commands.
---

The pinned Flutter command and the bundled Dart CLI are separate paths: standalone commands such as formatting use the SDK's `bin/cache/dart-sdk/bin/dart`, not a `dart` directory beneath the Flutter executable.

**Why:** The workspace's Flutter entry point is an executable, so appending `bin/cache/...` to that path produces a non-directory path and fails before Dart runs.

**How to apply:** For Dart-only maintenance commands, derive the path from the Flutter SDK directory (the parent of the Flutter executable), or use the known SDK cache path directly.
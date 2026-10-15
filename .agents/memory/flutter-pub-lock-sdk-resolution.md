---
name: Pinned Flutter dependency resolution
description: How the managed Flutter preview's pinned SDK affects transitive lockfile versions
---

The managed Flutter preview runs dependency resolution with the pinned Flutter 3.35.7 / Dart 3.9.2 toolchain before compiling. A lockfile produced by a newer Dart SDK can be rewritten to compatible transitive versions and SDK metadata.

**Why:** The preview's actual dependency resolution depends on its pinned SDK, so restoring newer locked transitive packages can make the workspace inconsistent with the toolchain.

**How to apply:** After restarting the Flutter preview, inspect any `pubspec.lock` changes in the context of the pinned SDK. Keep the solver-produced lock when it resolves cleanly; do not hand-edit package hashes.

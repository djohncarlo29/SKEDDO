---
name: Flutter web preview builds
description: Restart and compile checks for the managed Flutter web preview.
---

Restart the managed preview after Dart changes because compiled web bundles do not hot-reload. A failed compile can still leave the server running and serving the previous bundle, so check for a successful build before trusting the preview.

**Why:** A live port only proves that the static server started; it does not prove that it serves the latest Dart code.

**How to apply:** Follow the focused notes for [rebuilding the preview](flutter-web-preview-rebuild.md) and [detecting stale bundles](flutter-web-build-failure-serves-old-bundle.md).

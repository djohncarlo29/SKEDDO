---
name: Flutter web preview builds
description: Restart and compile checks for the managed Flutter web preview.
---

Restart the managed preview after Dart changes because compiled web bundles do not hot-reload. A failed compile can still leave the server running and serving the previous bundle, so check for a successful build before trusting the preview.

**Why:** A live port only proves that the static server started; it does not prove that it serves the latest Dart code. On a cold cache, standalone `flutter pub get` can exceed the shell time limit before dependency downloads finish. Flutter 3.44 also performs a WebAssembly dry-run during JS-only builds unless disabled, which can consume the preview startup window without changing the CanvasKit output.

**How to apply:** Restart the managed preview to resolve dependencies and compile in one tracked run; if standalone package fetching times out, do not repeat it before checking the workflow. For a JS/CanvasKit-only preview on Flutter 3.44, disable the unused Wasm dry-run. Follow the focused notes for [rebuilding the preview](flutter-web-preview-rebuild.md) and [detecting stale bundles](flutter-web-build-failure-serves-old-bundle.md).

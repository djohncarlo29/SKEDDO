---
name: Pinned Flutter Dart tool path
description: The pinned Flutter executable is a wrapper; use its sibling cache SDK path for standalone Dart CLI commands.
---

The pinned Flutter command and the bundled Dart CLI are separate paths: standalone commands such as formatting use the SDK's `bin/cache/dart-sdk/bin/dart`, not a `dart` directory beneath the Flutter executable. Set `PUB_CACHE=/home/runner/workspace/.cache/pub-cache` when running CLI tools so the package config resolves the workspace cache rather than the unavailable `/home/runner/.pub-cache`.

**Why:** The workspace's Flutter entry point is an executable, so appending `bin/cache/...` to that path produces a non-directory path and fails before Dart runs. The project package config can also point at the default home cache even though dependencies are stored under the workspace cache.

**How to apply:** For Dart-only maintenance commands, derive the path from the Flutter SDK directory (the parent of the Flutter executable), or use the known SDK cache path directly and set `PUB_CACHE`. For project analysis/build checks, invoke the pinned workspace Flutter SDK rather than the older global wrapper, or dependency resolution can select an incompatible Dart version.

## Test SDK matching

When `.dart_tool/package_config.json` points `flutter_test` at a Shorebird-cached Flutter SDK, run tests with that SDK's matching `bin/flutter` and `--no-pub`; the older Flutter 3.35.7 wrapper uses Dart 3.9 and cannot parse test sources marked for Dart 3.10.

**Why:** A stale or independently generated package config can pair newer Flutter test sources with the older wrapper's compiler, producing framework-wide language-version errors before project tests run.

**How to apply:** If `flutter test --no-pub` reports a Flutter SDK language-version mismatch, inspect the `flutter_test` `rootUri` in `.dart_tool/package_config.json` and use the matching cached Flutter SDK for tests. Keep the managed app workflow on its configured SDK.

## Test viewport dimensions

When a widget test uses `tester.binding.setSurfaceSize`, the Shorebird test SDK may still expose the default `MediaQuery.size` to route code. Tests whose geometry depends on viewport height should explicitly set `MediaQueryData.size` to the test surface size.

**Why:** A sheet transition used the default 600px MediaQuery height while its test surface was 700px high, so a safe-area ratio produced a rendered top offset larger than the expected physical gap.

**How to apply:** In the test app builder, copy the inherited MediaQuery with `size` set to the same dimensions passed to `setSurfaceSize`, alongside any synthetic safe-area insets.
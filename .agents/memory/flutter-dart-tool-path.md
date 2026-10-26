---
name: Pinned Flutter Dart tool path
description: The pinned Flutter executable is a wrapper; use its sibling cache SDK path for standalone Dart CLI commands.
---

The pinned Flutter command and the bundled Dart CLI are separate paths: standalone commands such as formatting use the SDK's `bin/cache/dart-sdk/bin/dart`, not a `dart` directory beneath the Flutter executable. Set `PUB_CACHE=/home/runner/workspace/.cache/pub-cache` when running CLI tools so the package config resolves the workspace cache rather than the unavailable `/home/runner/.pub-cache`.

**Why:** The workspace's Flutter entry point is an executable, so appending `bin/cache/...` to that path produces a non-directory path and fails before Dart runs. The project package config can also point at the default home cache even though dependencies are stored under the workspace cache.

**How to apply:** For Dart-only maintenance commands, derive the path from the Flutter SDK directory (the parent of the Flutter executable), or use the known SDK cache path directly and set `PUB_CACHE`. For project analysis/build checks, invoke the pinned workspace Flutter SDK rather than the older global wrapper, or dependency resolution can select an incompatible Dart version.

## Test and dependency-resolution SDK matching

The ambient `flutter` command may be older than the SDK used by the managed artifact workflow. Use that workflow's cached SDK for project tests and dependency resolution. `--no-pub` still reads the existing `.dart_tool/package_config.json`, which may point at a different Flutter SDK.

**Why:** In one run, the ambient Flutter 3.29.3 wrapper generated package config for its SDK while the managed app used Flutter 3.44.2. Running the newer SDK with `--no-pub` then loaded framework sources from the stale config and failed before reaching project tests.

**How to apply:** When SDKs differ, invoke the managed SDK's `bin/flutter pub get` first, then run tests/analyze with the same SDK. Do not resolve with the ambient wrapper and switch SDKs only for the test command.

## Test viewport dimensions

When a widget test uses `tester.binding.setSurfaceSize`, the Shorebird test SDK may still expose the default `MediaQuery.size` to route code. Tests whose geometry depends on viewport height should explicitly set `MediaQueryData.size` to the test surface size.

**Why:** A sheet transition used the default 600px MediaQuery height while its test surface was 700px high, so a safe-area ratio produced a rendered top offset larger than the expected physical gap.

**How to apply:** In the test app builder, copy the inherited MediaQuery with `size` set to the same dimensions passed to `setSurfaceSize`, alongside any synthetic safe-area insets.
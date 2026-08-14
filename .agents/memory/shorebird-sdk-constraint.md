---
name: Shorebird SDK constraint and pub-cache patching
description: Shorebird Flutter 3.44.9 bundles Dart 3.12.x; app and cached dependency SDK constraints must allow the active local and Shorebird Dart toolchains.
---

## Rule
The app's `sdk:` constraint must have an upper bound below 4.0.0 and must include the active local toolchain; the current project uses `'>=3.9.0 <4.0.0'`. Shorebird's Flutter 3.44.9 uses Dart 3.12.2, so an upper bound such as `<3.10.0` blocks patching.

## Why
`cupertino_native 0.0.1` may ship with a narrower SDK constraint in the cache. If it blocks resolution after relaxing the app constraint, patch the cached pubspec at:

    /home/runner/workspace/.cache/pub-cache/hosted/pub.dev/cupertino_native-0.0.1/pubspec.yaml

Change its SDK constraint to a range covering the active local and Shorebird toolchains, such as `sdk: '>=3.9.0 <4.0.0'`.

## How to apply
After any `pubspec.yaml` SDK constraint change, verify with:
1. `flutter pub get` — must succeed
2. `flutter test` — must pass
3. Check that no OTHER cached package has a `^3.9.0` constraint blocking resolution

The pub-cache patch survives across builds in the Replit environment (cache is persistent) but must be re-applied if the cache is cleared.

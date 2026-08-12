---
name: Shorebird SDK constraint and pub-cache patching
description: Shorebird Flutter 3.44.9 bundles Dart 3.9.x; app pubspec and cached dependency pubspecs must allow >=3.8.0 <4.0.0 for local (Dart 3.8) and Shorebird (Dart 3.9) builds to both work.
---

## Rule
The app's `sdk:` constraint must be `'>=3.8.0 <4.0.0'` — NOT `^3.9.0`. Shorebird's bundled Flutter (3.44.9) uses Dart 3.9.x, while the local Replit Flutter (3.32.0) uses Dart 3.8.0. A constraint of `^3.9.0` causes local `flutter pub get` to fail; `>=3.8.0 <4.0.0` satisfies both.

## Why
`cupertino_native 0.0.1` also ships with `sdk: ^3.9.0` in its own pubspec. This blocks `pub get` even after relaxing the app constraint. Fix: directly patch the cached pubspec at:

    /home/runner/workspace/.cache/pub-cache/hosted/pub.dev/cupertino_native-0.0.1/pubspec.yaml

Change `sdk: ^3.9.0` → `sdk: '>=3.8.0 <4.0.0'` there.

## How to apply
After any `pubspec.yaml` SDK constraint change, verify with:
1. `flutter pub get` — must succeed
2. `flutter test` — must pass
3. Check that no OTHER cached package has a `^3.9.0` constraint blocking resolution

The pub-cache patch survives across builds in the Replit environment (cache is persistent) but must be re-applied if the cache is cleared.

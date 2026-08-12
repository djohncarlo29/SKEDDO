---
name: liquid_glass_widgets Android crash
description: liquid_glass_widgets shaders are incompatible with Android's Skia backend and crash the app at runtime.
---

`liquid_glass_widgets 0.5.0` includes a fragment shader (`liquid_glass_geometry_blended.frag`) that compiles to invalid SkSL:

```
error: initializers are not permitted on arrays (or structs containing arrays)
    float param_2[96] = shapeData;
```

Flutter prints a build warning `"This shader will not load when running with the Skia backend"` but the build still succeeds. At runtime on Android (which uses Skia by default), loading the shader crashes the app — manifesting as "shows UI for a few seconds then crashes."

**Critical:** Removing GlassSwitch from Dart code is NOT sufficient. The shaders are declared in the package's `pubspec.yaml` under `flutter.shaders` and are bundled into the APK regardless of whether any widget uses them. Android's Impeller renderer pre-compiles all bundled package shaders in the background after the first frame renders — an invalid shader causes a process crash milliseconds after the UI appears. Shorebird patches (Dart-only) cannot remove bundled shaders. The only fix is to **remove the package from `pubspec.yaml` entirely** and build a new release.

**Fix:** Remove `liquid_glass_widgets` from `pubspec.yaml` and create a new Shorebird release (bump version). The custom `_SlidingSwitch` in `lib/widgets/app_switch.dart` provides the same visual on Android without any shaders.

**Why:** iOS uses Impeller (not Skia) which handles the shader correctly. The liquid_glass package is intentionally kept for iOS only.

**How to apply:** Check `app_switch.dart` — the `_usesNativeControl` guard (iOS/macOS → CNSwitch, everything else → `_SlidingSwitch`) is the correct pattern. Never add `GlassSwitch` or other liquid_glass widgets outside the iOS/macOS branch.

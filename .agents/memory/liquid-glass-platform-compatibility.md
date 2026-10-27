---
name: Liquid Glass package boundary
description: Package version and platform-routing constraints for the app's Liquid Glass controls.
---

Keep `liquid_glass_easy` at 5.0.0. The app carries a local copy of that release with only slider visual-size reporting and edge-icon tracking added. App switches intentionally use the caller's accent/category color when on and `kTertiaryLabel` when off, while retaining package-default geometry, glass style, and renderer; use native iOS switch controls only on native iOS.

**Why:** The user wants app-specific accent/category track colors restored from the previous wrapper, but still wants the 5.0.0 switch's default dimensions, optics, and rendering behavior.

**How to apply:** Keep the color mapping in `AppSwitch`; do not patch package defaults. Check [native switch routing](cupertino-native-switch-package.md) and [Flutter/package version compatibility](liquid-glass-widgets-compatibility.md) before changing dependencies or platform branches.

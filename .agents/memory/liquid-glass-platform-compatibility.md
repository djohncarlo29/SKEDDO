---
name: Liquid Glass package boundary
description: Package version and platform-routing constraints for the app's Liquid Glass controls.
---

Use hosted `liquid_glass_easy` 5.0.0 untouched; keep app-specific styling outside that package and use native iOS switch controls only on native iOS.

**Why:** The user selected the package's unmodified 5.0.0 defaults for `LiquidGlassSwitch`, while the app still has separate product styling and native iOS behavior.

**How to apply:** Check the focused notes for [native switch routing](cupertino-native-switch-package.md), [Flutter/package version compatibility](liquid-glass-widgets-compatibility.md), and [upstream 5.0.0 defaults](liquid-glass-easy-fork-compatibility.md) before changing dependencies or platform branches.

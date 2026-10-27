---
name: Liquid Glass package boundary
description: Package version and platform-routing constraints for the app's Liquid Glass controls.
---

Keep `liquid_glass_easy` at 5.0.0. The app carries a local copy of that release with only slider visual-size reporting and edge-icon tracking added; keep switch defaults unchanged and use native iOS switch controls only on native iOS.

**Why:** The user wants the slider to remain on 5.0.0 while restoring its thumb-edge icon bounce, and separately requires `LiquidGlassSwitch` to retain untouched 5.0.0 defaults.

**How to apply:** Check the focused notes for [native switch routing](cupertino-native-switch-package.md), [Flutter/package version compatibility](liquid-glass-widgets-compatibility.md), and [upstream 5.0.0 defaults](liquid-glass-easy-fork-compatibility.md) before changing dependencies or platform branches.

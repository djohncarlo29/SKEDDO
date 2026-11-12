---
name: Liquid Glass package boundary
description: Package version and platform-routing constraints for the app's Liquid Glass controls.
---

Keep `liquid_glass_easy` at 5.0.0. The app carries a local copy of that release with only slider visual-size reporting and edge-icon tracking added. App switches intentionally use the caller's accent/category color when on and `kTertiaryLabel` when off, while retaining package-default geometry and renderer; use native iOS switch controls only on native iOS.

**Why:** The user wants app-specific accent/category track colors restored from the previous wrapper, but still wants the 5.0.0 switch's default dimensions, optics, and rendering behavior.

**How to apply:** Keep the switch color mapping in `AppSwitch`, without changing switch geometry or interaction. Check [native switch routing](cupertino-native-switch-package.md) and [Flutter/package version compatibility](liquid-glass-widgets-compatibility.md) before changing dependencies or platform branches.

All Liquid Glass surfaces use the shared rim-strength target in
`skeddo_glass_settings.dart`, matching the brighter toolbar/tab-bar rim. Keep
interaction glow and theme-specific key lighting separate from that rim value.

**Why:** A separate 0.5 multiplier on menus made their edge look weaker than
the toolbar and tab bar.

**How to apply:** Use the shared rim-strength constant once for package
Fresnel and app-owned specular edges. Avoid applying a second Dark Mode
reduction; preserve independent glow, fill, blur, geometry, and dark contours.

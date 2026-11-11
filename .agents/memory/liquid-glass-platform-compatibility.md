---
name: Liquid Glass package boundary
description: Package version and platform-routing constraints for the app's Liquid Glass controls.
---

Keep `liquid_glass_easy` at 5.0.0. The app carries a local copy of that release with only slider visual-size reporting and edge-icon tracking added. App switches intentionally use the caller's accent/category color when on and `kTertiaryLabel` when off, while retaining package-default geometry and renderer; use native iOS switch controls only on native iOS.

**Why:** The user wants app-specific accent/category track colors restored from the previous wrapper, but still wants the 5.0.0 switch's default dimensions, optics, and rendering behavior.

**How to apply:** Keep the switch color mapping in `AppSwitch`, without changing switch geometry or interaction. Check [native switch routing](cupertino-native-switch-package.md) and [Flutter/package version compatibility](liquid-glass-widgets-compatibility.md) before changing dependencies or platform branches.

In Dark Mode, keep bright Liquid Glass rim/specular highlights and matching thin
white edge lines at half their prior strength. Do not dim Light Mode or the
separate darker edge contour.

**Why:** The user wants the bright glass edge treatment less prominent in dark
surfaces without changing the material fill, blur, geometry, or dark outline.

**How to apply:** Scale only the bright rim/highlight intensity and white
hairline alpha in Dark Mode across package and app-owned glass renderers.

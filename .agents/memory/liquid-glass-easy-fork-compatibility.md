---
name: Liquid Glass Easy upstream 5.0.0
description: The project decision to use the untouched hosted liquid_glass_easy 5.0.0 package.
---

Keep the app's local `liquid_glass_easy` copy aligned with upstream 5.0.0. `AppSwitch` passes the caller's accent/category color as the on-track tint and `kTertiaryLabel` as the off-track color. Keep all other `LiquidGlassSwitch` defaults: do not pass custom style, dimensions, renderer overrides, or optical settings. Keep compatibility styling in app-owned widgets rather than modifying the package.

**Why:** The user wants the previous app-specific active/inactive track colors restored, while keeping package 5.0.0's default switch geometry and rendering.

**How to apply:** Keep the package at 5.0.0; make the permitted color mapping only in `AppSwitch`, preserve the separate native iOS switch route, and leave package geometry, style, and renderer defaults untouched.
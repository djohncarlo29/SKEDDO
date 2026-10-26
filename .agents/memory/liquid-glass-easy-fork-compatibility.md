---
name: Liquid Glass Easy upstream 5.0.0
description: The project decision to use the untouched hosted liquid_glass_easy 5.0.0 package.
---

Use the hosted `liquid_glass_easy` 5.0.0 package without a local path override. `LiquidGlassSwitch` must use package defaults: do not pass custom style, dimensions, colors, renderer overrides, or optical settings. Keep any necessary compatibility styling in app-owned widgets rather than modifying the package.

**Why:** The user explicitly chose the untouched 5.0.0 package and its default switch rendering, including the package-selected renderer and optical effects.

**How to apply:** Keep `liquid_glass_easy` pinned to hosted 5.0.0, adapt app call sites when public APIs are removed, and preserve the separate native iOS switch route.
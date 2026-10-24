---
name: Modal toolbar package glass
description: Modal toolbar actions use flutter_liquid_glass_widgets GlassIconButton with accent-tinted or disabled checkmarks.
---

Modal sheet and Notes attachment-preview toolbar controls use the package's
`GlassIconButton`, which is designed for toolbar icon actions. Pass the shared
floating-tab-bar `LiquidGlassSettings` to these standalone buttons. Active
checkmarks use the action's accent/category color for the glyph. A checkmark
whose action surface is `kDisabledActionSurface` remains glass but is disabled.

**Why:** Without explicit settings, `GlassIconButton` uses the package's general
theme defaults (lower thickness/refraction, more blur) instead of the tab bar's
stronger optical preset. Premium quality alone does not match the tab bar.

**How to apply:** Route sheet and attachment-preview toolbar actions through the
shared wrapper with the shared bar settings, `GlassQuality.premium`, and
`useOwnLayer: true`; keep action tint and disabled state without replacing
package rendering. Non-Impeller renderers still use the package's lighter path.
---
name: Modal toolbar package glass
description: Modal toolbar actions use flutter_liquid_glass_widgets GlassIconButton with accent-tinted or disabled checkmarks.
---

Modal sheet and Notes attachment-preview toolbar controls use the package's
`GlassIconButton`, which is designed for toolbar icon actions. Pass the shared
floating-tab-bar `LiquidGlassSettings` to these standalone buttons. Active
checkmarks use the action's accent/category color for their glass tint and an
opaque white glyph, with 85% tint opacity. Inactive checkmarks use the same
glass opacity and white glyph, tinted `#CECDD3` in Light Mode or `#474749` in
Dark Mode, while remaining semantically and functionally disabled.

**Why:** Without explicit settings, `GlassIconButton` uses the package's general
theme defaults (lower thickness/refraction, more blur) instead of the tab bar's
stronger optical preset. The user wants inactive checkmarks to remain visually
consistent with active glass while being distinguished by their specified tint.

**How to apply:** Route sheet and attachment-preview toolbar actions through the
shared wrapper with the shared bar settings, `GlassQuality.premium`, and
`useOwnLayer: true`; keep action tint and disabled state without replacing
package rendering. Non-Impeller renderers still use the package's lighter path.
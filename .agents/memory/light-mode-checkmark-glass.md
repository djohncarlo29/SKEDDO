---
name: Modal toolbar package glass
description: Modal toolbar actions use flutter_liquid_glass_widgets GlassIconButton with accent-tinted or disabled checkmarks.
---

Modal sheet and Notes attachment-preview toolbar controls use the package's
`GlassIconButton`, which is designed for toolbar icon actions. Pass the shared
floating-tab-bar `LiquidGlassSettings` to these standalone buttons. Active
checkmarks use an 85% accent/category underlay beneath a clear package glass
surface and an opaque white glyph; set the glass saturation to 1.0 to preserve
the accent hue. Inactive checkmarks keep the same 85% treatment and white glyph,
tinted `#CECDD3` in Light Mode or `#474749` in Dark Mode, while remaining
semantically and functionally disabled.

**Why:** Without explicit settings, `GlassIconButton` uses the package's general
theme defaults (lower thickness/refraction, more blur) instead of the tab bar's
stronger optical preset. Its premium shader preserves backdrop luminance for
chromatic tints, which can shift blue toward cyan over a bright surface.

**How to apply:** Route sheet and attachment-preview toolbar actions through the
shared wrapper with the shared bar settings, `GlassQuality.premium`, and
`useOwnLayer: true`. For active chromatic checkmarks, place the tint underneath
the package glass rather than passing it as `glassColor`; inactive grey tints can
still use `glassColor` directly. Active checkmarks should disable chromatic
aberration, Fresnel rim, and shadows while keeping subtle directional lighting;
the tab-bar edge effects create violet fringes and a contrasting outline at
this smaller size. Keep inactive controls disabled and preserve the package
renderer. Non-Impeller renderers still use the package's lighter path.
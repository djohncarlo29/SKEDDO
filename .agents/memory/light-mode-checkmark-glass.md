---
name: Modal toolbar package glass
description: Modal toolbar actions use flutter_liquid_glass_widgets GlassIconButton with accent-tinted or disabled checkmarks.
---

Modal sheet and Notes attachment-preview toolbar controls use the package's
`GlassIconButton`, which is designed for toolbar icon actions. Pass the shared
floating-tab-bar `LiquidGlassSettings` to these standalone buttons. Active
checkmarks use a fully opaque accent/category base, a 30% refraction-only
package layer, a clear full-strength Fresnel/lighting layer, and an opaque white
glyph. Inactive checkmarks use 85% glass tint with a white glyph,
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
still use `glassColor` directly. Active checkmarks need a fully opaque color
base, a translucent refraction-only package layer, and a clear, full-strength
Fresnel/lighting overlay with zero chromatic aberration. Keep inactive controls
disabled and preserve the package renderer. Non-Impeller renderers still use
the package's lighter path.
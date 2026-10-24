---
name: Modal toolbar package glass
description: Modal toolbar actions use flutter_liquid_glass_widgets GlassIconButton with accent-tinted or disabled checkmarks.
---

Modal sheet and Notes attachment-preview toolbar controls use the package's
`GlassIconButton`, which is designed for toolbar icon actions. Pass the shared
floating-tab-bar `LiquidGlassSettings` to these standalone buttons. Active
checkmarks keep a full-strength accent/category fill inside the visual
composition, with the complete button rendered at 85% opacity. The composition
also contains a 30% refraction-only package layer and a clear full-strength
Fresnel/lighting layer. Put every visual layer inside one transparent
`GlassButton.custom` stretch shell so fill, optical layers, and white glyph
deform together. Inactive checkmarks use 85% glass tint and a white glyph in
both themes, tinted `#CECDD3` in Light Mode or `#474749` in Dark Mode, while
remaining semantically and functionally disabled.

**Why:** Without explicit settings, `GlassIconButton` uses the package's general
theme defaults (lower thickness/refraction, more blur) instead of the tab bar's
stronger optical preset. Its premium shader preserves backdrop luminance for
chromatic tints, which can shift blue toward cyan over a bright surface. Keep
the checkmark glyph white in Light Mode too, even if stretching reduces its
contrast; do not replace it with a dark adaptive glyph.

**How to apply:** Route sheet and attachment-preview toolbar actions through the
shared wrapper with the shared bar settings, `GlassQuality.premium`, and
`useOwnLayer: true`. For active chromatic checkmarks, place the tint underneath
the package glass rather than passing it as `glassColor`; apply 85% opacity to
the complete active button composition, not to the category tint alone.
Inactive grey tints use `glassColor` directly, with a white glyph in both
themes. Keep inactive controls disabled and preserve the package renderer.
Non-Impeller renderers still use the package's lighter path.
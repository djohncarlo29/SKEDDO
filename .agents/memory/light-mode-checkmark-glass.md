---
name: Modal toolbar package glass
description: Modal toolbar actions use flutter_liquid_glass_widgets GlassIconButton with accent-tinted or disabled checkmarks.
---

Modal sheet and Notes attachment-preview toolbar controls use the package's
`GlassIconButton`, which is designed for toolbar icon actions. Active checkmarks
use an accent/category fill at 85% opacity, with glass optics layered above it
at a fixed 50%-slider reference; slider changes must not affect active
checkmarks. The composition also contains a 30% refraction-only package layer
and a clear full-strength Fresnel/lighting layer. Put every visual layer inside
one transparent `GlassButton.custom` stretch shell so fill, optical layers, and
white glyph deform together. Inactive checkmarks use shared slider settings,
85% glass tint and a white glyph in both themes, tinted `#CECDD3` in Light Mode
or `#474749` in Dark Mode, while remaining semantically and functionally
disabled. Set `GlassIconButton.glowColor` to transparent on these inactive
checkmarks to remove the touch halo without changing their resting glass tint.

**Why:** Without explicit settings, `GlassIconButton` uses the package's general
theme defaults (lower thickness/refraction, more blur). Active checkmarks need
stable optics even as the shared renderer slider changes. Its premium shader
preserves backdrop luminance for chromatic tints, which can shift blue toward
cyan over a bright surface. Keep the checkmark glyph white in Light Mode too,
even if stretching reduces its contrast; do not replace it with a dark adaptive
glyph.
Applying opacity to the complete active composition also dims its glass, so the
85% value belongs on the category fill only.

**How to apply:** Route sheet and attachment-preview toolbar actions through the
shared wrapper with `GlassQuality.premium` and `useOwnLayer: true`. For active
chromatic checkmarks, use the fixed 50%-reference optics and place the tint
underneath the package glass rather than passing it as `glassColor`; apply 85%
opacity to the category fill only. Inactive grey tints use shared slider
settings, `glassColor` directly, and a white glyph in both themes. Keep inactive
controls disabled, suppress their glow with transparent `glowColor`, and
preserve the package renderer.
Non-Impeller renderers still use the package's lighter path.
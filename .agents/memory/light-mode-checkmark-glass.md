---
name: Modal toolbar package glass
description: Modal toolbar actions use flutter_liquid_glass_widgets GlassIconButton with accent-tinted or disabled checkmarks.
---

Modal sheet and Notes attachment-preview toolbar controls use the
`liquid_glass_widgets` `GlassButton` renderer through the shared wrapper.
Active checkmarks retain an accent/category fill at 85% opacity, with glass
optics layered above it at a fixed 50%-slider reference; slider changes must
not affect active checkmarks. The composition also contains a 30%
refraction-only package layer and a clear full-strength Fresnel/lighting layer.
Put every visual layer inside one transparent `GlassButton.custom` shell so
fill, optical layers, and white glyph remain composed together. Modal toolbar
actions match the pinned AppShell's native press growth and 0.15 shared-shell
stretch.
Inactive checkmarks use shared slider settings, 85% glass tint and a white
glyph in both themes, tinted `#CECDD3` in Light Mode or `#474749` in Dark Mode,
while remaining semantically and functionally disabled. Set
`GlassButton.glowColor` to transparent on these inactive checkmarks to remove
the touch halo without changing their resting glass tint. The
discard-confirmation button has no touch glow, stretch, or interaction-driven
color change.

**Why:** The package button's general theme defaults don't match the app's
slider-driven shared optics. Active checkmarks need stable optics even as the
shared renderer slider changes. Its premium shader preserves backdrop
luminance for chromatic tints, which can shift blue toward cyan over a bright
surface. Keep the checkmark glyph white in Light Mode too, even if stretching
reduces its contrast; do not replace it with a dark adaptive glyph.
Applying opacity to the complete active composition also dims its glass, so the
85% value belongs on the category fill only.

**How to apply:** Route sheet and attachment-preview toolbar actions through the
shared wrapper using `liquid_glass_widgets.GlassButton`, `GlassQuality.premium`,
and `useOwnLayer: true`; bridge the app's shared glass settings into the
package's settings type. Leave the press scale unset to use the package's native
17-point press growth and set stretch to 0.15 for modal headers; reserve
no-touch-motion for controls explicitly designed to stay rigid. For active
chromatic checkmarks, use the fixed 50%-reference optics and place the tint
underneath the package glass rather than passing it as `glassColor`; apply 85%
opacity to the category fill only. Inactive grey tints use shared slider
settings, `glassColor` directly, and a white glyph in both themes. Keep inactive
controls semantically and functionally disabled and suppress their glow with
transparent `glowColor`. The discard confirmation action uses zero interaction
scale, zero stretch, transparent zero-opacity glow, zero ambient light, and
disabled interaction color feedback.
Non-Impeller renderers still use the package's lighter path.
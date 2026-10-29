---
name: Search cancel glass reparenting
description: Stable identity required for the Liquid Glass cancel control while search moves between scrollable and overlay locations.
---

The search cancel control must retain a stable GlobalKey when the search row moves between its inline scrollable location and the pinned off-screen search overlay. Its full-size `ModalToolbarGlassButton`/`GlassIconButton` must remain intact during the reveal animation without a rectangular clip; preserve the current X glyph, placement, and delayed cancel callback.

The cancel circle must claim drag gestures locally while leaving `GlassButton`'s raw-pointer stretch tracking active. Keep its native package press scale unset and use the standard 0.5 stretch, matching the other circular toolbar controls.

**Why:** The package stretch listener observes pointer movement but its button recognizer only claims taps. In inline search, a parent tab scroll view can otherwise win a drag beginning on the cancel button and move the screen beneath it.

**How to apply:** Wrap the cancel button in an opaque `GestureDetector` with horizontal and vertical drag callbacks that consume movement. Leave the inner `GlassButton` tap handler intact so ordinary taps still cancel search, and do not add a second scale override.

**Why:** Moving the row can remount the captured glass at the exact moment an overlay or sheet changes occlusion. The cancel button's surface styling is now intentionally flat and opaque, while its package button remains the interactive shape participant.

**How to apply:** Give each independent search surface its own stable key, keep the cancel circle as a grouped `ModalToolbarGlassButton`, and paint the same opaque search-surface fill over its glass shape. Keep its shape in the shared layer, without visible refraction or rim, and use an overflow-safe scale reveal. Preserve the delayed callback, centered X, and 0.5 px optical adjustment.

Light Mode checkmark buttons preserve their current LiquidGlassButton interior and active/inactive fill colors. Use one pure-white contour at 50% opacity, painted over the fill and fully inside the circle; it replaces both the separate white rim and dark outer contour. Its smooth variable width is thinnest around 1–2 o’clock and 7–8 o’clock. Dark Mode remains unchanged.

**Why:** The translucent white contour should blend with the existing glass fill as one edge treatment, without adding any contour outside the checkmark silhouette.

**How to apply:** Keep checkmarks on the existing LiquidGlassLens path and retain their `circle.color` surface. Overlay only the 50%-white inset variable-width contour in Light Mode. Keep the existing Dark Mode outline and appearance path unchanged.

Regular static surfaces should remain solid by default; controls that need the native lens must opt in explicitly and independently from `showOpticalBorder`.

**Why:** Search surfaces are intentionally solid fills; the cancel circle still needs the package's shared-layer geometry for blending, not a visible optical lens or rim.

**How to apply:** Keep opaque search-field and cancel fills above their shared-layer shape participants. Do not expose the underlying renderer's refraction or edge rim through those fills.
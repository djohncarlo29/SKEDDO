---
name: Search cancel glass reparenting
description: Stable identity required for the Liquid Glass cancel control while search moves between scrollable and overlay locations.
---

The search cancel control must retain a stable GlobalKey when the search row moves between its inline scrollable location and the pinned off-screen search overlay. Its full-size `ModalToolbarGlassButton`/`GlassIconButton` must remain intact during the reveal animation without a rectangular clip; preserve the current X glyph, placement, and delayed cancel callback.

**Why:** Moving the row can remount the captured glass at the exact moment an overlay or sheet changes occlusion. The user also explicitly requested that search cancel use the shared package `GlassIconButton` renderer in both appearances.

**How to apply:** Give each independent search surface its own stable key, build the cancel circle with `ModalToolbarGlassButton`, and use an overflow-safe scale reveal rather than constraining or rectangular-clipping the glass button. Preserve the established delayed cancel callback. Keep the X horizontally centered and 0.5 px above the circle’s center.

Light Mode checkmark buttons preserve their current LiquidGlassButton interior and active/inactive fill colors. Use one pure-white contour at 50% opacity, painted over the fill and fully inside the circle; it replaces both the separate white rim and dark outer contour. Its smooth variable width is thinnest around 1–2 o’clock and 7–8 o’clock. Dark Mode remains unchanged.

**Why:** The translucent white contour should blend with the existing glass fill as one edge treatment, without adding any contour outside the checkmark silhouette.

**How to apply:** Keep checkmarks on the existing LiquidGlassLens path and retain their `circle.color` surface. Overlay only the 50%-white inset variable-width contour in Light Mode. Keep the existing Dark Mode outline and appearance path unchanged.

Regular static surfaces should remain solid by default; controls that need the native lens must opt in explicitly and independently from `showOpticalBorder`.

**Why:** The Notes text-input card should not pay for or visually receive the glass lens, while the cancel-search control still needs its optical rim and lens treatment.

**How to apply:** Keep the shared surface's lens opt-in disabled for ordinary cards. Search cancel is a package-rendered action button and should not be reintroduced as a lens-enabled static surface.
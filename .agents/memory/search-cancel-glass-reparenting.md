---
name: Search cancel glass reparenting
description: Stable identity required for the Liquid Glass cancel control while search moves between scrollable and overlay locations.
---

The search cancel control must retain a stable GlobalKey when the search row moves between its inline scrollable location and the pinned off-screen search overlay. Its full-size lens must also remain intact during the reveal animation without a rectangular clip. Its visual and tap behavior must use the shared `StaticLiquidGlassActionButton` path in both appearances, not the non-interactive `StaticLiquidGlassSurface` path.

**Why:** Moving the row can otherwise remount the LiquidGlassView at the exact moment an overlay or sheet is changing occlusion, causing the cached capture and optical rim to render incorrectly. A separate surface implementation also diverges from the user's requirement that search cancel match the shared LiquidGlassButton behavior in Light and Dark Modes.

**How to apply:** Give each independent search surface its own stable key, build the cancel circle with `StaticLiquidGlassActionButton`, and use an overflow-safe scale reveal rather than constraining or rectangular-clipping the lens itself. Preserve the established delayed cancel callback and let the shared action button own its bloom and appearance-specific rim. Its Light Mode fill is `#FDFDFD`, with a dedicated 15%-opacity contour color; do not reuse `kTertiaryLabel`. Keep the cancel X horizontally centered and 0.5 px above the circle’s center.

Light Mode checkmark buttons preserve their current active/inactive fill colors but share the same thin white rim and tapered 15%-opacity contour as other circular action buttons. Dark Mode remains unchanged.

**Why:** The requested Light Mode edge treatment is shared across all LiquidGlassButton variants, while the checkmark fill remains semantically tied to its active state.

**How to apply:** Apply the Light Mode edge painter to checkmarks too; retain their `circle.color` surface and glass treatment. Keep the existing Dark Mode outline and appearance path unchanged.

Regular static surfaces should remain solid by default; controls that need the native lens must opt in explicitly and independently from `showOpticalBorder`.

**Why:** The Notes text-input card should not pay for or visually receive the glass lens, while the cancel-search control still needs its optical rim and lens treatment.

**How to apply:** Keep the shared surface's lens opt-in disabled for ordinary cards. Search cancel is now an action button and should not be reintroduced as a lens-enabled static surface.
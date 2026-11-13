---
name: Lifted tile rims and intentional grouping glow
description: Lifted category and event tiles use shared Light/Dark rim contours; grouping snap glow remains separate from outlines.
---

Lifted category and event tile ghosts use the same package-rendered optical rim
as the long-press context menu, clipped to a narrow contour so their ordinary
fill and content remain unchanged. Do not approximate this with a fixed
`BorderSide`; the shader-generated rim is not a 0.5pt stroke and is important to
keep visible in web previews as well as native rendering. Apply it to
context-menu previews and all reorder paths, including pinned-grid drags.
Overlay-sheet outlines retain their separate treatment. The category-grouping
snap glow is separate from elevation shadows and must remain visible in Dark
Mode.

**Why:** Lifted tiles should match the context menu's edge treatment while
remaining ordinary category/event surfaces rather than becoming full glass
surfaces. A hairline border was too weak in the web preview. The grouping glow
communicates an active drop target rather than elevation and should not be
removed by app-wide Dark Mode shadow suppression.

**How to apply:** Reuse the long-press menu's package renderer and slider-driven
glass settings, clipping the rendered effect to the tile's edge contour. Keep
the tile's own fill, text, and category/event icon untouched. Do not suppress
the rim for any reorder path. Paint grouping glow directly rather than through
the normal shadow resolver, using the stationary destination category's
resolved color.
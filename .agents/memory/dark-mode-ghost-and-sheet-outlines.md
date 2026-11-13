---
name: Lifted tile rims and intentional grouping glow
description: Lifted category and event tiles use shared Light/Dark rim contours; grouping snap glow remains separate from outlines.
---

Lifted category and event tile ghosts remain ordinary surfaces; paint the shared
menu-style rim as a separate edge-only overlay. Do not put a glass renderer,
gradient band, or opacity layer over the tile face: those either add an
unrequested wash, soften the tile, or wash out its contents. Use a uniform white
contour in both themes; do not add a grey outline in Light Mode. Apply it to
context-menu previews and all reorder paths, including pinned-grid drags.
Overlay-sheet outlines retain their separate treatment. The category-grouping
snap glow is separate from elevation shadows and must remain visible in Dark
Mode.

**Why:** Lifted tiles should match the context menu's edge treatment while
remaining ordinary category/event surfaces rather than becoming full glass
surfaces. A hairline border was too weak in the web preview. The grouping glow
communicates an active drop target rather than elevation and should not be
removed by app-wide Dark Mode shadow suppression.

**How to apply:** Keep the tile face fully opaque and draw only a thin,
uniform-color contour, with strength tied to the long-press menu's shared rim
settings. Fade the rim independently from the tile. Do not suppress the rim for
any reorder path. Paint grouping glow directly rather than through the normal
shadow resolver, using the stationary destination category's resolved color.
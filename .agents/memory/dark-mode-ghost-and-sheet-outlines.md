---
name: Lifted tile rims and intentional grouping glow
description: Lifted category and event tiles use shared Light/Dark rim contours; grouping snap glow remains separate from outlines.
---

Lifted category and event tile ghosts remain ordinary surfaces; paint the shared
menu-style rim as a separate edge-only overlay. Reuse the menu's premium shader
rim terms while setting the glass body to identity/transparent: do not blur,
refract, tint, or broadly gradient-fill the tile face. Do not substitute a
uniform stroke or add a grey Light Mode outline. Apply it to context-menu
previews and all reorder paths, including pinned-grid drags.
Overlay-sheet outlines retain their separate treatment. The category-grouping
snap glow is separate from elevation shadows and must remain visible in Dark
Mode.

**Why:** Lifted tiles should match the context menu's edge treatment while
remaining ordinary category/event surfaces rather than becoming full glass
surfaces. A hairline border was too weak in the web preview. The grouping glow
communicates an active drop target rather than elevation and should not be
removed by app-wide Dark Mode shadow suppression.

**How to apply:** Keep the tile face fully opaque, pass the menu's actual
Fresnel/specular/rim-light settings to an edge-only shader layer, and disable
body blur, refraction, tint, and color grading. Fade the rim independently from
the tile. Do not suppress the rim for any reorder path. Paint grouping glow
directly rather than through the normal shadow resolver, using the stationary
destination category's resolved color.
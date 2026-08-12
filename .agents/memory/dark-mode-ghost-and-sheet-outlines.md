---
name: Dark-mode-only outlines and intentional grouping glow
description: Smart Scheduler overlays and lifted cards use hairline outlines only in Dark Mode; grouping snap glow is an intentional accent effect.
---

Overlay sheets and lifted category ghosts should receive a 0.5 px tertiary-label
outline only when the active Cupertino brightness is dark, except while the
active drag is in the pinned-grid path. The category-grouping snap glow is
separate from elevation shadows and must remain visible in Dark Mode.

**Why:** Dark Mode needs edge definition on near-black/glass surfaces, while
Light Mode should preserve the existing shadow-only treatment. The grouping glow
communicates an active drop target rather than elevation and should not be
removed by the app-wide Dark Mode shadow suppression.

**How to apply:** Resolve the border at the widget build boundary and use
`BorderSide.none` in Light Mode or for any pinned-grid reorder ghost. Paint
grouping glow directly rather than through the normal shadow resolver, using the
stationary destination category's resolved color.
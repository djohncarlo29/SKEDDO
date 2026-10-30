---
name: GlassMenu morph and scroll bounds
description: Keep toolbar-menu transitions aligned with GlassPopover and keep scroll-indicator travel clear of rounded corners
---

## Rule
Toolbar menus should use the same normal morph spring, trigger-to-surface path, opening blur ramp, adaptive premium quality request, and shared content fade/scale profile as `GlassPopover`. Preserve the popover's staged layout handoff before starting the menu spring/blur. For pinned toolbar menus, use the popover's 0.3 stretch amount, 0.08 resistance, and 4px rightward settled landing offset. The premium request remains capped by adaptive device quality. The menu scroll indicator should travel only along the straight-sided portion of its card, ending one corner radius from each outer edge.

**Why:** The user wants toolbar menus to morph like the circle-trigger discard confirmation. Standard quality suppresses the trigger ghost during close, per-row scale/fade changes content motion, immediate menu spring start skips the popover's two-stage layout handoff, and the menu's larger default stretch feels more elastic. The user also wants its settled destination 4px right of the prior position.

**How to apply:** When changing `GlassMenu` morph behavior, compare its spring, path, blur ramp, render quality, layout-start timing, stretch, and content motion with `GlassPopover`; preserve the menu's existing radius and size. Derive the indicator track's top and bottom insets from the active menu radius.

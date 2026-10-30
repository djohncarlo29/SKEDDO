---
name: GlassMenu morph and scroll bounds
description: Keep toolbar-menu transitions aligned with GlassPopover and keep scroll-indicator travel clear of rounded corners
---

## Rule
Toolbar menus should use the same normal morph spring, trigger-to-surface path, opening blur ramp, adaptive premium quality request, and shared content fade/scale profile as `GlassPopover`. The premium request must remain capped by the device's adaptive quality scope. The menu scroll indicator should travel only along the straight-sided portion of its card, ending one corner radius from each outer edge.

**Why:** The user wants toolbar menus to morph like the circle-trigger discard confirmation. Standard quality suppresses the trigger ghost during close, removing the returning metaball merge; per-row scale/fade also made menu content move differently from the popover.

**How to apply:** When changing `GlassMenu` morph behavior, compare its spring, path, blur ramp, render quality, and content motion with `GlassPopover`; preserve the menu's existing radius and size. Derive the indicator track's top and bottom insets from the active menu radius.

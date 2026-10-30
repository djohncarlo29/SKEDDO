---
name: GlassMenu morph and scroll bounds
description: Keep toolbar-menu transitions aligned with GlassPopover and keep scroll-indicator travel clear of rounded corners
---

## Rule
Toolbar menus should use the same normal morph spring, trigger-to-surface path, and opening blur ramp as `GlassPopover`. The menu scroll indicator should travel only along the straight-sided portion of its card, ending one corner radius from each outer edge.

**Why:** The user wants toolbar menus to morph like the circle-trigger discard confirmation, and the scroll indicator endpoints to stay within the corner-radius-safe bounds shown in their screenshots.

**How to apply:** When changing `GlassMenu` morph behavior, compare its spring, path, and blur ramp with `GlassPopover`; preserve the menu's existing radius and size. Derive the indicator track's top and bottom insets from the active menu radius.

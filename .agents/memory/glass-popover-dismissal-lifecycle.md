---
name: GlassPopover dismissal lifecycle
description: The package's GlassPopover close callback signals the start of its morph, not animation completion.
---

**Rule:** `GlassPopover.onClose` runs when closing starts, not when the morph has settled. If a host `OverlayEntry` is removed there, the close transition is cut short. Keep the host mounted through the package's close animation, and route outside-tap, back, and action dismissal through one close handler.

**Why:** The popover owns its morph controller but exposes neither that controller nor a completion callback.

**How to apply:** When hosting a `GlassPopover` in a root overlay, delay entry cleanup until the close spring settles and account for reduced-motion settings.

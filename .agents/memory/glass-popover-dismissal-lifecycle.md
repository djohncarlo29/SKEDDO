---
name: GlassPopover dismissal lifecycle
description: The package's GlassPopover close callback signals the start of its morph, not animation completion.
---

**Rule:** `GlassPopover.onClose` runs when closing starts, not when the morph has settled. Keep the trigger/host mounted through the close animation, and route outside-tap, back, and action dismissal through one close handler. If the same popover must reopen, reset its package state only after that settle delay.

**Why:** The popover owns its morph and overlay controllers but exposes neither the controller nor a completion callback; reusing it before its overlay finishes can make the next toggle close again instead of opening.

**How to apply:** Delay host cleanup or state reset until the close spring settles, account for reduced-motion settings, and cover dismiss-then-reopen in tests.

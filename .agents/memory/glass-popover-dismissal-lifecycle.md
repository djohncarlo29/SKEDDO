---
name: GlassPopover dismissal lifecycle
description: The package's GlassPopover close callback signals the start of its morph, not animation completion.
---

**Rule:** `GlassPopover.onClose` runs when closing starts, not when the morph has settled. Keep the trigger/host mounted until the real trigger is visible and its rendered position has settled back at its origin; do not treat the first zero-crossing as completion. Before opening from a vetoed sheet drag, await the shared route restoration so the popover measures the settled trigger location.

**Why:** The package owns its morph and overlay controllers but exposes neither the controller nor a completion callback. A fixed delay can pop the sheet before the X returns, and the package captures trigger geometry only when opening.

**How to apply:** Observe the actual trigger return and stable geometry before resolving a dismiss result or resetting the popover host. Coalesce restoration calls from the route drag recognizer and the discard request, and cover swipe-to-confirm plus dismiss-then-reopen in tests.

---
name: Vetoed sheet drag restoration
description: Restoring rounded modal sheets after an unsaved-change pop is blocked.
---

When a rounded modal sheet's interactive down-drag calls `maybePop()` and an unsaved-change `PopScope` vetoes the route, the route animation controller remains at the finger's partial drag value. It must animate back to value 0 while the confirmation appears.

**Why:** The normal framework path only reverses an actively animating controller. A manually dragged controller is not animating at the moment `maybePop()` is vetoed, so the confirmation can otherwise appear above a half-dismissed sheet.

**How to apply:** After `maybePop()`, if the route is still current and the controller value is above zero, run the standard dropped-drag reverse animation. Skip this only when the route was actually popped.
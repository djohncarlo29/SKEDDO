---
name: Vetoed sheet drag restoration
description: Restoring rounded modal sheets after an unsaved-change pop is blocked.
---

When a rounded modal sheet's interactive down-drag calls `maybePop()` and an unsaved-change `PopScope` vetoes the route, the route animation controller remains at the finger's partial drag value. It must animate to value 1 while the confirmation appears; value 0 is fully dismissed.

**Why:** The normal framework path only reverses an actively animating controller. A manually dragged controller is not animating at the moment `maybePop()` is vetoed, so the confirmation can otherwise appear above a half-dismissed sheet. The route's settled/open value is 1.0, not 0.0.

**How to apply:** After `maybePop()`, if the route is still current and the controller value is below one, run the standard dropped-drag animation to 1.0. Skip this only when the route was actually popped.
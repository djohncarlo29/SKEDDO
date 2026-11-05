---
name: Context menu overlay covers underlying animation
description: Preserve close-animation timing and source-preview geometry when context-menu actions run.
---

## Rule
Main Events Tab category tiles (built-in and user-created, pinned and unpinned) use the package context-menu route with the tile itself as the in-place preview; do not pass `previewBuilder`. Preserve the existing long-press/reorder arbitration and previous centered platter placement. Group headers and event tiles remain on their separate custom menus unless explicitly migrated.

**Why:** The package route is pushed on the root Navigator, so `targetRect` must be measured in that root overlay's coordinate space; otherwise the hidden source preview and platter can appear at the screen origin. The route future resolves as dismissal starts, so the source must remain hidden and action callbacks pending through the 170ms reverse morph.

**How to apply:** Keep custom press/tap/drag handling and invoke the package's imperative context-menu API only after the existing menu-versus-reorder delay. Convert the source bounds to root-overlay coordinates, preserve the app's prior platter anchor/side/gap where required, hide the source until route dismissal finishes, then run any selected action. Do not replace group or event menus as part of this category-only behavior.

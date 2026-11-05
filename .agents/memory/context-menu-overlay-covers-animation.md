---
name: Context menu overlay covers underlying animation
description: Preserve close-animation timing and source-preview geometry when context-menu actions run.
---

## Rule
Main Events Tab category tiles (built-in and user-created, pinned and unpinned) use the package context-menu route with no `previewBuilder`. Keep the source tile painted but non-interactive under the route scrim, and let the package preview sit above it. Preserve long-press/reorder arbitration and the centered platter placement.

**Why:** The package route is pushed on the root Navigator, so `targetRect` must be measured in that root overlay's coordinate space. Its platter must be clamped to the safe viewport when the preferred side cannot fit, or the panel can escape its intended position. Keeping the source painted also preserves the previous in-place tile while the route draws its lifted copy.

**How to apply:** Keep custom press/tap/drag handling and invoke the package's imperative context-menu API only after the existing menu-versus-reorder delay. Convert source bounds to root-overlay coordinates, choose above/below using available room, clamp platter placement, ignore source input until dismissal completes, then run any selected action. Do not replace group or event menus as part of this category-only behavior.

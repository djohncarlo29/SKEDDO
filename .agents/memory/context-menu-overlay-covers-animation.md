---
name: Context menu overlay covers underlying animation
description: Preserve close-animation timing and source-preview geometry when context-menu actions run.
---

## Rule
Main Events Tab category tiles (built-in and user-created, pinned and unpinned) use the package context-menu route with no `previewBuilder`. Measure the pressed tile through a keyed render-object wrapper, not the `State`'s `BuildContext`; convert that box to root-overlay coordinates and pass the matching overlay size. Keep the source tile painted but non-interactive under the route scrim, and let the package preview sit above it.

**Why:** A `State` context can resolve to an ancestor render box rather than the actual tile. Passing that larger rectangle makes the lifted preview and platter appear detached or collapse toward the screen corner. The package route is pushed on the root Navigator, so the tile bounds and overlay size must use the same coordinate space. The platter must also be clamped to the safe viewport when its preferred side cannot fit.

**How to apply:** Keep custom press/tap/drag handling and invoke the package's imperative context-menu API only after the existing menu-versus-reorder delay. Use a keyed render object for the source bounds, choose above/below using actual overlay space, clamp platter placement, ignore source input until dismissal completes, then run any selected action. Do not replace group or event menus as part of this category-only behavior.

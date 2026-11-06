---
name: Context menu overlay covers underlying animation
description: Preserve close-animation timing and source-preview geometry when context-menu actions run.
---

## Rule
Main Events Tab category tiles (built-in and user-created, pinned and unpinned) use the package context-menu route with no `previewBuilder`. Measure the pressed tile through a keyed render-object wrapper, convert it to root-overlay coordinates, and pass that overlay's size. Keep the source tile visually clear of the scrim and magnified 7% while the platter is open. Place the platter immediately below the tile when it fits, otherwise above when that fits; never clamp it vertically to a screen edge. Taps on the platter backdrop or lifted tile dismiss the route.

**Why:** A `State` context can resolve to an ancestor render box rather than the pressed tile, which detaches the menu. Clamping the platter to the viewport can then make it appear at the screen edge instead of beside its source. The prior custom interaction also kept the tile lifted, undimmed, and tappable to dismiss.

**How to apply:** Keep custom press/tap/drag handling and invoke the imperative package API after the existing menu-versus-reorder delay. Use a keyed render object for source bounds, pass the matching overlay size, preserve a scrim hole around the source, and let the package route own the glass platter and dismissal animation. Ignore source input until the reverse morph completes, then run any selected action. Do not replace group or event menus as part of this category-only behavior.

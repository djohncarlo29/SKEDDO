---
name: Context menu overlay covers underlying animation
description: Preserve close-animation timing and source-preview geometry when context-menu actions run.
---

## Rule
Main Events Tab category tiles (built-in and user-created, pinned and unpinned) use the package context-menu route with the tile itself as the in-place preview; do not pass `previewBuilder`. Preserve the existing long-press/reorder arbitration. Group headers and event tiles remain on their separate custom menus unless explicitly migrated.

**Why:** The package route supplies the requested lifted source and Liquid Glass platter, while using its wrapper recognizer directly would compete with SKEDDO's existing category reorder gesture. Its route future resolves as dismissal starts, so the source must remain hidden and action callbacks pending through the 170ms reverse morph.

**How to apply:** Keep custom press/tap/drag handling and invoke the package's imperative context-menu API only after the existing menu-versus-reorder delay. Hide the source until route dismissal finishes, then run any selected action. Do not replace group or event menus as part of this category-only behavior.

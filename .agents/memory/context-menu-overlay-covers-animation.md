---
name: Context menu overlay covers underlying animation
description: Preserve close-animation timing and source-preview geometry when context-menu actions run.
---

## Rule
The All Events tile uses SKEDDO's shared custom category context menu, not the package `GlassContextMenu` proof of concept. Defer menu actions until the custom overlay's closing animation completes.

**Why:** SKEDDO's custom overlay keeps an opaque preview over the real row through its close animation. The package `showGlassContextMenu` route future completes as the pop starts, before its reverse morph finishes, and its action callback runs after `Navigator.pop()`. In the package layout, `previewBuilder` marks the preview as custom and centers it apart from the target; without it, the package uses the target rectangle and keeps the source visually anchored. A positioned-only `Stack` can also measure at zero when the package builds a custom preview offstage without the grid's constraints.

**How to apply:** For custom overlays, defer callbacks until the overlay is removed. For package menus, keep the source hidden and pending action through the reverse transition duration before restoring it or invoking the callback. Use no `previewBuilder` for in-place previews; when a relocated custom preview is intended and the source is constraint-dependent, wrap it in a `SizedBox` using the source tile's measured size.

---
name: Context menu overlay covers underlying animation
description: Preserve close-animation timing and source-preview geometry when context-menu actions run.
---

## Rule
Do not run a context-menu mutation callback until the closing animation is complete. In `showGlassContextMenu`, supplying `previewBuilder` opts into the centered custom-preview layout; omit it and provide `previewChild` when the preview should remain at the source rect and use the package's in-place lift scale.

**Why:** SKEDDO's custom overlay keeps an opaque preview over the real row through its close animation. The package `showGlassContextMenu` route future completes as the pop starts, before its reverse morph finishes, and its action callback runs after `Navigator.pop()`. In the package layout, `previewBuilder` marks the preview as custom and centers it apart from the target; without it, the package uses the target rectangle and keeps the source visually anchored. A positioned-only `Stack` can also measure at zero when the package builds a custom preview offstage without the grid's constraints.

**How to apply:** For custom overlays, defer callbacks until the overlay is removed. For package menus, keep the source hidden and pending action through the reverse transition duration before restoring it or invoking the callback. Use no `previewBuilder` for in-place previews; when a relocated custom preview is intended and the source is constraint-dependent, wrap it in a `SizedBox` using the source tile's measured size.

---
name: Context menu overlay covers underlying animation
description: Preserve close-animation timing and source-preview geometry when context-menu actions run.
---

## Rule
The All Events tile uses SKEDDO's shared custom category context menu, not the package `GlassContextMenu` proof of concept. Defer menu actions until the custom overlay's closing animation completes.

**Why:** SKEDDO's custom overlay keeps an opaque preview over the real row through its close animation. The package `showGlassContextMenu` route future completes as the pop starts, before its reverse morph finishes, and its action callback runs after `Navigator.pop()`. In the package layout, `previewBuilder` marks the preview as custom and centers it apart from the target; without it, the package uses the target rectangle and keeps the source visually anchored. A positioned-only `Stack` can also measure at zero when the package builds a custom preview offstage without the grid's constraints.

**How to apply:** For custom overlays, defer callbacks until the overlay is removed. For package menus, keep the source hidden and pending action through the reverse transition duration before restoring it or invoking the callback. Use no `previewBuilder` for in-place previews; when a relocated custom preview is intended and the source is constraint-dependent, wrap it in a `SizedBox` using the source tile's measured size.

## GlassMenu-matched context platter
Keep category and event long-press menus on the shared custom overlay when the interaction needs SKEDDO's in-place lifted preview and dismissal lifecycle. The platter can use the package's `GlassContainer` and `GlassMenuItem` row geometry, with the same menu surface settings, without adding a `GlassMenu` trigger morph.

**Why:** The package menu API owns a trigger-to-menu transition, while the app's context menu is anchored to a lifted tile and has separate action/dismiss callbacks. Reusing the package's surface and row primitives gives consistent formatting without replacing that interaction.

**How to apply:** Enable the GlassMenu-style ActionPanel only from the shared context-menu overlay. Leave the existing overlay lifecycle, tile preview, and callbacks intact; do not globally change other ActionPanel call sites.

For a platter above its source, pin its bottom edge to the source top minus the desired gap and scale from `Alignment.bottomCenter`; for a platter below, pin its top edge to the source bottom plus the gap and scale from `Alignment.topCenter`. Include the platter's material insets when calculating overflow height.

**Why:** The platter's own padding increases its visible height beyond the action rows. A top-based position derived from row height alone makes the above-source platter overlap the tile, while a top-anchored scale causes the gap to vary during its entrance.

**How to apply:** Keep one edge fixed at the source-facing side for each placement. Measure row wrapping at the actual menu width and text scale, then add the glass platter's insets before deciding whether to scroll.

Use the package's public `GlassInteractiveContainer` for the custom context platter: it composes the premium glass surface with the same horizontal stretch and touch glow as `GlassMenu`, while preserving the context menu's independent placement and no-trigger-morph behavior. Keep the backdrop scrim as a clipped dim-only layer when blur is not requested.

**Why:** Rebuilding those effects in the app can drift from package menu behavior, while swapping to a trigger-morphing `GlassMenu` changes the established context-menu presentation. The category and event tiles already share one overlay path.

**How to apply:** Route both category and event actions through the shared overlay and glass-styled `ActionPanel`. Keep its press feedback, overflow-only bounce/edge fade/scroll indicator, disabled selected state, and surface opacity animation together; do not add a backdrop filter to a dim-only scrim.

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

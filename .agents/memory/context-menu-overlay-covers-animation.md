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

For a platter with 12 pt of material inset, place its scroll indicator 3 pt from the outer glass edge (offset the content-relative indicator by -9 pt horizontally and use 20 pt vertical content insets for the 32 pt corner radius). Keep both `isSelected` and `showInteractionHighlight` false on action rows when no selection pill/highlight should appear; press scaling can remain enabled.

**Why:** `isSelected: false` alone does not disable a row's touch/hover highlight, and the context platter's inset child otherwise leaves the scrollbar visibly farther from the edge than the package menus.

**How to apply:** On orientation metrics changes, remeasure the trigger `RenderBox` after the next layout and update a `ValueListenable<Rect>` consumed by both the lifted preview and menu placement. Do this while opening or closing so the whole overlay stays attached to the same tile.

While a context menu is open, exempt category grid/list geometry from its normal animated reflow. The menu and tile should stay present and use one settled destination rectangle after rotation.

**Why:** The normal position animation can move the real tile over several frames while the lifted preview is already re-anchored, making the two appear to separate or briefly disappear.

**How to apply:** Listen to the shared context-menu-active notifier at the category layout boundary and use zero geometry duration for that open interval. Keep the overlay entry alive and refresh its source rectangle after the new layout completes.

To guarantee the source stays visible after a rotation changes the viewport, keep its menu-owning list item alive while the menu opens/closes, insert the full-screen entry in the root overlay, and call `Scrollable.ensureVisible` with keep-visible-at-end then keep-visible-at-start before measuring the final anchor.

**Why:** A tile can move outside a shorter or differently packed viewport after rotation; remeasuring alone does not bring it back onscreen, and a lazy list can otherwise dispose its menu owner before the correction runs.

**How to apply:** Run the reveal only when the observed orientation actually changes, with zero-duration scrolling; after those scroll positions settle, update the preview rectangle and let the menu recalculate its placement in the new viewport.

Context-menu action rows should use the shared `instantOnOpen` row behavior so every option is visible together as the panel opens. When revealing the trigger after rotation, target the bottom of the usable scroll area above the floating tab bar, not the physical screen edge; place the context platter within that same safe bottom boundary.

**Why:** Sequential row cascades obscure available actions, while a trigger aligned to the viewport's physical bottom can sit behind the floating navigation pill.

**How to apply:** Set `instantOnOpen` on every action in category, group, and event context menus. Use the shared tab-bar content clearance when computing the trigger's reveal alignment and the menu's available placement height.

Context-menu GlassMenu-style rows should match `GlassBarItem.menu` geometry: center each glyph inside the shared 28 pt text-scaled leading slot, then use the shared 12 pt icon-to-label gap so labels have one common left edge. The larger slot leaves scaled ink room for variable SF Symbol bounds.

**Why:** Sizing the slot to each individual glyph makes labels drift horizontally and icon centers vary from row to row.

**How to apply:** Keep actual glyph dimensions and optical offsets per action, but wrap them in the same centered fixed-width slot and pass that slot width as the GlassMenuItem icon size.

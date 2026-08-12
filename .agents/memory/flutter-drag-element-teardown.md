---
name: Flutter drag-reorder element teardown bug
description: Changing child widget structure (e.g. wrapping in DecoratedBox+AnimatedScale) when drag starts causes Flutter to tear down and recreate state, killing the GestureDetector mid-drag.
---

## Rule
When a `StatefulWidget` containing a `GestureDetector` is the child of an `AnimatedPositioned` (or any keyed widget), the child's widget tree structure must remain **structurally identical** between the "resting" and "dragging" states. If you change the widget type at any ancestor level (e.g. wrapping the child in a new `DecoratedBox` or `AnimatedScale` when drag starts), Flutter sees a different widget type at that tree position and **tears down the entire subtree**, destroying `State` objects including the `GestureDetector`'s recognizers. All subsequent `onLongPressMoveUpdate` events are lost.

**Why:** Flutter element reconciliation matches widget types at a given tree position. Different types → destroy + recreate. The gesture recognizer is disposed with the old state, so the drag dies after the first `onReorderStart` fires.

## How to apply
- Any visual change on drag start (scale, shadow, lift) must happen **inside** the tile's own `State` (e.g. via an `AnimationController`), not by wrapping the tile from outside.
- If a sibling node (like `ClipRect`) must behave differently during drag, change a **property** (`clipBehavior: isDragging ? Clip.none : Clip.hardEdge`) rather than replacing the node type.
- Never add or remove widget wrappers around a `StatefulWidget` with active gesture recognizers in response to state changes.

## Applied fix (SKEDDO events_tab.dart)
- `_AnimatedCategoryGrid`: removed `DecoratedBox(AnimatedScale(...))` wrapper around the dragging tile's `entries[i].child`. Grid dragging tile now uses the same bare `entries[i].child` as non-dragging tiles.
- `_CategoryCard._buildSlot`: replaced `if (isDragging) { ... DecoratedBox ... } else { ClipRect(...) }` with a single `ClipRect(clipBehavior: isDragging ? Clip.none : Clip.hardEdge, child: content)`. Structural identity is preserved; only the clip mode changes.
- Visual lift (scale 1.05 + shadow) lives entirely in `_CategoryContextMenuState._liftCtrl` — an `AnimationController` that fires on drag activate and reverses on end/cancel.

## Additional fix: outer container clipping
- `_CategoryCard`'s `AnimatedContainer` had `clipBehavior: Clip.antiAlias` with a `ShapeDecoration` — this clipped the entire Stack including the dragging tile, preventing it from escaping the list's bounds.
- Fix: removed the card `decoration` and `clipBehavior` from `AnimatedContainer`. Each row now carries its own card decoration inside `_CategoryRow._buildRowContent()` (a `Container` with `ShapeDecoration`). This way `_liftCtrl` scales the entire card (background + content) as one unit.
- Row gaps (`_kRowGap = 8.0`) were added between independent cards so shadows are visible.
- `_CategoryCard._buildSlot` signature had `divColor` param removed (dividers eliminated since rows are independent cards).
- Reorder pitch calculations (`_onListReorderStart/Update`) updated to use `_kListRowH + _kRowGap` as the slot pitch.

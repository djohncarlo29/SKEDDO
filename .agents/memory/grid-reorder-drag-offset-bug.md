---
name: Grid drag-reorder grab-offset accumulation
description: Why drag ghost drifts progressively further from the finger after each reorder session in the Events tab grid.
---

## The rule
In `_onGridReorderStart`, always look up the tile's visual slot index from `_gridCombinedOrder`, **not** from the section-local lists (`_smartCategoryOrder` / `_pinnedUserCategories`).

## Why
`_onGridReorderUpdate` mutates only `_gridCombinedOrder` during a drag (live reorder). The section-local lists are **never** updated per-drag-frame. After a session ends, `_gridCombinedOrder` reflects the new order but the section-local lists still have the old one. The next drag start uses a stale index → wrong `tileTopLeft` → wrong `_dragGridGrabOffset` → ghost is offset from the finger. The error compounds (accumulates) across sessions.

## How to apply
```dart
// CORRECT – always current
final Object lookupKey = key is String ? key.substring(6) : key;
final gridIdx = _gridCombinedOrder.indexOf(lookupKey);
if (gridIdx == -1) return;

// WRONG – section-local lists are stale after any reorder
final si = visibleSmart.indexOf(label);         // stale
final pi = visiblePinned.indexOf(key);           // stale
```

This applies to both smart tiles (key = `'smart_$label'`, lookupKey = `label`) and pinned user tiles (key = `_UserCategory` object, lookupKey = same object).

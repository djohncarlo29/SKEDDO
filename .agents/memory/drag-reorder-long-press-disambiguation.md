---
name: Drag-reorder vs context-menu long-press disambiguation
description: When a tile/row already uses long-press to open a context menu, adding long-press-drag reorder requires a grace-window pattern to distinguish "hold still → menu" from "hold then move → reorder".
---

## Rule
Use `onLongPressStart` / `onLongPressMoveUpdate` / `onLongPressEnd` / `onLongPressCancel` (not `onLongPress`) so you can observe movement BEFORE deciding which mode to enter. Start a short timer (~150ms) on long-press-start; if movement exceeds a slop threshold (10px) before the timer fires, cancel the timer and enter reorder; if the timer fires first, open the menu as before.

**Why:** `onLongPress` fires at the end of the press threshold with no subsequent movement tracking — you can't intercept the gesture for drag. The four-callback form gives continuous tracking of whether the user is moving.

**How to apply (Smart Scheduler `_CategoryContextMenu`):**
- Add `reorderable`, `onReorderStart`, `onReorderUpdate`, `onReorderEnd`, `onReorderCancel` to the widget.
- In `_onLongPressStart`: for reorderable tiles, start a 150ms `Timer`; for non-reorderable (smart tiles) call `_show()` immediately.
- In `_onLongPressMoveUpdate`: if movement ≥ `_kReorderSlop` (10px), cancel timer, set `_reorderActive = true`, call `onReorderStart`.
- In `_onLongPressEnd` / `Cancel`: if `_reorderActive`, fire `onReorderEnd` / `onReorderCancel`.
- Dispose the timer in `dispose()`.

Non-reorderable tiles keep the original instant-show-menu behavior.

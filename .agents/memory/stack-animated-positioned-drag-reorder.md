---
name: Stack + AnimatedPositioned drag-reorder with zero-duration dragging tile
description: Pattern for implementing live drag-to-reorder with smooth sibling sliding, using the same Stack+AnimatedPositioned infrastructure built for lifecycle animations.
---

## Rule
For the dragging tile: use `AnimatedPositioned(duration: Duration.zero)` so it follows the finger with zero lag. For all other tiles: use the normal `AnimatedPositioned(duration: _duration)` — their positions update as the data list is mutated live during drag, and they smoothly animate to their new slots.

**Why:** `AnimatedPositioned` interpolates between successive build values. If the dragging tile used a non-zero duration, its position would lag one `duration` behind the finger. `Duration.zero` makes the interpolation instant — same render as a plain `Positioned` but without the key-type-mismatch problem (no need to switch widget type at the same key across builds).

**How to apply (grid + list):**
- Render non-dragging tiles first in Stack children list (normal AnimatedPositioned).
- Render dragging tile LAST (paints on top of siblings) with `duration: Duration.zero`.
- Capture the grab offset (`localPointerPos - tileTopLeft`) in `onReorderStart` so the tile doesn't jump to center-on-finger.
- During `onReorderUpdate`: convert global pointer to Stack-local coords via `GlobalKey + RenderBox.globalToLocal()`, compute `newTopLeft = localPos - grabOffset`, mutate the data list order (swap the dragged item to the target index), and setState. Other tiles' positions recompute from the new list order and AnimatedPositioned animates them.
- `_applyReorderedVisible*()` helpers splice the reordered visible sublist back into the full backing list while preserving archived entries in their original positions.

**List-specific:** Use a fixed slot height (`_kListRowH = 64.0`) with `maxLines:1` enforced on text widgets. `AnimatedContainer` wraps the Stack so card height animates in lock-step when rows collapse or expand. Dividers are separate AnimatedPositioned elements hidden during drag.

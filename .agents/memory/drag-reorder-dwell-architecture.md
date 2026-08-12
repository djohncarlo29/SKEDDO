---
name: Drag-reorder + dwell-to-group architecture
description: How live reorder and dwell-to-group coexist; group member drag; solo→group join
---

## Rule
Live reorder ALWAYS runs (it is the primary gesture). Dwell-to-group runs in parallel using physical Y position tracking so it survives reorder swaps.

## Why the old "return early" approach broke reorder
The old fix froze the list whenever `hoveringOverSoloCat` was true. After a single swap, `targetIdx == currentIdx` → `hoveringOverSoloCat = false` → timer cancelled. This meant:
- Normal solo reorder was completely broken (list never moved).
- Dwell-to-group might fire once but was unreliable.

## The correct architecture
- `_dwellStartPhysicalY`: records ghost rawTopY when a dwell timer starts.
- Timer cancels only when `(rawTopY - _dwellStartPhysicalY).abs() > slotPitch * 0.7`.
- A reorder swap changes logical indices but not the finger position → timer survives.
- Live reorder runs unconditionally in the solo branch (no return-early).

## Group member drag
- `_draggingListGroupId`: non-null while a group member tile is being dragged. Set in `_onListReorderStart` by inspecting `draggingItem.isGroupMember`.
- `_CategoryRow.reorderable = true` always (was `!indented`).
- `_handleGroupMemberDrag`: within-group → reorder `memberIds`; crosses boundary → remove from group + insert as solo in `_listTopOrder` (group dissolves if <2 members remain). Sets `_draggingListGroupId = null` on exit.
- `_handleSoloDragIntoGroup`: called when a solo cat's ghost enters a group member slot. Removes from `_listTopOrder`, inserts into `memberIds`, sets `_draggingListGroupId`.

## How to apply
- Any change to dwell/reorder must preserve `_dwellStartPhysicalY` tracking.
- Do NOT gate live reorder on `hoveringOverSoloCat`.
- Dwell-to-group only applies when BOTH dragged item and target are solo (`draggedItem.isSolo && targetItem.isSolo`). Group member drags skip dwell entirely (the `_draggingListGroupId != null` branch returns early before reaching dwell logic).

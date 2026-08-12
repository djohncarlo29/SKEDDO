---
name: Categories accordion outer clip
description: The outer unpinned CATEGORIES card must keep one stable shape while grouped rows expand and collapse.
---

## Rule
The outer CATEGORIES surface is a single `AnimatedContainer` with a constant
`BoundedContinuousRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(24)))`.
Its height animates, but the requested corner radius is always 24 px and the card
is always at least one full row tall (64 px), so the border's vertical-scale
constraint never fires. Row surfaces inside paint their own shapes with isFirst/isLast
corners but do NOT repaint the outer boundary.

## Accordion height contract

Two helpers drive the animation in `_CategoryCard`:

| Helper | Purpose |
|---|---|
| `_slotTargetH(item)` | Target height after animation ends. Collapsingmembers → 0; lifecycle-collapsed rows → 0; everyone else → `_kListRowH`. **Used to drive `totalH` for the outer AnimatedContainer.** |
| `_slotCurrentH(item)` | Height right now. Same as `_slotTargetH` except expanding members → 0 (they animate upward into the space the outer card already opened). **Used in `_slotTopY` and `slotH` in `_buildSlot`.** |
| `_isSlotHidden(item)` | `_slotCurrentH == 0`. **Used for isFirst/isLast corner-flag visibility.** |

## Expand flow
1. `_expandingGroupIds.add(gid)` + `_expandedGroupIds.add(gid)` (state machine in `_toggleGroupExpanded`).
2. Members added to flat list via `_buildFlatDisplayList` (showMembers=true while in expanding set).
3. `_slotTargetH` = `_kListRowH` → outer card starts growing to full height immediately.
4. `_slotCurrentH` = 0 (in `expandingGroupIds`) → slots start at zero.
5. After animation delay: `_expandingGroupIds.remove(gid)`.
6. `_slotCurrentH` becomes `_kListRowH` → AnimatedPositioned slides rows up into the open card. ✓
7. isFirst/isLast for group header stays `isLast=true` throughout (members hidden by `_isSlotHidden`).

## Collapse flow
1. `_expandedGroupIds.remove(gid)` + `_collapsingGroupIds.add(gid)`.
2. Members kept in flat list (`showMembers=true` while in collapsing set).
3. `_slotTargetH` = 0 → outer card starts shrinking immediately.
4. `_slotCurrentH` = 0 → AnimatedPositioned animates slots from `_kListRowH` → 0.
5. After animation delay: `_collapsingGroupIds.remove(gid)` → members removed from flat list.
6. Group header becomes `isLast=true` immediately on step 1 (members hidden by `_isSlotHidden`). ✓

**Why:** Both target-height mismatch (animated container chasing wrong final size) and immediate
isFirst/isLast reassignment caused the visible corner snap. The two helpers separate "where we're
going" from "where we are now," keeping them in sync with the row animations.

**How to apply:** Never compute `totalH` from `_slotCurrentH`; always use `_slotTargetH` for the
AnimatedContainer target so it leads the row animation rather than chasing it.

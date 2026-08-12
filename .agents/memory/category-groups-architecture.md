---
name: Category Groups Architecture
description: Data model, state vars, rendering pipeline, and persistence for the CATEGORIES list group feature.
---

## Data model

- `_CategoryGroup { id, name, memberIds }` — persisted to `_kPrefsCategoryGroups` as JSON list.
- `_FlatItemKind` enum: `solo | groupHeader | groupMember`.
- `_FlatItem` sealed-like class — carries `category`, `group`, and `parentGroupId`.
- `_listTopOrder: List<String>` — canonical list section order. Entries are either a category ID or `'grp-<groupId>'`. Persisted to `_kPrefsListTopOrder`.

## Key state vars (on EventsTabState)

- `_categoryGroups`, `_listTopOrder`, `_expandedGroupIds`, `_expandingGroupIds`, `_collapsingGroupIds`
- `_dragGroupTargetCat`, `_dragGroupHapticFired`, `_draggingListGroupId`

## Rendering pipeline

`_buildFlatDisplayList()` → `List<_FlatItem>` → `_CategoryCard` → `_buildSlot()` dispatches to `_GroupRow` or `_CategoryRow`.

`_CategoryCard` now takes `List<_FlatItem>` (not `List<_UserCategory>`), plus `expandedGroupIds`, `collapsingGroupIds`, `dragGroupTargetCat`, `onEditGroup`, `onUngroup`, `onToggleExpand`.

## Group header row (_GroupRow)

- `SFIcons.sf_rectangle_stack` icon, no container, `kPrimaryLabel`, `w500`.
- Member count replaces event count.
- `AnimatedRotation` chevron (right→down, `kAccentColor`). `const Icon` with `kAccentColor` is valid since `CupertinoDynamicColor` IS a const.
- Long-press → `_CategoryContextMenu(isGroup: true)` → "Edit Group" / "Ungroup" actions.

## Drag-to-group flow

`_onListReorderUpdate` detects hover-over-solo-cat → sets `_dragGroupTargetCat` + haptic + glow. `_onListReorderEnd` → `_openNewGroupSheet(cat1, cat2)`.

**Why:** Using the existing long-press drag infrastructure avoids a separate gesture recognizer; only the target-cat state variable needs to be guarded against group-member drags.

## _NewGroupSheet

Title field + "Include" picker using `ActionMenuOverlay`. Min 2 categories checked to enable Save. Multi-select: tapping a checked item with count ≤ 2 is silently ignored. `_ModalCircleButton.onTap` is non-nullable — pass `() {}` no-op instead of `null` when disabled.

## Persistence / migration

- `_saveCategories` → writes `_categoryGroups` (JSON) and `_listTopOrder` (strings) to prefs.
- `_loadCategories` → restores both; validates tokens against live cat/group IDs. Migration path: if no saved list order but user cats exist, seeds `_listTopOrder` from current non-archived cats in order.

## Group lifecycle helpers

- `_createGroup` — replaces first member's solo slot with `grp-<id>`; removes remaining solo slots.
- `_ungroupGroup` — removes `grp-<id>` token; inserts member IDs back as solo slots in place.
- `_updateGroup` — diffs old/new memberIds; removes newly-excluded solo slots; inserts newly-excluded IDs back as solo after the group token.
- `_removeFromGroupById` — removes a cat from its group; if membership drops below 2, dissolves the group automatically.
- `_toggleGroupExpanded` — adds to `_expandingGroupIds` immediately (so members show), then after animation delay removes from that set and adds to `_expandedGroupIds`.

## List.remove() gotcha

`List<T>.remove()` returns `bool`, not `T?`. Always use `list.contains(x)` before removal if you need to know whether it was present.

## Drag-to-group: dwell timer + freeze list order during dwell

The original center-proximity check (`distFromCentre < 0.38 * rowH`) never fired because live-reorder displaced the target before the ghost could reach it. Replaced with a 320 ms dwell timer (`_kGroupDwellMs`).

**Critical rule: do NOT run live reorder while the dwell timer is pending.** If you reorder the list during the dwell, the dragged cat swaps into the target's slot on the very next move event, making `targetIdx == currentIdx` → `hoveringOverSoloCat` turns false → timer is cancelled immediately. The 320 ms window never completes. Fix: `return` early after updating only ghost Y when `hoveringOverSoloCat` is true — live reorder only runs when the ghost is NOT hovering over a solo cat. Once confirmed group mode fires, list stays frozen until release or ghost moves off.

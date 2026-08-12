---
name: _FlatItem ValueKey ghost-freeze bug
description: Why ValueKey(_FlatItem) causes ghost-freeze when a category transitions between solo and groupMember during drag
---

## Rule
Never use `ValueKey(item)` where `item` is a `_FlatItem` in any widget tree that persists across solo↔member transitions.

## Why
`_FlatItem.hashCode = Object.hash(kind, category?.id, group?.id)`. `kind` is `_FlatItemKind.solo` vs `_FlatItemKind.groupMember` — different values. So `ValueKey(_FlatItem.solo(cat))` ≠ `ValueKey(_FlatItem.groupMember(cat, gid))`. Flutter disposes the old element and creates a new one, killing the `_CategoryContextMenu._reorderActive = true` state mid-drag. The overlay entry is never removed → ghost frozen on screen permanently.

**How to apply:**
Use a stable string key based on the item's identity, not its role:
```dart
final slotKey = item.isGroupHeader
    ? ValueKey('grp-${item.group!.id}')
    : ValueKey(item.category!.id);
```
This is stable across solo↔member transitions since the category ID doesn't change.

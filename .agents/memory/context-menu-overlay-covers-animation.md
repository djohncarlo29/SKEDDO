---
name: Context menu overlay covers underlying animation
description: The _CategoryContextMenu closing overlay (420ms) paints an opaque floating copy of the tile/row directly over the real widget — any animation fired synchronously on action-tap plays and finishes invisibly underneath it.
---

## Rule
Never fire a destructive or mutation callback synchronously inside a context menu action button. Always defer it until the overlay's close animation completes.

**Why:** `_CategoryContextMenu._hide()` starts a 420ms easeIn collapse animation on the overlay entry. During those 420ms the overlay's opaque floating preview copy sits exactly over the real widget in the tree. Any animation started on the real widget (archive collapse, delete flash, pin reflow) runs and completes entirely behind the overlay — invisible to the user. The user sees the overlay disappear and the row already in its final state, making it look like nothing animated.

**How to apply:** Pass the action callback via `_hide(then: callback)`. The `then` parameter is invoked inside `cleanup()` which runs after `animateTo(0).then(...)` — i.e., after the overlay entry is removed and the real tree is fully visible. This applies to ALL five actions (pin, unpin, edit, archive, delete) uniformly.

Implementation: `_hide({VoidCallback? then})` + `then?.call()` inside `cleanup()`.

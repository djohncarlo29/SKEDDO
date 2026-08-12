---
name: Pin-category scroll-jump and compensation anchor
description: Why pinning a category jumps the scroll to reveal the newly pinned grid tile, and how the compensation must be anchored.
---

## The rule
Save the scroll offset **before** the phase-1 row collapse and pass it as `scrollBase` to `_startGridResizeTracking`. The per-frame compensation then uses `scrollBase + totalGrowth` (not `currentOffset + delta`) as the target.

## Why
Phase 1 collapses the list row (220 ms). This shrinks the scroll content, which can clamp the scroll offset *upward* — briefly bringing the grid's newly added tile into view. If phase-2 compensation starts from the *clamped* offset it reinforces that shifted position rather than correcting it. The fix: anchor to the pre-clamp offset so the final position is always `(pre-pin-offset) + (how much the grid has grown so far)`.

## How to apply
In `_pinCategory`:
```dart
final scrollBase = _scrollController.hasClients ? _scrollController.offset : 0.0;
setState(() => _removingFromList.add(cat));        // phase 1
Future.delayed(220ms, () {
  _startGridResizeTracking(scrollBase);            // pass the anchor
  setState(() { /* add tile to grid */ });
});
```

In `_startGridResizeTracking(double scrollBase)`:
```dart
_initialGridRenderHeight = h;   // grid height before setState
_gridResizeScrollBase    = scrollBase;
```

In `_tickGridResizeCompensation`:
```dart
final totalGrowth = currentH - _initialGridRenderHeight;
final newOffset   = (_gridResizeScrollBase + totalGrowth)
    .clamp(0.0, _scrollController.position.maxScrollExtent);
_scrollController.jumpTo(newOffset);
```

Do **not** use `_scrollController.offset + delta` — that carries forward any phase-1 clamp offset and keeps the grid tile visible.

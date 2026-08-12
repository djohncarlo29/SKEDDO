---
name: Calendar 3-panel swipe ±2 bug
description: Why the header title jumped ±2 while content showed ±1 after a swipe, and the correct fix.
---

## The bug

`_animateSlide` had a `_bloomTimer` that fired `doThen()` (nav commit + panel remap) at **55% of the animation**, while the animation continued to 100%. This caused the header to get stuck showing ±2.

## Why it happened (step by step for a forward swipe)

3-panel layout during animation:
```
prev @ monthSlideX − sw | current @ monthSlideX | next @ monthSlideX + sw
```
Animation: `monthSlideX` goes from `−200` (drag-end) → `−screenW` (target).

1. At 55% (~−368px): `doThen()` fires. `_applyNext()` makes M+1 the new "current".
   - Panel remap: slots are now [M, M+1, M+2]
   - `_slideX = 0`, `onStripSlide(0)` → `_calendarStripSlide.value = 0`
2. Animation continues (still running): `_snapCtrl` listener fires every frame:
   `widget.onStripSlide?.call(_snapAnim.value)` — **overrides the 0.0 reset** with the still-negative animation value.
3. At 100% (−screenW): `_calendarStripSlide.value = −screenW`.
   - Header shows: current (M+1) at `−screenW` (off-screen), next (M+2) at `0` (centered) → **stuck at M+2**.
4. Content resets correctly: after `_snapCtrl.reset()`, `slideX = _slideX = 0`, M+1 at center.
   Header never resets → permanently shows M+2.

## Why the fix works (doThen at 100%)

At animation completion (`_snapAnim.value = −screenW`):
- "Next" panel (M+1) is at position `monthSlideX + sw = −sw + sw = 0` → **already at center**.
- `doThen()` fires: `_applyNext()` makes M+1 "current", `_slideX = 0`.
- Rebuild: "current" (M+1) at `monthSlideX = 0` → **same pixel, zero visual jump**.
- Header: `onStripSlide(0)` fires, `_calendarStripSlide.value = 0`, M+1 centered ✓.

## The fix

Remove the `_bloomTimer` entirely. Let `doThen` fire only in the `.then()` callback (animation completion):

```dart
_snapCtrl.forward(from: 0).then((_) {
  if (!mounted || _snapGeneration != myGen) return;
  _snapThenFired = true;
  _slideX = 0.0;
  widget.onStripSlide?.call(0.0);
  then();
  _snapCtrl.reset();
  if (mounted) setState(() => _navLocked = false);
});
```

**Why:** At 100%, the panel that was "next" (M+1) is exactly at center. Making it "current" with `slideX=0` keeps it at center. The header's `_calendarStripSlide` is reset to 0 before the animation listener can override it (listener guards with `isAnimating`, which is false after completion).

## Key insight

In a 3-panel layout (`prev | current | next`), remapping panel roles mid-animation always shifts the visual by one extra slot. **Any early commit during an in-progress animation causes ±2.** Always commit at completion.

---
name: TweenAnimationBuilder vs implicit-animated widget type mismatch kills animation
description: When a keyed slot switches between TweenAnimationBuilder and any Animated* widget (ClipRect+AnimatedAlign, etc.) at the same key, Flutter treats it as a new element and tears down the old one — killing the animation after ~1 frame.
---

## Rule
Never mix explicit (`TweenAnimationBuilder`) and implicit (`Animated*`) widget types at the same keyed slot across consecutive builds. Pick one approach for the full lifecycle of that slot, or use a stable intermediate widget type as the key owner.

**Why:** Flutter's reconciler, given the same key, checks runtime type. `TweenAnimationBuilder<double>` ≠ `ClipRect`. Even with an identical key (`ObjectKey(cat)` / `ValueKey(cat)`), a type change causes the existing Element to be discarded and a fresh one mounted — restarting the animation from scratch with no progress from the previous frame.

**How to apply (list row create-animation case):** The `_poppingInList` flag controls which branch of `_buildRowSlot` runs. The flag MUST stay set for the full `TweenAnimationBuilder` duration (260ms) — removing it even one frame early (via `addPostFrameCallback`) switches the slot to `ClipRect` and tears down the `TweenAnimationBuilder`. Fix: `Future.delayed(const Duration(milliseconds: 260), () => setState(() => _poppingInList.remove(cat)))`.

**General rule:** Always match `Future.delayed` durations to the animation duration of the widget whose type you are changing.

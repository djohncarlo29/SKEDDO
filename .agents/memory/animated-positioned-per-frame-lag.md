---
name: AnimatedPositioned per-frame lag
description: Using AnimatedPositioned on a value that changes every frame (e.g. raw finger position) causes permanent lag equal to the animation duration.
---

## Rule
Never use `AnimatedPositioned` (or `AnimatedContainer` for position) on a variable that updates every drag frame. The animation curve means the widget is always catching up to the latest value — it lags behind by the full duration.

**Why:** AnimatedPositioned animates between the previous value and the new value each time the value changes. When the value changes every 16ms (every frame), the animation never finishes before the next value arrives. The result is the widget always trails the source by ~duration ms.

**How to apply:** Split position and size when only one needs animation:
- Use `Positioned` for XY (follows raw finger directly, no animation)
- Use `AnimatedContainer` inside it for width/height only (animates discrete slot transitions)

This pattern applies to any overlay ghost that must follow a pointer while also growing/shrinking between two discrete sizes.

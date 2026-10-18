---
name: DCV offscreen search keyboard viewport
description: Keyboard geometry and empty-result centering for offscreen search overlays in the Detailed Category View.
---

## Rule

The Events tab's DCV search overlay lives in a custom full-screen Stack that
does not resize with the keyboard. `SmartDcvSearchResults` must reserve
`MediaQuery.viewInsets.bottom` with `AnimatedPadding`, remove the bottom
viewInsets from its inner scroll view, and use zero tab-bar clearance while the
keyboard is open. When the keyboard is hidden, keep the normal floating-tab-bar
clearance.

**Why:** The Calendar search centers inside its keyboard-safe viewport. If both
the parent and the empty-state helper count the keyboard, the placeholder shifts
too far upward; if neither resizes the result area, it centers behind the
keyboard.

**How to apply:** Keep the inset handling inside `SmartDcvSearchResults` so its
callers cannot apply the same obstruction twice. Test it with explicit
`MediaQuery.viewInsets` and assert the empty state centers between the fixed
header and keyboard edge.

---
name: Emoji category selection repaint
description: Selection rendering for variation-selector emoji in the category strip.
---

Category-tab selection should keep the existing tab layout intact while
replacing only the painted emoji child when its selected/idle state changes.
Variation-selector color emoji such as the heart need a real Opacity layer for
dimming.

**Why:** A larger Stack-based separation caused the picker itself to disappear,
while a stale platform color-emoji layer could still preserve the wrong
selection appearance.

**How to apply:** Keep the category slot and its existing GlobalKey as-is. Put
a selection-dependent KeyedSubtree around the existing Center's emoji content,
and keep Opacity around the Text because platform color emoji may ignore alpha
in TextStyle.color. For overflowing strips, do not write the current pixels
back with a no-op jumpTo during tap handling; cancel active scroll activity
without forcing an immediate scroll-position update. Do not add a
StackFit.expand geometry layer.
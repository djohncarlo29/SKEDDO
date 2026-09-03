---
name: Emoji category selection repaint
description: Selection rendering for variation-selector emoji in the category strip.
---

Category-tab selection alpha must be painted by the emoji Text itself, not by an
Opacity compositing wrapper. Variation-selector color emoji such as the heart
can retain the wrapper's old rasterized appearance after the horizontally
scrollable strip repositions.

**Why:** The picker could switch its grid data correctly while the heart tab
continued to look selected after navigating away from it.

**How to apply:** Keep the category slot keyed only for visibility scrolling,
and express selected versus idle opacity in the TextStyle color so the
RenderParagraph receives a fresh paint value on every category switch.
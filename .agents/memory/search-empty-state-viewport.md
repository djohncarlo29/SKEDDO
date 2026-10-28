---
name: Search empty-state viewport geometry
description: Keep the No Results placeholder centered when search viewports have different tab-bar and keyboard boundaries.
---

Offscreen search results are already bounded above the tab bar by the shell. Do not reserve tab-bar clearance again inside the empty-state viewport. The keyboard inset is measured from the window bottom, so subtract the shell's reserved bottom offset before treating it as an obstruction inside that viewport. Inline search reaches the window bottom and keeps its tab-bar clearance inside the results layout.

**Why:** Applying the full tab-bar clearance or keyboard inset to an already-shortened viewport shifts the placeholder upward twice, both with and without the keyboard.

**How to apply:** When adjusting empty-state centering, distinguish internal content clearance from the viewport's existing bottom offset. Use the overlap of the keyboard and actual results viewport, and keep inline and shell-overlay cases separately tested.

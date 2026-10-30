---
name: Glass menu selection behavior
description: Menu selection, scale, and rubberband interaction rules
---

`GlassBarItem.menu` rows stay visually neutral for every gesture: no selector pill, press/hover/focus fill, or selected-row scale. Normal taps and slide-to-select remain functional. Rubberbanding depends only on actual overflow; fitting root and nested menus do not bounce, while overflowing ones do.

**Why:** The row's press/hover fill can look like the selector pill even after the pill itself is disabled. Selection, visual feedback, and scrolling must remain independent.

**How to apply:** Disable row interaction highlights for every `GlassBarItem.menu` appearance, including light/dark and submenu levels, without disabling pointer selection or tap handlers. Enable bounce only when rendered content exceeds its viewport.

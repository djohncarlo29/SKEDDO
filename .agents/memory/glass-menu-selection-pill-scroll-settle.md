---
name: Glass menu selection behavior
description: Menu selection, scale, and rubberband interaction rules
---

Menu rows can be selected by sliding across them, but do not show a selector pill or shrink/scale the selected row. Rubberbanding is based only on actual content overflow: overflowing root or nested menus bounce, while fitting menus of either level do not. Fitting nested menus must still allow slide-to-select.

**Why:** The requested interaction separates row selection from scrolling; nesting alone must not enable rubberbanding.

**How to apply:** Keep the pointer selection path independent from scroll physics. Enable bounce only when the rendered list height exceeds its viewport; ordinary taps must still activate through the row recognizer.

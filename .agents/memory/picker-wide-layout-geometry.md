---
name: Picker wide-layout geometry
description: Responsive sizing rules for category color, icon, and emoji picker grids.
---

Category color, icon, and emoji pickers preserve the portrait layout's computed visual size, tappable cell size, gaps, and horizontal insets for the current OS text scale. Wider layouts recalculate only how many complete cells fit inside the existing sheet content width; they do not enlarge cells, stretch gaps, or cap the column count, and the grid remains leading/left aligned.

The portrait baseline is scale-derived rather than a stale raw-pixel snapshot. If the app starts in landscape, use the same portrait geometry rules for the current OS text scale. If the OS text scale changes while a picker is open, recompute using the normal portrait adaptation immediately.

**Why:** The portrait mobile layout is already visually correct. Larger landscape and tablet widths should add capacity without changing the established picker item size or touch behavior.

**How to apply:** Keep portrait output unchanged. Measure available picker width after its existing insets, fit as many fixed-size cells plus the existing gaps as possible, and leave the final row naturally incomplete when needed.
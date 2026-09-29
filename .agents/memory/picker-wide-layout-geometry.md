---
name: Picker wide-layout geometry
description: Responsive sizing rules for category color, icon, and emoji picker grids.
---

Category color, icon, and emoji pickers preserve the portrait layout's computed visual size and tappable cell size for the current OS text scale. Wider layouts fit as many complete cells as possible, then redistribute horizontal gaps only upward to reach the 16pt card insets; partial final rows keep the same gap and remain leading/left aligned.

The portrait baseline is scale-derived rather than a stale raw-pixel snapshot. If the app starts in landscape, use the same portrait geometry rules for the current OS text scale. If the OS text scale changes while a picker is open, recompute using the normal portrait adaptation immediately.

**Why:** The portrait mobile layout is already visually correct. Larger landscape and tablet widths should add capacity without changing the established picker item size or touch behavior.

**How to apply:** Keep portrait output unchanged. Derive the wide cell size from the actual portrait result, fit complete cells using the portrait gap as the floor, and calculate one full-row gap with `max(portraitGap, redistributedGap)`. Reuse that gap for incomplete rows without forcing their last item to the trailing inset. Keep vertical row spacing independent.
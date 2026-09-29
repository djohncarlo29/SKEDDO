---
name: Picker geometry consolidation
description: Shared layout invariants for the icon, emoji, and color pickers before rotation interpolation is added.
---

Use one authoritative geometry calculation for each picker. It owns content
insets, item size, column and row counts, gaps, height, and item rectangles;
renderers should consume those values rather than independently reflowing.
Portrait establishes the baseline. Landscape keeps the portrait item size and
vertical gap, uses at least the portrait horizontal gap, and distributes extra
width through horizontal spacing. The outer content edge is 16pt from each
side.

**Why:** The prior picker implementations had competing checkpoint/live paths,
orientation-specific padding, and disabled pinch state. Preserving those paths
made it easy for portrait and landscape to drift even when one screenshot was
correct.

**How to apply:** Extend the shared picker geometry utility for future picker
states. Add rotation interpolation only as a transition between the settled
portrait and landscape geometries; do not add another independent timed layout
animation or reintroduce per-picker geometry calculators.
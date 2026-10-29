---
name: Separate glass control blending
description: Package architecture for separate neighboring glass controls that visually blend when their shapes overlap.
---

**Rule:** Keep adjacent glass controls as independent surfaces and hit targets, but place them in one `AdaptiveLiquidGlassLayer` and make each child use that shared layer rather than an isolated one.

**Why:** Separate capture layers prevent the package renderer from blending the glass edges when interaction geometry overlaps. The package tab bar's pill and extra action share one parent layer, which is the reference pattern.

**How to apply:** Preserve each control's existing size, spacing, and gesture behavior. Use enough parent `clipExpansion` for the controls' press-scale and stretch bounds, and pass shared settings through the parent layer.

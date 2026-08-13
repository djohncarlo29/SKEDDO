---
name: Variable category row heights
description: Main Events category rows are independently measured and drag hit-testing follows the same variable-height geometry.
---

## Rule

The main Events category card must measure each flat item independently. A
title-only row uses the compact baseline, while wrapped titles or subtitles
grow only that item's slot. Outer-card height sums the item heights, and drag
positioning/hit-testing must use cumulative measured tops rather than a shared
row pitch.

**Why:** Accessibility text scaling can make one category row much taller than
its neighbors; using the tallest row globally wastes space and makes compact
rows look incorrectly padded.

**How to apply:** When changing category-row layout, update both the
`_CategoryCard` slot geometry and all list drag/reorder overlay calculations
together. Keep the shared measurement helper as the source of truth.
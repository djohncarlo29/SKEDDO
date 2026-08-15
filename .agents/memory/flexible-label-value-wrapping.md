---
name: Flexible label-value wrapping
description: Shared picker/settings rows choose label and trailing-value widths together to minimize wrapped row height.
---

The label and trailing value are independent flexible text blocks separated by
at least 25dp. When a single-line layout does not fit, choose widths by
comparing measured wrapped heights: minimize the row's maximum block height
first, then total text height.

**Why:** Reserving the value's remaining width after a preferred or fixed label
can make a short label force a long value into an unnecessary extra line.

**How to apply:** Reuse the shared row layout for picker and settings rows; do
not restore a label-priority or value-priority width heuristic.
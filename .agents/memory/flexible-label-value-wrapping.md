---
name: Flexible label-value wrapping
description: Shared picker/settings rows choose label and trailing-value widths together to minimize wrapped row height.
---

The label and trailing value are independent flexible text blocks separated by
at least 25dp. When a single-line layout does not fit, explicitly compare the
label-preserved, value-preserved, and shared-wrap alternatives using measured
wrapped heights: minimize the row's maximum block height first, then total text
height.

Words must never be allowed to split at a character boundary. Reject any
side-by-side allocation narrower than either block's widest word; if no valid
allocation remains, stack the value below the label and let the row grow.

**Why:** Reserving the value's remaining width after a preferred or fixed label
can make a short label force a long value into an unnecessary extra line.

**How to apply:** Reuse the shared row layout for picker and settings rows; do
not restore a label-priority or value-priority width heuristic, and do not make
shared wrapping the default when a one-sided candidate is shorter.

Category Type with Shopping List follows the Smart Category exception: preserve
the label on one line while the value can take the wrapped side without
bypassing the minimum gap; shared wrapping is only the fallback when that
allocation is not possible.

**Why:** These category values are long enough to trigger Dynamic Type wrapping,
but the label remains readable and should not wrap prematurely.
---
name: Flexible label-value wrapping
description: Shared picker/settings rows choose label and trailing-value widths together to minimize wrapped row height.
---

The label and trailing value are independent flexible text blocks separated by
at least 25dp. When a single-line layout does not fit, preserve the label at its
natural single-line width first and let a multi-word trailing value wrap. Only
when that label-preserved allocation cannot satisfy the gap/readability rules
should both blocks share wrapping.

Words must never be allowed to split at a character boundary. Reject any
side-by-side allocation narrower than either block's widest word; if no valid
allocation remains, stack the value below the label and let the row grow.

**Why:** Reserving the value's remaining width after a preferred or fixed label
can make a short label force a long value into an unnecessary extra line.

**How to apply:** Reuse the shared label-first row layout for every chevron-value
row, including picker/modal and settings rows. Keep words intact; if no
label-preserved side-by-side allocation remains, use shared wrapping or stack.

Category Type with Shopping List follows the Smart Category exception: preserve
the label on one line while the value can take the wrapped side without
bypassing the minimum gap; shared wrapping is only the fallback when that
allocation is not possible.

**Why:** These category values are long enough to trigger Dynamic Type wrapping,
but the label remains readable and should not wrap prematurely.
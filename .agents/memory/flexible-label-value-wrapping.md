---
name: Flexible label-value wrapping
description: Shared picker/settings rows choose label and trailing-value widths together to minimize wrapped row height.
---

The label and trailing value are independent flexible text blocks separated by
at least 25dp. When a single-line layout does not fit, normal multi-word rows
try exact word-boundary line counts in this order: value wrap 1, label wrap 1,
value wrap 2, label wrap 2, continuing the same alternation. The first
word-safe allocation that preserves the gap wins; stack only when no such
allocation exists.

A two-word value containing a one-character word (for example, "1 hour") is an
exception: treat the complete value as unbreakable first and let the label
wrap. Only when that protected value cannot coexist with a readable label does
the ordinary breakable-value fallback begin.

Words must never be allowed to split at a character boundary. Reject any
side-by-side allocation narrower than either block's widest word; if no valid
allocation remains, stack the value below the label and let the row grow.
When protecting a short two-word value, preserve its visible normal-looking
space; only the break opportunity changes.

**Why:** The value is the trailing content users scan first, so it should take
the first wrap opportunity without forcing the label to wrap prematurely.
Alternating one additional line at a time avoids a large jump in row height and
keeps the visible gap stable. Splitting a compact value such as "1 hour" still
creates an awkward one-character line break, so that pair remains protected.

**How to apply:** Reuse the shared row layout for every chevron-value
row, including picker/modal and settings rows. Keep words intact; try the
value-first alternating line-count sequence before falling back to a stack.

Category Type with Shopping List follows the Smart Category exception: preserve
the label on one line while the value can take the wrapped side without
bypassing the minimum gap; shared wrapping is only the fallback when that
allocation is not possible.

**Why:** These category values are long enough to trigger Dynamic Type wrapping,
but the label remains readable and should not wrap prematurely.
---
name: Month List fit and overflow
description: Fitting Month List content has no scroll range; natural overflow remains scrollable.
---

Size the empty Month List placeholder from the viewport remaining after the header and grid; it must fill space without creating scroll range when the grid fits. For eventful days, keep the list in its natural position immediately after the grid. If the document fits, put any remaining viewport space below the list; do not push its events down toward the tab bar. Only overflowing content should scroll, and at the actual bottom its final tile or collapsed section label should have a 16pt gap from the tab bar.

**Why:** Filling the space before a fitting event list makes the event appear pinned to the tab bar even though there is no scroll offset. Empty placeholders still need to fill the viewport, while eventful content must retain its natural position. Intrinsic sizing is unsafe when the document contains `LayoutBuilder`.

**How to apply:** Keep the minimum viewport height for eventful Month List documents, but position the list at the grid's natural bottom and leave any remaining height after the list. Avoid intrinsic-measurement wrappers around the `LayoutBuilder`-based month document. Test that fitting content has zero scroll range and stays next to the grid; for overflow, scroll to the actual end and measure the 16pt gap to the rendered tab bar.

**Why:** The AppShell’s rendered tab-bar bounds are the visible reference users compare against; a constants-only test can pass without proving the visible gap. Placing the pill inside the page's top-inset padding shifts the reference bar and can make the measurement misleading.

When the portrait compact title is active on an overflowing Month List, the Month document translates upward by the DOW text inset. Compensate the trailing scroll clearance by that inset multiplied by header collapse progress, including a negative target gap when the inset exceeds 16pt. This affects the final scroll boundary, not the natural position of a fitting event list. Compact-state widget tests must provide a scroll-title builder and bind the transition to the nested outer position; otherwise they can silently measure the expanded layout.

**Why:** The visual translation does not change the scroll extent, so unchanged tail padding produces an oversized visible gap. The isolated CalendarTab test does not receive the AppShell's automatic header binding.

**How to apply:** Keep the correction in the embedded DCV tail spacer and listen to `AppHeaderTitleTransition`; assert the final event or collapsed section against the rendered tab-bar top after setting the outer nested position to its maximum.

---
name: Month List fit and overflow
description: Fitting Month List content has no scroll range; natural overflow remains scrollable.
---

Size the empty Month List placeholder from the viewport remaining after the header and grid; it must fill space without creating scroll range when the grid fits. For eventful days, preserve the embedded DCV’s measured natural height. If the whole document fits, put unused space between the calendar grid and event list so the final item’s trailing clearance stays anchored to the tab bar; if it overflows, keep natural scroll extent and the same final clearance. The result should have zero scroll range when all content fits and a positive scroll range only when content overflows. Do not change the initial scroll offset.

**Why:** An empty placeholder can add artificial scroll extent, while minimum-height-only sizing for a fitting eventful document leaves unused space after its final item. Intrinsic sizing is also unsafe when the document contains `LayoutBuilder`.

**How to apply:** In Month List slivers, derive available height from `viewportMainAxisExtent - precedingScrollExtent`; compare it against post-layout grid and list sizes, keep the grid at the top, and align the list tail to the document bottom. Avoid intrinsic-measurement wrappers around the `LayoutBuilder`-based month document. For final-gap tests, render `FloatingTabPill` as a full-window sibling outside the page's top-inset padding, then measure its actual `GlassTabBar` bounds.

**Why:** The AppShell’s rendered tab-bar bounds are the visible reference users compare against; a constants-only test can pass without proving the visible gap. Placing the pill inside the page's top-inset padding shifts the reference bar and can make the measurement misleading.

When the portrait compact title is active, the Month document translates upward by the DOW text inset. Reduce the embedded list's trailing clearance by that inset multiplied by header collapse progress, including a negative target gap when the inset exceeds 16pt. Compact-state widget tests must provide a scroll-title builder and bind the transition to the nested outer position; otherwise they can silently measure the expanded layout.

**Why:** The visual translation does not change the scroll extent, so unchanged tail padding produces an oversized visible gap. The isolated CalendarTab test does not receive the AppShell's automatic header binding.

**How to apply:** Keep the correction in the embedded DCV tail spacer and listen to `AppHeaderTitleTransition`; assert the final event or collapsed section against the rendered tab-bar top after setting the outer nested position to its maximum.

---
name: Month List fit and overflow
description: Fitting Month List content has no scroll range; natural overflow remains scrollable.
---

Size the empty Month List placeholder from the viewport remaining after the header and grid; it must fill space without creating scroll range when the grid fits. For eventful days, preserve the embedded DCV’s measured natural height. If the whole document fits, put unused space between the calendar grid and event list so the final item’s trailing clearance stays anchored to the tab bar; if it overflows, keep natural scroll extent and the same final clearance. The result should have zero scroll range when all content fits and a positive scroll range only when content overflows. Do not change the initial scroll offset.

**Why:** An empty placeholder can add artificial scroll extent, while minimum-height-only sizing for a fitting eventful document leaves unused space after its final item. Intrinsic sizing is also unsafe when the document contains `LayoutBuilder`.

**How to apply:** In Month List slivers, derive available height from `viewportMainAxisExtent - precedingScrollExtent`; compare it against post-layout grid and list sizes, keep the grid at the top, and align the list tail to the document bottom. Avoid intrinsic-measurement wrappers around the `LayoutBuilder`-based month document.

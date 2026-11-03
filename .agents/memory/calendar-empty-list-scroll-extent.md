---
name: Month List fit and overflow
description: Fitting Month List content has no scroll range; natural overflow remains scrollable.
---

Size the empty Month List placeholder from the viewport remaining after the header and grid; it must fill space without creating scroll range when the grid fits. For eventful days, preserve the embedded DCV’s natural height and give its document at least the remaining viewport height. The result should have zero scroll range when all content fits and a positive scroll range only when content overflows. Do not force the initial content position away from the top.

**Why:** An empty placeholder can add artificial scroll extent, while a viewport-constrained eventful document can hide real overflow. Both cases need sizing based on actual content versus the remaining viewport.

**How to apply:** In Month List slivers, derive available height from `viewportMainAxisExtent - precedingScrollExtent`; fill that minimum for fitting content, and preserve natural document height for eventful lists that exceed it.

---
name: Calendar week-strip veil architecture
description: Per-week background behavior during calendar morphs and Month↔Day reveals.
---

Each calendar week background is part of that week strip's shared element. During the Year↔Month morph, paint separate row surfaces and interpolate each row from its mini-calendar position to its full-width Month View position; do not use one month-sized grid surface.

During the Month→Day collapse, lay out the Day content underneath the Month View. The DOW header remains fixed for Single Day and Multi Day, while each complete week row—including its surface, dates, markers, week number, and separator—acts as an opaque veil. Rows above the selected week move up and rows below move down. Keep the Month-owned selected row for this morph, then hand the settled strip off to the Day header stack so it shares the shell's live title-state coordinates and avoids the Month scroll viewport's independent inset/clip. The Day overlay owns timeline scrolling. List Day keeps its existing headerless layout by sliding the Month header group away.

Overflow dates in the first and last calendar rows follow the midpoint threshold only for the active selected week row. Adjacent non-selected rows must not reveal their next/previous-month dates just because collapse progress passed 0.5.

**Why:** A parent-level grid background or a Day layer painted above the Month rows can show the Day placeholder through the row spaces, making the week strips look detached from their content. In settled Day View, Month and Day header content can occupy different vertical origins even when their widget rectangles appear aligned; the nested Month viewport can clip the date cells. A Day-owned strip avoids both issues without adding a speculative translation to the Month panel.

**How to apply:** Keep settled Month, animated Month→Day, and Year mini-calendar rows as bounded surfaces; hand off only after the Month→Day animation settles. Verify the Day-owned strip is directly below DOW, directly above the banner, and outside the Month viewport clip in expanded and compact header states. Preserve the original List header slide-out.
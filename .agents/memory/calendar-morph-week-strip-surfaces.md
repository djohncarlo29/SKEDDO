---
name: Calendar week-strip veil architecture
description: Per-week background behavior during calendar morphs and Month↔Day reveals.
---

Each calendar week background is part of that week strip's shared element. During the Year↔Month morph, paint separate row surfaces and interpolate each row from its mini-calendar position to its full-width Month View position; do not use one month-sized grid surface.

During the Month→Day collapse, lay out the Day content underneath the Month View. The DOW header remains fixed for Single Day and Multi Day, while each complete week row—including its surface, dates, markers, week number, and separator—acts as an opaque veil. Rows above the selected week move up, rows below move down, and the selected row becomes the pinned Day strip. Once settled, restore Day content above the Month layer so its native scroll views receive gestures. List Day keeps its existing headerless layout by sliding the Month header group away.

**Why:** A parent-level grid background or a Day layer painted above the Month rows can show the Day placeholder through the row spaces, making the week strips look detached from their content; leaving the Month layer above after settling blocks Day rubber-band and timeline scrolling.

**How to apply:** Keep settled Month, pinned Day, and Year mini-calendar rows as bounded surfaces, preserve independent theme resolution through the existing background color resolver, keep reveal clips out of the Month→Day layer order, and preserve the original List header slide-out.
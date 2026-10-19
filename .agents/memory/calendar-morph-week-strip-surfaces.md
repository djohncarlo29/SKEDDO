---
name: Calendar week-strip veil architecture
description: Per-week background behavior during calendar morphs and Month↔Day reveals.
---

Each calendar week background is part of that week strip's shared element. During the Year↔Month morph, paint separate row surfaces and interpolate each row from its mini-calendar position to its full-width Month View position; do not use one month-sized grid surface.

During the Month→Day collapse, lay out the Day content underneath the Month View. The DOW header remains fixed for Single Day and Multi Day, while each complete week row—including its surface, dates, markers, week number, and separator—acts as an opaque veil. Rows above the selected week move up, rows below move down, and the selected row becomes the pinned Day strip at the existing Month content origin, which is already immediately below the DOW mask. Do not add a second header offset. Keep the Month row layer visible beneath the Day banner and timeline after settling so the dates remain present; the Day overlay stays above it and owns timeline scrolling. List Day keeps its existing headerless layout by sliding the Month header group away.

Overflow dates in the first and last calendar rows follow the midpoint threshold only for the active selected week row. Adjacent non-selected rows must not reveal their next/previous-month dates just because collapse progress passed 0.5.

**Why:** A parent-level grid background or a Day layer painted above the Month rows can show the Day placeholder through the row spaces, making the week strips look detached from their content. The existing Month content inset already places its origin below the title and DOW labels, so another header offset pushes the dates down into the banner. Hiding the Month row layer at handoff removes the week strip, while putting it in front of the Day overlay blocks timeline gestures.

**How to apply:** Keep settled Month, pinned Day, and Year mini-calendar rows as bounded surfaces, preserve independent theme resolution through the existing background color resolver, keep reveal clips out of the Month→Day layer order, align the selected row with the existing content origin without duplicating its inset, keep that row under Day content at rest, and preserve the original List header slide-out.
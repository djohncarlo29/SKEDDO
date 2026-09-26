---
name: Calendar morph week-strip surfaces
description: Per-week background behavior during the Year↔Month calendar morph.
---

Each calendar week background is part of that week strip's shared element. During the Year↔Month morph, paint separate row surfaces and interpolate each row from its mini-calendar position to its full-width Month View position; do not use one month-sized grid surface.

**Why:** A parent-level grid background can remain visually behind moving rows, which makes the strips look detached from their content during the zoom.

**How to apply:** Keep settled Month, pinned Day, and Year mini-calendar rows as bounded surfaces, and preserve independent theme resolution through the existing background color resolver.
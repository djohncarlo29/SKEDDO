---
name: Calendar search overlay scrim
description: The CalendarTab search overlay can look like a Year↔Month morph scrim when its full-viewport background is opaque.
---

The calendar search layer must remain transparent over the calendar viewport; a full-screen background surface there visually washes out the Year↔Month transition while leaving the AppShell header unchanged.

**Why:** The search overlay is mounted inside the calendar content Stack, below the AppShell header. Its full-viewport background therefore appears as a body-only grey veil and can be mistaken for a morph rendering problem.

**How to apply:** When debugging a calendar transition that is grey only below the header, inspect `_greyActive` / `_buildSearchOverlay` before changing `_MorphPainter` or List content geometry.
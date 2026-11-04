---
name: Calendar Day List header scroll ownership
description: Keep the shared AppShell title bound to the active List Day scroll position while calendar panels remain mounted.
---

For Calendar Day List, show the selected day's events through the shared DCV event-list renderer, including its timed sections and actions. Show the empty-state placeholder only when that selected day has no events. Bind the shared header only to the vertical scroll position receiving the user's direct scroll gesture. Hidden Month and preview panels can remain mounted and emit their own metrics; they must not replace the active Day List position. Reset the tracked owner when the calendar view or Day submode changes. Keep the separate Single/Multi Day timeline behavior unchanged.

**Why:** The List Day mode is a day-scoped DCV, not an always-empty placeholder. Users explicitly expect the same event grouping and interactions as other DCVs, while the empty state is reserved for days with no events. The empty Day List also uses a different scroll surface from retained month panels; unfiltered notifications can leave the shared title attached to a hidden panel.

**How to apply:** When changing Calendar Day List, preserve selected-day event grouping, shared DCV actions, and the empty-only fallback. When changing AppShell scroll-notification ownership, keep source-position filtering for the active user gesture and its subsequent updates; do not use this scroll rule for Single/Multi Day timeline scrolling.

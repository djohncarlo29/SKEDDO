---
name: Calendar Day List header scroll ownership
description: Keep the shared AppShell title bound to the active List Day scroll position while calendar panels remain mounted.
---

For Calendar Day List, bind the shared header only to the vertical scroll position receiving the user's direct scroll gesture. Hidden Month and preview panels can remain mounted and emit their own metrics; they must not replace the active Day List position. Reset the tracked owner when the calendar view or Day submode changes. Keep the separate Single/Multi Day timeline behavior unchanged.

**Why:** The empty Day List uses a different scroll surface from the retained month panels. Unfiltered notifications can leave the shared title attached to a hidden panel, so the visible empty state does not collapse and expand like a DCV.

**How to apply:** When changing AppShell scroll-notification ownership or Calendar Day List, keep source-position filtering for the active user gesture and its subsequent updates; do not use this rule for Single/Multi Day timeline scrolling.

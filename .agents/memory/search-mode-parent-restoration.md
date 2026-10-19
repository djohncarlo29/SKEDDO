---
name: Search-mode parent restoration
description: Product behavior for leaving search mode across Notes, Events, and Calendar.
---

Search is temporary. On exit, return to the parent screen at its pre-search position, with transient overscroll and unfinished gestures settled or canceled; keep the parent hierarchy and headers intact.

**Why:** The user explicitly wants opening and closing search to feel as if the parent screen was unaffected, including after rubberbanding or starting a swipe.

**How to apply:** When changing search entry or dismissal in any tab, preserve the normalized parent position and settle in-progress presentation gestures before the search overlay replaces the screen.

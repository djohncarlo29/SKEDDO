---
name: Search-mode parent restoration
description: Product behavior for leaving search mode across Notes, Events, and Calendar.
---

Search is temporary. On exit, return to the parent screen at its pre-search position, with transient overscroll and unfinished gestures settled or canceled; keep the parent hierarchy and headers intact.

Portrait inline search keeps the same search-bar widget in the pinned header while entering and exiting. Move it with the shared header transition; do not swap it into a sibling overlay. Off-screen search remains a separate overlay flow.

**Why:** The user explicitly wants opening and closing search to feel as if the parent screen was unaffected, including after rubberbanding or starting a swipe.

**How to apply:** Before search freezes shell header updates, sync the title from the parent's post-settle scroll metrics. Clamp Notes and Events scroll positions; finish released Calendar snaps (including their navigation callbacks), but center unreleased drags. Settle shell-level detail transitions too, so dismissing search restores a complete parent hierarchy.

**Why:** The inline bar disappearing during entry/exit was caused by moving its widget between the scroll header and a fixed overlay instead of animating one persistent header child.

**How to apply:** For portrait inline search in Notes and Events, preserve the search bar in the shared pinned-header slot for the whole transition; reserve the independent overlay for off-screen and landscape search paths.

---
name: Search-mode parent restoration
description: Product behavior for leaving search mode across Notes, Events, and Calendar.
---

Search is temporary. On exit, return to the parent screen at its pre-search position, with transient overscroll and unfinished gestures settled or canceled; keep the parent hierarchy and headers intact.

Portrait inline search keeps the same search-bar widget in the pinned header while entering and exiting. In active inline search, restore the fixed background and separator and keep the complete header pinned while results rubber-band. Do not move it into a sibling overlay. Off-screen search remains a separate overlay flow.

**Why:** The user explicitly wants opening and closing search to feel as if the parent screen was unaffected, including after rubberbanding or starting a swipe.

**How to apply:** Before search freezes shell header updates, sync the title from the parent's post-settle scroll metrics. Clamp Notes and Events scroll positions; finish released Calendar snaps (including their navigation callbacks), but center unreleased drags. Settle shell-level detail transitions too, so dismissing search restores a complete parent hierarchy.

**Why:** The inline bar disappearing during entry/exit was caused by moving its widget between the scroll header and a fixed overlay instead of animating one persistent header child.

**How to apply:** For portrait inline search in Notes and Events, preserve the search bar in the shared pinned-header slot for the whole transition; reserve the independent overlay for off-screen and landscape search paths.

**Why:** The inline result viewport must bounce independently, while the search bar and separator remain fixed. The shared header slot preserves the search field state and avoids a frame-long disappearance during entry or exit.

**How to apply:** Keep the fixed search header in the shared third-level header slot, pin that slot during inline search, and disable its normal rubberband translation. Do not change the off-screen overlay path.

Off-screen search is a stationary overlay: keep the shell header and toolbar at their existing positions, hide toolbar actions without sliding them, and show/remove the overlay without a fade. Preserve and restore the parent scroll state. Inline search keeps its existing animated header transition.

**Why:** The user wants off-screen search to cover the current screen and leave it unchanged on exit; only inline search should move the header chrome.

**How to apply:** In the AppShell off-screen activation path, do not drive the search-header or toolbar-slide controllers. Keep the overlay behavior local to Notes, Events, and Calendar, and restore both the page and shared header positions when it closes.

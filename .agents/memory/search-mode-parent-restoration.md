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

Off-screen search is an overlay, not a toolbar destination: keep the parent toolbar route stable while the overlay hides its pinned chrome. Inline search may use its own toolbar transition.

**Why:** Switching to an empty toolbar route on off-screen search exit replays the package's materialize/blur transition, making the parent chrome react to a temporary overlay.

**How to apply:** Do not push an empty toolbar route for off-screen search. Let the overlay hide the chrome on the existing route, and verify no toolbar morph runs during entry or exit; keep inline-search route behavior separate.

Off-screen search can temporarily shrink the parent's scroll extent or detach its ScrollPosition while shell and keyboard insets return. Never clamp or abandon the saved offset against that transient geometry. Retry until the position is attached and its range supports the saved offset, then restore and clear the lock; rebind the shared header after the tab confirms restoration.

**Why:** A single post-frame callback can run while the keyboard is still animating or the scrollable is detached. Clamping then loses the original offset; returning to zero is worse than the gradual drift it replaced.

**How to apply:** Notes, Events, and Calendar should retry restoration across layout frames when the controller is detached or the current extent is too small. Do not release the offscreen restoration lock until the saved offset has been applied, and have AppShell wait before rebinding the shared header.

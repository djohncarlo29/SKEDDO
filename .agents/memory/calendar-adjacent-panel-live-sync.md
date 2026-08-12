---
name: Live-synced adjacent swipe panels
description: How to keep off-screen prev/next preview panels' scroll position matching the current panel in real time, not just at panel-creation time.
---

In a 3-panel swipe architecture (prev | current | next, e.g. Smart Scheduler's
Calendar Month View and Year View), each side panel gets its own
`ScrollController` created lazily when its `ValueKey` changes (i.e. when it
becomes the new prev/next panel after a committed swipe).

That lazy-creation-only approach is not enough for a "single carried-forward
source of truth" scroll model, where whatever the current panel is scrolled to
right now should already be reflected in the adjacent panels *before* any
swipe starts. If the user scrolls the current panel after its neighbors were
created, the neighbors' controllers are stale until the next commit, causing a
visible snap/flicker mid-swipe.

**Fix pattern:** add a listener on the *current* panel's `ScrollController`
that, on every scroll tick, calls `.jumpTo(currentOffset)` on the prev/next
preview controllers (guarded by `hasClients`). This listener must be
re-attached every time the current controller is disposed/recreated (e.g. on
committed swipe, or on remount from a parent view transition) — easy to miss
one of the several recreation call sites.

**Why:** Users expect "scroll here, then swipe" to feel seamless; deferring
the sync to swipe-commit time is visually a downgrade even though the final
resting state is correct.

**How to apply:** Applied identically to both Month View (`_monthViewScrollCtrl`
→ `_syncPreviewScrollToCurrent`) and Year View (`_yearScrollCtrl` →
`_syncYearPreviewScrollToCurrent`) in Smart Scheduler's calendar_tab.dart. Any
new swipeable multi-panel view with scrollable panel content should follow the
same shape: carry-forward offset field, live-sync listener, and re-attachment
at every controller recreation site.

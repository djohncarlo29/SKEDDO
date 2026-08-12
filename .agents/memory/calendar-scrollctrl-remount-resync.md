---
name: ScrollController remount resets to stale initialScrollOffset
description: Why a ValueKey-remounted Scrollable can silently jump to a stale offset even though the same ScrollController instance is reused, and how that broke Day View's week-strip pinning across month boundaries.
---

A `ScrollController`'s `initialScrollOffset` is fixed at construction time and is
re-used by **every** future `createScrollPosition()` call for that controller
instance — not just the first. Calling `jumpTo(x)` only moves the *currently
attached* `ScrollPosition`; it does not update what a *future* remount will
start at. So if a `Scrollable`'s `ValueKey` changes (forcing a full
unmount/remount) while reusing the same controller, the newly-attached
position resets to the controller's original `initialScrollOffset`, not
wherever `jumpTo()` last left it.

**Why this matters:** in the calendar's Day View, a pinned week-row's
on-screen position is computed as `contentTop(field) - viewportScrollOffset`.
The field (`_collapseScrollOffset`) is kept at a steady 0.0 while at rest in
Day View. Any Day-View navigation that crosses a month/year boundary changes
the underlying `_MonthView`'s key and forces a remount — and because the
month-view `ScrollController` was last constructed with whatever offset the
user had scrolled to back in Month View, the remount silently re-seeded the
viewport at that stale nonzero value while the field stayed 0, so the pinned
row rendered off-screen (looked like the week strip "disappeared").

**How to apply:** whenever code intentionally causes a `Scrollable` to remount
via a key change, and some other piece of state assumes the controller's live
offset is a specific value (e.g. 0), dispose and recreate the controller with
`initialScrollOffset` set to that same value *before* the remount happens —
don't rely on `jumpTo()` to have "fixed" it for next time.

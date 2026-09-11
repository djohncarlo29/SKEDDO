---
name: Editable DCV section keyboard reveal
description: Keyboard visibility behavior for inline-editable custom section headers in the Category Detail View.
---

## Rule

An inline section header that autofocuses inside the DCV's scrollable content must reveal itself after focus, after keyboard insets change, and after text edits that can add wrapped lines.

**Why:** Focus can happen before the keyboard resizes the viewport, and a title can become taller after the initial reveal. A single focus-time scroll leaves lower lines hidden on shorter screens.

**How to apply:** Keep the reveal scheduled post-frame, use `Scrollable.ensureVisible` on the editable header, and repeat it from the text field's `onTap`, the focus listener, `didChangeMetrics`, and `onChanged` callback.

The app shell is a custom full-screen Stack rather than a Scaffold, so the DCV
viewport must explicitly reserve `MediaQuery.viewInsets.bottom` while a
section field is focused. Without that reserved space, ensureVisible measures
against content hidden behind the keyboard and can report the row as visible.

**Why:** A custom Stack does not automatically apply the keyboard inset to its
content height, especially on the native/web preview path.

**How to apply:** Add the bottom keyboard inset only while the Events tab has
an active DCV, leaving other tabs and the keyboard-hidden layout unchanged.

Reveal calls triggered by `onChanged` must use a keep-visible policy rather
than explicit alignment. Explicit alignment recenters an already-visible
section on every keystroke, making the DCV jump upward as soon as typing starts.

**Why:** The keyboard inset changes the viewport once, but text edits can fire
many reveal callbacks. Re-centering on each callback does not reflect a real
visibility problem and breaks the stable pre-typing position.

**How to apply:** Preserve the current scroll offset when the header is visible
and scroll only the minimum distance needed when a wrapped line becomes
occluded.

When a focused header shrinks from multiple lines to one, compensate the
scroll offset by the removed height if the header was anchored near the
keyboard. This removes the stale gap without moving sections that were not
near the viewport edge.

**Why:** The viewport keeps its prior scroll offset after the header's layout
height decreases, so the keyboard-safe position can retain one line's worth of
empty space.

**How to apply:** Measure the header before and after layout, subtract only the
negative height delta from the active scroll position, clamp to scroll bounds,
then run the keep-visible reveal.
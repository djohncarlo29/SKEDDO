---
name: Calendar timeline rubberband synchronization
description: Preserve local elastic overscroll when adjacent day timelines share their scroll position.
---

Shared Single Day and Multi Day timeline offsets should receive only in-range scroll positions. Do not publish elastic overscroll through a shared notifier if its listeners clamp and `jumpTo` the receiving controllers; that synchronous correction cancels the active timeline's native rubberband.

**Why:** Adjacent day panels share a vertical position, but each active scrollable must retain ownership of its own elastic motion at the leading and trailing edges.

**How to apply:** Keep ordinary in-range offset propagation unchanged, and skip notifier updates while the source `ScrollPosition` is out of range. Keep `BouncingScrollPhysics` on both timeline modes.

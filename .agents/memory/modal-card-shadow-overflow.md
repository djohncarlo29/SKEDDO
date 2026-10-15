---
name: Modal card shadow overflow
description: Keep modal card shadows visible when they extend beyond a sheet's scroll viewport.
---

Modal card shadows need to paint beyond the primary scroll viewport and the shared scroll-under wrapper. A normal `SizeTransition` adds its own hard-edge clip even when fully open, so transitions around standalone cards need a shadow-aware clip that expands only at the fully open endpoint. The rounded sheet route remains the outer boundary.

**Why:** Scroll views, their containing stack, and `SizeTransition` each add independent clips; disabling only the scroll viewport clips does not fix cards inside animated sections. Removing the route's rounded clip instead would let content spill outside the sheet.

**How to apply:** For every scrollable passed to `ModalSheetScrollUnder`, set `clipBehavior: Clip.none`, and keep the wrapper stack unclipped. For a standalone card inside a vertical `SizeTransition`, use a shadow-aware transition that retains the normal clip while animating and expands the clip only when fully open. Preserve the outer rounded route clip.

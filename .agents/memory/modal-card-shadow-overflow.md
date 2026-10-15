---
name: Modal card shadow overflow
description: Keep modal card shadows visible when they extend beyond a sheet's scroll viewport.
---

Modal card shadows need to paint beyond both the primary scroll viewport and the shared scroll-under wrapper. Keep their clipping disabled; the rounded sheet route remains the outer boundary that preserves the sheet silhouette.

**Why:** Scroll views and their containing stack default to hard-edge clipping, which cuts decorated card shadows when a card reaches a viewport edge. Removing the route's rounded clip instead would let content spill outside the sheet.

**How to apply:** For every scrollable passed to `ModalSheetScrollUnder`, set `clipBehavior: Clip.none`, and keep the wrapper stack unclipped. Preserve the outer rounded route clip.

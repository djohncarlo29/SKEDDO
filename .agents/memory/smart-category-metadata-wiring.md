---
name: Smart Category metadata wiring
description: The shared event card already supports Standard Category metadata, but the Smart Category detail-view call site must explicitly enable it.
---

Smart Category event metadata is controlled at the `_CategoryDetailView` construction site; enabling the shared card or ghost renderer alone is not enough.

**Why:** The renderer defaults the category line off so ordinary event lists keep their existing appearance. A missing call-site flag makes an apparently implemented feature invisible in both normal and drag-preview tiles.

**How to apply:** When changing Smart Category event metadata, verify the detail-view flag, the grouped card path, and the drag/reorder ghost path together.
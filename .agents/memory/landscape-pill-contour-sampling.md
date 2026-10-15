---
name: Landscape pill contour sampling
description: Rendering rule for the Light Mode contour on the Floating Tab Bar and Settings preview.
---

Keep the portrait contour profile unchanged. In landscape, use denser geometry sampling for the short end caps of both the Floating Tab Bar and Settings preview; invalidate the painter when orientation changes. Keep the contour Light Mode-only.

**Why:** A fixed angular sample count leaves too few points across the narrow end-cap angles of long landscape pills, creating visible facets.

**How to apply:** Preserve portrait rendering, scale landscape sampling with the current pill aspect ratio, and verify both surfaces use the same treatment without adding the contour in Dark Mode.

---
name: Landscape pill contour sampling
description: Rendering rule for the Light Mode contour on the Floating Tab Bar and Settings preview.
---

Use a 1px minimum contour width for both the Floating Tab Bar and Settings preview. Preserve the portrait sampling count; in landscape, use denser geometry sampling for short end caps and invalidate the painter when orientation changes. Keep the contour Light Mode-only.

**Why:** A fixed angular sample count leaves too few points across the narrow end-cap angles of long landscape pills, creating visible facets.

**How to apply:** Share the 1px minimum across both surfaces and orientations, scale landscape sampling with the current pill aspect ratio, and keep the glass fill and Dark Mode behavior unchanged.

---
name: Landscape pill contour sampling
description: Rendering rule for the Light Mode contour on the Floating Tab Bar and Settings preview.
---

Use a 1px minimum contour width for both the Floating Tab Bar and Settings preview. The white rim alpha follows the normalized Liquid Glass slider exactly (0–100%), independently of the glass material's 0.2–0.8 opacity range. Preserve the portrait sampling count; in landscape, use denser geometry sampling for short end caps and invalidate the painter when orientation changes. Keep the contour Light Mode-only.

**Why:** The setting's 0% position still uses translucent material opacity, so the rim must follow normalized slider progress rather than copying the raw material opacity. A fixed angular sample count also leaves too few points across long landscape end caps.

**How to apply:** Share the 1px minimum and normalized white-rim alpha across both surfaces and orientations, scale landscape sampling with the current pill aspect ratio, and keep the glass fill and Dark Mode behavior unchanged.

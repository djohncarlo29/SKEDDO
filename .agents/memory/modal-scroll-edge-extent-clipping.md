---
name: Modal scroll-edge extent and clipping
description: The top scroll-under effect's extent and sheet-boundary clipping.
---

For modal scroll-under effects, derive both the top fade and blur extent from the scroll view's actual resting top content inset. They must both reach zero exactly at the first content card's top edge; do not use a fixed transition tail. Clip the effect with the containing sheet's actual top shape, including transparent corner cutouts. Popup sheets with a different radius must pass their own shape.

**Why:** A short or independently tuned fade/blur stops before the first card, while an unclipped backdrop filter can paint into the transparent rounded corners.

**How to apply:** Keep the measured first-content position as the single source for both fade and blur; ensure the edge-effect wrapper uses the same `ShapeBorder` as its parent sheet.
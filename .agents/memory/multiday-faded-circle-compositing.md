---
name: Multi-Day faded circle compositing
description: Keep overlapping 40% today and adjacent Multi-Day circles from becoming darker during swipes.
---

When the fixed today marker and moving adjacent Multi-Day marker are both faded, draw their opaque circle union inside one composited layer and apply 40% opacity once. Keep the selected full-opacity circle and text overlays above that layer.

**Why:** Separate source-over widgets compound alpha in the overlap region, making the circles visibly darker than either marker.

**How to apply:** Share only the two faded marker geometries in the overlay; keep the selected marker in normal row content so its full opacity and existing movement remain unchanged.
---
name: Independent Multi-Day faded circles
description: Keep today and adjacent Multi-Day markers visually fixed-size while their centers move during horizontal drags.
---

Render the fixed today marker and moving adjacent Multi-Day marker as separate circles at the authored diameter and 40% opacity. During a swipe, translate their centers only; never paint them as one union shape or apply a scale to their faded marker layer.

**Why:** A shared opaque union makes the two markers read as one wider shape as the moving marker approaches today, even when each mathematical radius is unchanged.

**How to apply:** Keep faded markers in the normal day-circle render tree with fixed-size enabled. The selected marker may translate independently, while today and the adjacent marker retain their own circle bounds.
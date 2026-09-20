---
name: Multi-Day faded-circle compositing
description: Composite today and adjacent Multi-Day markers once without changing their independent fixed geometry.
---

Render the fixed today marker and moving adjacent Multi-Day marker as separate fixed-size circle widgets inside one opacity layer. Apply 40% opacity to the parent layer, not to either child, so overlap remains 40% rather than becoming 80%.

**Why:** Separate 40% source-over circles compound alpha where they overlap. A custom-painter union also made the markers read as an enlarged combined shape during the drag.

**How to apply:** Position each child with its own fixed diameter and translate only its center. Keep the overlay behind the full-opacity selected marker and the number overlay; do not apply a scale or draw both markers as one custom-painter silhouette.
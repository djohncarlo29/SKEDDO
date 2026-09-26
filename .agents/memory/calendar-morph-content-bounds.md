---
name: Calendar morph content bounds
description: Layout rule for list content embedded inside the Year↔Month morph overlay.
---

When list content is inserted into the calendar morph as a Positioned child, size the
alignment wrapper to its child and calculate empty-state height from the space below
the month grid. Do not let a loose viewport constraint turn the selected-day content
into a full-overlay layer. Keep the morph painter itself opaque with the resolved
calendar background, and fade List-only dots/content across the Month-side half.

**Why:** A viewport-sized alignment wrapper can make the embedded list surface read as
a grey veil over the Year↔Month transition, even though the event cards or placeholder
are the only intended content. During the hierarchy handoff, a transparent morph
layer can also expose the route’s gray backing color; hard midpoint insertion makes
the List mode visibly different from the other month modes.

**How to apply:** Keep the midpoint handoff and list content mounted as designed, but
use a content-sized Align and subtract the grid origin when measuring the empty-state
region. Paint the resolved background once at the start of the morph painter, and use
the same second-half alpha for List dots and the embedded selected-day content.
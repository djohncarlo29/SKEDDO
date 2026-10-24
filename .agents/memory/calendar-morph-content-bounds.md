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

## Empty Month List landing alignment

For an empty Month List day, compute the settled placeholder height from the
viewport remaining below the actually remaining shared large-title extent and
month grid, then subtract the floating-tab-bar clearance. The title extent must
collapse with the shared header; a portrait-only constant 57px slot leaves the
empty placeholder too high in compact state. Do not retain a fixed-expanded-region
centering correction after making the placeholder region respond to that extent.

**Why:** The grid scrolls as the shared title collapses, and the available
placeholder area grows. Keeping the expanded title slot subtracted after collapse
made the placeholder remain above the center of that newly available area.

**How to apply:** Keep the settled empty-state height aligned with
`viewportHeight - remainingTitleExtent - gridHeight - clearance`, using the shared
collapse position for `remainingTitleExtent`. Preserve the expanded measurement and
let the collapse-aware empty region account for its own centering. Do not subtract
the app-header leading inset again; `AppHeaderScrollViewport` and its matching
content inset already cancel one another.
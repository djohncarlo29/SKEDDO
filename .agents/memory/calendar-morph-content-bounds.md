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

For an empty selected day, compute the settled placeholder height from the viewport
remaining below both the shared 57px second-level title slot and the month grid, then
subtract the floating-tab-bar clearance. The title slot is present either as the
scrollable title widget or as portrait top padding.

**Why:** The Year→Month morph measures the List content's actual top after the title
slot, while the settled formula previously subtracted only the grid. That extra space
made “No Events” settle lower than its transition position.

**How to apply:** Keep the settled empty-state height aligned with
`viewportHeight - measuredListContentTop - clearance`. Do not subtract the app-header
leading inset again; `AppHeaderScrollViewport` and its matching content inset already
cancel one another.
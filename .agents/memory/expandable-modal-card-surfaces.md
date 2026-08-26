---
name: Expandable modal card surfaces
description: Shared visual rule for modal rows that reveal nested rows or inline pickers.
---

Expandable modal row stacks must render inside one `BoundedSquircleStadiumBorder` surface in every state. Keep the animated child content inside that surface and use separators between rows; do not compose separate top-only and bottom-only cards.

**Why:** Separate animated cards expose seams and duplicate corners while rows expand and collapse, especially when a picker or end-date subrow appears.

**How to apply:** When adding or changing a modal row with a subrow, put the parent row and its `SizeTransition`/picker content in the same card children list. This applies equally to the main event sheets and their Custom Repeat subsheets.
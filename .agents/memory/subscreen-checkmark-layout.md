---
name: Subscreen checkmark layout
description: Shared spacing and Dynamic Type rules for selectable subscreen rows.
---

Selectable subscreen rows must use one shared trailing checkmark slot: use the
same `CupertinoIcons.checkmark` glyph as Calendar and modal menu selections at
17 pt scaled through the active OS text scaler. The row keeps 16 pt from the
checkmark to its trailing edge, and labels stop at least 16 pt before the
checkmark slot. Reserve the slot for unselected rows too.

**Why:** Default Category was implemented separately and allowed its label and
unscaled checkmark geometry to diverge from the established subscreen pattern.

**How to apply:** Build every future selectable settings/subscreen row from the
shared slot rather than placing an icon directly after an Expanded label.
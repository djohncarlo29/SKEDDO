---
name: Subscreen checkmark layout
description: Shared spacing and Dynamic Type rules for selectable subscreen rows.
---

Rows and cards with a trailing selection checkmark use one shared slot: the
same `CupertinoIcons.checkmark` glyph as Settings subscreens, at 17 pt scaled
through the active OS text scaler. The row's outer 16 pt inset puts the mark
16 pt from the card edge; labels stop at least 16 pt before the slot. Reserve
the slot for unselected rows too. Use it in Settings and modal picker rows.

**Why:** Independently built picker rows used a different glyph and let labels
shift as selection moved, even when their nominal icon size matched Settings.

**How to apply:** Build every selectable row with a trailing value-area check
from the shared slot rather than placing an icon directly after an Expanded
label.
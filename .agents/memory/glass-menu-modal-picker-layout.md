---
name: Modal picker menu layout
description: Selection mark sizing and spacing for modal-sheet picker menus
---

Modal-sheet `GlassMenu` pickers show a 17pt OS-text-scaled selection checkmark in the leading slot. Every row reserves that slot, labels follow with a 16pt gap, and the trailing side stays empty. The checkmark starts 16pt from the menu surface edge.

**Why:** The picker should read as checkmark → label → blank and match the Calendar `GlassBarItem.menu` checkmark size while respecting OS text-size scaling.

**How to apply:** Keep the picker platter's content inset at zero when each row already has a 16pt horizontal inset. Use `MediaQuery.textScalerOf(context).scale(17)` for the checkmark and slot, and do not add trailing icons to picker options.

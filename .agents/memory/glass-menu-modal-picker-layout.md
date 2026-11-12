---
name: Modal picker menu layout
description: Selection mark sizing and spacing for modal-sheet picker menus
---

Modal-sheet `GlassMenu` pickers show a 17pt OS-text-scaled selection checkmark in the leading slot. Every row reserves that slot, labels follow with a 16pt gap, and the trailing side stays empty. The checkmark starts 16pt from the menu surface edge. If the full menu cannot fit beside its trigger, keep the platter anchored to the trigger edge, cap its viewport to the available side, and scroll its options instead of clamping the whole platter away.

**Why:** The picker should read as checkmark → label → blank, match the Calendar `GlassBarItem.menu` checkmark size while respecting OS text-size scaling, and retain a clear relationship to the trailing value even when many choices overflow.

**How to apply:** Keep the picker platter's content inset at zero when each row already has a 16pt horizontal inset. Use `MediaQuery.textScalerOf(context).scale(17)` for the checkmark and slot, and do not add trailing icons to picker options. For overflow, choose below if it fits, otherwise above if it fits, otherwise use the side with more room and let the menu's existing scroll view handle the rest.

---
name: Modal picker menu layout
description: Selection mark sizing and spacing for modal-sheet picker menus
---

Modal-sheet `GlassMenu` pickers mirror Calendar `GlassBarItem.menu`: the platter has a 12pt content inset plus each row's 16pt inset, placing the 24pt OS-scaled leading icon slot 28pt from the surface edge. A 17pt OS-scaled checkmark sits centered in that slot, followed by a 12pt icon-label gap and 17pt label text; every row reserves the slot and has no trailing icons. If the full menu cannot fit beside its trigger, keep the platter anchored to the trigger edge, cap its viewport to the available side, and scroll its options instead of clamping the whole platter away.

**Why:** The picker should match Calendar menu typography and spacing, keep the checkmark readable at OS text sizes, and retain a clear relationship to the trailing value when options overflow. Its glass should follow the Settings slider with the same GlassPopover opacity and blur curve used by Calendar menus.

**How to apply:** Use a 12pt platter content inset, 16pt row inset, 24pt scaled icon slot, 17pt scaled checkmark, 12pt icon-label gap, and 17pt title. Listen to `appLiquidGlassOpacityNotifier` and pass `skeddoPopoverGlassSettingsFor` through `skeddoNavigationGlassSettingsFromShared`. For overflow, choose below if it fits, otherwise above if it fits, otherwise use the side with more room and scroll.

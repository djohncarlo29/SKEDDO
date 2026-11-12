---
name: Modal picker menu layout
description: Selection mark sizing and spacing for modal-sheet picker menus
---

Modal-sheet `GlassMenu` pickers mirror Calendar `GlassBarItem.menu`: use premium glass, the same popover slider curve, and SKEDDO's half-strength Dark Mode edge lighting. The platter has a 12pt content inset plus each row's 16pt inset, placing the 24pt OS-scaled leading icon slot 28pt from the surface edge. A 17pt OS-scaled checkmark sits centered in that slot, followed by a 12pt icon-label gap and 17pt label text; every row reserves the slot, allows multiline wrapping, and has no trailing icons. Disable the selector/interaction highlight while preserving normal taps. If the full menu cannot fit beside its trigger, keep the platter anchored to the trigger edge, cap its viewport to the available side, and scroll its options instead of clamping the whole platter away.

**Why:** Picker menus should match Calendar menu typography, spacing, rendering quality, and neutral row behavior while keeping long choices readable and the checkmark accessible at OS text sizes.

**How to apply:** Use a 12pt platter inset, 16pt row inset, 24pt scaled icon slot, 17pt scaled checkmark, 12pt gap, and 17pt title. Set premium quality, `showItemInteractionHighlight: false`, and `allowTextWrapping: true`; listen to `appLiquidGlassOpacityNotifier` and pass `skeddoPopoverGlassSettingsFor` through `skeddoNavigationGlassSettingsFromShared`. Since `GlassMenu.onClose` fires at the start of the reverse morph, keep the modal's picker-open guard until `GlassMenuController.isOpen` becomes false. For overflow, choose below if it fits, otherwise above if it fits, otherwise use the side with more room and scroll.

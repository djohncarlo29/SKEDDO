---
name: Large confirmation sheet radius
description: The radius exception for the microphone permission and Delete Group overlay sheets.
---

The archive/delete confirmation sheet is the reference geometry: its outer sheet card uses a fixed 24px `BoundedSquircleStadiumBorder`, and its buttons use a separate fixed 24px radius. The microphone access sheet and the other gel-bloom confirmation surfaces follow that same 24px/24px pairing. The discard confirmation popover is a separate shape: its outer platter uses a 34px radius, with 22px top inset, the shared 20.33px message-to-action gap, and a 48px minimum-height action button with a fixed 24px radius. The action button grows from measured wrapped text using the active OS text scaler and uses the same resolved destructive red as alert actions. Dismiss buttons retain their separate token and layout.

**Why:** Archive/delete is the product reference for gel-bloom confirmation surfaces, while the anchored discard popover needs a larger platter to match the alert-dialog shape. Separate outer and action radii preserve curvature as multiline labels grow; a fixed-height discard button clips its label at accessibility text sizes.

**How to apply:** Use the shared confirmation-sheet token for the microphone, archive/delete, group/category, utility, and other matching gel-bloom cards. Keep the discard popover's separate 34px surface token and 24px button token. Use the shared message-to-action gap for the alert platter and discard popover. Do not change the regular rounded sheet route or the dismiss sheet's distinct spacing and token. For text-bearing glass action buttons, measure at the current `TextScaler`, including wrapping, and preserve the fixed radius while expanding height.
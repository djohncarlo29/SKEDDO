---
name: Large confirmation sheet radius
description: The radius exception for the microphone permission and Delete Group overlay sheets.
---

The archive/delete confirmation sheet is the reference geometry: its outer sheet card uses a fixed 24px `BoundedSquircleStadiumBorder`, and its buttons use a separate fixed 24px radius. The microphone access sheet and the other gel-bloom confirmation surfaces follow that same 24px/24px pairing. Dismiss buttons retain their separate token and layout.

**Why:** Archive/delete is the product reference for these confirmation surfaces. Keeping the outer sheet and button tokens separate prevents multiline button labels from changing their corner curvature, while preserving each sheet's existing insets and behavior.

**How to apply:** Use the shared confirmation-sheet token for the microphone, archive/delete, group/category, utility, and other matching gel-bloom cards. Use the shared fixed button token for their action buttons. Do not change the regular rounded sheet route or the dismiss sheet's distinct spacing and token.
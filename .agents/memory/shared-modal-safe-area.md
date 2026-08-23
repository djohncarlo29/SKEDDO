---
name: Shared modal safe-area handling
description: The project-wide rule for persistent bottom navigation and home-indicator insets in panels, sheets, and overlays.
---

Persistent bottom system space must be derived from the larger of `viewPadding.bottom` and `systemGestureInsets.bottom`, while keyboard `viewInsets` remain excluded. Apply that safe area once at a shared container boundary; do not rely on implicit package padding and do not add it again in individual child sheets.

**Why:** Different Android navigation modes and iPhone home indicators report different bottom values, and implicit package padding previously caused layered surfaces to drift or child sheets to double-count the inset.

**How to apply:** Keep the Floating Tab Bar's minimum design spacing separate from the persistent safe-area value. For Settings, sub-screens, modal sheets, and transient bottom overlays, preserve authored spacing and add the shared safe-area inset once. Remove any child-level safe-area padding when the shared parent already supplies it.
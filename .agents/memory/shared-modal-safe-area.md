---
name: Shared modal safe-area handling
description: The project-wide rule for persistent bottom navigation and home-indicator insets in panels, sheets, and overlays.
---

Persistent bottom system space must be derived from the larger of `viewPadding.bottom` and `systemGestureInsets.bottom`, while keyboard `viewInsets` remain excluded. Apply that safe area once at a shared container boundary; do not rely on implicit package padding and do not add it again in individual child sheets.

**Why:** Different Android navigation modes and iPhone home indicators report different bottom values, and implicit package padding previously caused layered surfaces to drift or child sheets to double-count the inset.

**How to apply:** Use the shared bottom-padding helper for surfaces that follow the Floating Tab Bar rule: `max(16px, persistentSystemInset)`. Apply it once at the shared panel/sheet boundary using unpainted padding; do not round it to the layout grid, add another 16px, or create a separately colored safe-area band.

**Why:** Keeping the minimum and system inset in one helper prevents Android navigation modes and iOS home-indicator variants from producing additive spacing or inconsistent transparent/invisible behavior across panels.
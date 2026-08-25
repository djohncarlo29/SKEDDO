---
name: Shared modal safe-area handling
description: The project-wide rule for persistent bottom navigation and home-indicator insets in panels, sheets, and overlays.
---

Persistent bottom system space must be derived from the larger of `viewPadding.bottom` and `systemGestureInsets.bottom`, while keyboard `viewInsets` remain excluded. Apply that safe area once at a shared container boundary; do not rely on implicit package padding and do not add it again in individual child sheets. Modal sheet routes use the persistent inset itself; only surfaces following the Floating Tab Bar rule use the separate 16px minimum.

**Why:** Different Android navigation modes and iPhone home indicators report different bottom values, and implicit package padding previously caused layered surfaces to drift or child sheets to double-count the inset.

**How to apply:** Use the shared bottom-padding helper only for surfaces that follow the Floating Tab Bar rule: `max(16px, persistentSystemInset)`. For modal sheet routes, apply `persistentSystemInset` directly once at the route boundary using padding and matching backing paint; do not add another 16px or create an authored bottom band.

**Why:** Keeping the minimum and system inset in one helper prevents Android navigation modes and iOS home-indicator variants from producing additive spacing or inconsistent transparent/invisible behavior across panels; separating modal routes prevents the tab bar's design margin from becoming a visible strip below sheets.
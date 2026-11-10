---
name: Shared modal safe-area handling
description: The project-wide rule for persistent bottom navigation and home-indicator insets in panels, sheets, and overlays.
---

Persistent bottom system space must be derived from the larger of `viewPadding.bottom` and `systemGestureInsets.bottom`, while keyboard `viewInsets` remain excluded. Apply that safe area once at a shared container boundary; do not rely on implicit package padding and do not add it again in individual child sheets. Modal sheet routes use the persistent bottom inset itself and place both parent and nested sheet tops exactly 10px below the top safe-area inset.

**Why:** Different Android navigation modes and iPhone home indicators report different bottom values, and implicit package padding previously caused layered surfaces to drift or child sheets to double-count the inset.

**Why:** Applying landscape insets only to sheet contents left the modal surface edge-to-edge and hid the dimmed AppShell from the side gutters.

**Why:** The sheet scroll-edge overlay previously expanded to physical-screen width. Once the landscape route itself is inset, that full-bleed layer can extend past the sheet and obscure its rounded corners.

**How to apply:** Use the shared bottom-padding helper only for surfaces that follow the Floating Tab Bar rule: `max(16px, persistentSystemInset)`. For modal sheet routes, do not apply route-level bottom padding. Keep the sheet surface full-height within its route bounds and size the translated page to the viewport remaining after the top safe-area inset plus the 10px gap. In landscape, constrain the complete sheet route—including its surface, clipping, transitions, and drag hit area—to the horizontal system-safe inset; leave the AppShell full-width behind the transparent side gutters. Keep scroll-edge effects at the local sheet viewport width, never the physical window width. Each modal scroll view must use `max(authoredBottomPadding, persistentSystemInset)` for its final content clearance; the primary Event, Category, Group, and Edit Sections sheets use a 16px authored clearance. Resolve the persistent inset from both the inherited MediaQuery and the underlying FlutterView so route-level MediaQuery padding changes cannot erase landscape navigation space.

**Why:** Keeping the minimum and system inset in one helper prevents Android navigation modes and iOS home-indicator variants from producing additive spacing or inconsistent transparent/invisible behavior across panels; separating modal routes prevents the tab bar's design margin from becoming a visible strip below sheets.
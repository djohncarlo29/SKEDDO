---
name: GlassPopover landscape safe area
description: Prevent double-counting platform safe-area insets in GlassPopover placement.
---

**Rule:** Use the intended edge gap as `GlassPopover.screenPadding`; do not add `AppWindowContentScope.horizontalInset` to it.

**Why:** GlassPopover adds the root `FlutterView` padding itself while clamping its overlay. Adding the app's landscape inset again shifts the popover away from its trigger.

**How to apply:** When anchoring GlassPopover to an in-window control in landscape, leave the normal 12px screen padding and let the package account for physical view insets.

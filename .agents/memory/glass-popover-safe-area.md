---
name: GlassPopover placement boundaries
description: Keep GlassPopover safe-area clamping and discard-only morph offsets scoped correctly.
---

**Rule:** Use the intended edge gap as `GlassPopover.screenPadding`; do not add `AppWindowContentScope.horizontalInset` to it.

**Why:** GlassPopover adds the root `FlutterView` padding itself while clamping its overlay. Adding the app's landscape inset again shifts the popover away from its trigger.

**How to apply:** When anchoring GlassPopover to an in-window control in landscape, leave the normal 12px screen padding and let the package account for physical view insets.

**Rule:** Keep the shared GlassPopover offset at zero. Only the discard-confirmation sheet opts into its 4px upper-left morph target.

**Why:** The user wants this placement adjustment only for the discard sheet; future and unrelated popovers must remain trigger-aligned.

**How to apply:** Set an explicit offset at the discard-sheet call site, never in package defaults or a shared wrapper.

**Rule:** When a GlassPopover uses a target offset, move its trigger ghost by that same interpolated offset during the morph.

**Why:** Moving only the expanding body separates the two glass shapes and can leave a detached crescent near the trigger.

**How to apply:** Keep the anchor and body trajectories synchronized for every nonzero `popoverOffset`; zero-offset popovers retain their existing path.

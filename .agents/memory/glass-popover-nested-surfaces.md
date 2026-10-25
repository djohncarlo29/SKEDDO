---
name: Independent GlassPopover surfaces
description: Package GlassPopover content normally shares the morphing parent surface; render nested glass controls independently when they need their own optical boundary.
---

**Rule:** Do not render an independent `GlassButton` directly inside `GlassPopover`'s clipped `GlassContainer`. Reserve its layout slot in the popover, then render the whole button in the root overlay with `CompositedTransformTarget`/`CompositedTransformFollower` so it tracks the slot without inheriting the popover clip.

**Why:** The package's own guidance warns against nesting independent glass controls inside `GlassContainer`; its morphing clip can cut the own-layer render even while the label remains in its normal layout position. Insets and edge-fade masks do not correct that layer/clip mismatch.

**How to apply:** Keep a same-size in-flow placeholder for measurement and scrolling, anchor the overlay button to it, show the portal only while the popover is open, and disable its hit testing during close. Preserve the button's own tint/settings and the original layout spacing.

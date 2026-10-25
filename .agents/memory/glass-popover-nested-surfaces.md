---
name: Independent GlassPopover surfaces
description: Package GlassPopover content normally shares the morphing parent surface; render nested glass controls independently when they need their own optical boundary.
---

**Rule:** A glass control inside `GlassPopover.contentBuilder` shares the popover's inherited glass layer by default. If the child should appear as a separate glass surface, give it an explicit tint/settings, premium quality, and `useOwnLayer: true`; also provide finite width constraints so its shape fills its intended area. Keep the child's optical rim inside the popover's rounded clip with sufficient inset, especially at the lower corners.

**Why:** The package puts popover content inside a `GlassContainer` and inherited `LiquidGlassLayer`, and clips children to the morphing outer shape. A nested control that opts into neither a distinct compositing layer nor its own width can visually merge into the popover; an independent glass rim can also be cut off if it sits too close to that outer clip.

**How to apply:** Use this for nested action buttons or controls that must preserve independent color, refraction, and Fresnel/rim effects. Keep the popover's card tint separate from the child control tint, and reserve extra bottom padding where the parent has large rounded corners.

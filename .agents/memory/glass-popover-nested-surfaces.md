---
name: Independent GlassPopover surfaces
description: Package GlassPopover content normally shares the morphing parent surface; render nested glass controls independently when they need their own optical boundary.
---

**Rule:** A glass control inside `GlassPopover.contentBuilder` shares the popover's inherited glass layer by default. If the child should appear as a separate glass surface, give it an explicit tint/settings, premium quality, and `useOwnLayer: true`; also provide finite width constraints so its glass geometry matches its layout bounds. Do not put that own-layer glass inside an edge-fade `ShaderMask`.

**Why:** The package puts popover content inside a transformed, clipped `GlassContainer`. An additional `ShaderMask` around an independent glass layer can composite its lens away from the control's visible bounds, making the rim appear detached or clipped. Adding more padding moves the control instead of correcting the glass layer's position.

**How to apply:** Use this for nested action buttons or controls that must preserve independent color, refraction, and Fresnel/rim effects. Keep the popover's card tint separate from the child control tint; when using an edge-fading scroll wrapper, disable its mask for content containing the independent glass control and keep the intended spacing.

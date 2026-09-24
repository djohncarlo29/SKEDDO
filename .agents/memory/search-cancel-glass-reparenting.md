---
name: Search cancel glass reparenting
description: Stable identity required for the Liquid Glass cancel control while search moves between scrollable and overlay locations.
---

The search cancel control must retain a stable GlobalKey when the search row moves between its inline scrollable location and the pinned off-screen search overlay. Its full-size lens must also remain intact during the reveal animation without a rectangular clip.

**Why:** Moving the row can otherwise remount the LiquidGlassView at the exact moment an overlay or sheet is changing occlusion, causing the cached capture and optical rim to render incorrectly.

**How to apply:** Give each independent search surface its own stable key, keep the modal-style static/synchronized glass lens, and use an overflow-safe scale reveal rather than constraining or rectangular-clipping the lens itself.

The cancel control's `showOpticalBorder` opt-in must be forwarded into the native lens style as well as the foreground hairline painter; otherwise the button keeps a faint outline but loses the directional rim highlight.

**Why:** A glass-surface refactor preserved the call-site opt-in and visible outline while hardcoding the lens style's optical border off, which made the cancel button appear flat.

**How to apply:** When changing `StaticLiquidGlassSurface`, pass the opt-in through to `_staticLiquidGlassStyle`; keep the surrounding exact-shape clip so the rim stays inside the circle.
---
name: Search cancel glass reparenting
description: Stable identity required for the Liquid Glass cancel control while search moves between scrollable and overlay locations.
---

The search cancel control must retain a stable GlobalKey when the search row moves between its inline scrollable location and the pinned off-screen search overlay. Its full-size lens viewport must also remain intact during the reveal animation.

**Why:** Moving the row can otherwise remount the LiquidGlassView at the exact moment an overlay or sheet is changing occlusion, causing the cached capture and optical rim to render incorrectly.

**How to apply:** Give each independent search surface its own stable key, keep the modal-style static/synchronized glass lens, and animate the surrounding reveal slot rather than constraining the lens itself.
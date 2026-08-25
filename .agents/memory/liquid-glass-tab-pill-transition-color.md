---
name: Liquid Glass tab-pill transition color
description: The animated nav pill interpolates restStyle appearance into the moving glass style appearance.
---

The moving tab-pill endpoint must explicitly set its appearance color when the desired lifted state is clear. Omitting the color lets the package default tint become the animated endpoint, so the old tint appears in intermediate lift and return frames even when both settled endpoints look correct.

**Why:** LiquidGlassNavBarMotionPill lerps the full appearance, including color; a package default is still visible during interpolation.

**How to apply:** Keep the settled active color in the rest style and set the lifted glass appearance color explicitly to transparent when the lifted state should be untinted.
---
name: Transparent icon overlay compositing
description: How AppShell custom-painted icons must preserve true transparent knockout geometry
---

For a custom-painted icon that must punch through an AppShell surface, keep the
CustomPaint on the same canvas as the destination it cuts through. Do not wrap
the painter in Opacity or Transform layers; express animated alpha and scale as
paint parameters and geometry instead.

**Why:** Intermediate compositing layers isolate BlendMode.clear from the
header/content destination. The icon can then show a white or tinted plus/ring
in Dark Mode and during modal-sheet ColorFiltered/ScaleTransition frames even
though the painter appears to use a clear blend mode.

**How to apply:** Mount the icon as a direct Stack overlay, use non-compositing
layout/gesture wrappers only, and let the painter apply visual opacity/scale
while leaving the separation ring and negative-space glyph as clear operations.
---
name: Transparent icon overlay compositing
description: How AppShell custom-painted icons must preserve true transparent knockout geometry
---

For a custom-painted icon that must punch through an AppShell surface, keep the
CustomPaint on the same canvas as the destination it cuts through. Do not wrap
the painter in external Opacity or Transform layers; express animated alpha and
scale as paint parameters and geometry instead. Inside the painter, use a
bounded transparent saveLayer before applying BlendMode.clear.

**Why:** External compositing layers isolate BlendMode.clear from the
header/content destination, while Android can also retain destination pixels
when clear is drawn directly on the scene canvas. The bounded internal layer
gives the icon real transparent pixels without letting the knockout alter
unrelated AppShell content.

**How to apply:** Mount the icon as a direct Stack overlay, use non-compositing
layout/gesture wrappers only, let the painter apply visual opacity/scale, and
leave the separation ring and negative-space glyph as clear operations inside
the bounded layer.
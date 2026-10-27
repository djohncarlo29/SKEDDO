---
name: Text Size slider step alignment
description: The Text Size slider's tick centers, continuous drag, and release snap behavior.
---

Text Size has seven step marks aligned with the resting thumb centers from minimum to maximum, inset from the track endpoints by half the resting thumb width. Keep the marks below the track. Drag continuously, then snap to the nearest of six intervals on release.

Keep the marks as 3×3 circles, preserving their 3 px height and vertical placement. Preserve the existing colors: ticks use kTertiaryLabel; Text Size side icons and Liquid Glass SVG details use kEmptyStateIcon.

**Why:** The user expects the thumb to move freely while dragging but settle at one of the marked text-size positions, without changing the existing gray colors.

**How to apply:** For Flutter, place ticks across the slider's resting thumb-center travel, not the track's outer endpoints. Preserve the existing tick and icon color tokens in Flutter and the light/dark iOS SVG variants; keep native iOS markers aligned to its thumb-center travel with quantization only at gesture end.

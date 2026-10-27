---
name: Text Size slider step alignment
description: The Text Size slider's tick centers, continuous drag, and release snap behavior.
---

Text Size has seven step marks aligned with the resting thumb centers from minimum to maximum, inset from the track endpoints by half the resting thumb width. Keep the marks below the track. Drag continuously, then snap to the nearest of six intervals on release.

**Why:** The user expects the thumb to move freely while dragging but settle at one of the marked text-size positions.

**How to apply:** For Flutter, place ticks across the slider's resting thumb-center travel, not the track's outer endpoints. Keep native iOS markers aligned to its thumb-center travel and apply quantization only at gesture end.

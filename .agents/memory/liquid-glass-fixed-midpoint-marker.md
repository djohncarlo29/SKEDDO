---
name: Fixed Liquid Glass midpoint marker
description: The Liquid Glass settings slider's 50% tick stays fixed to the row card while its track rubberbands.
---

Position `stepMarkerValue` from the resting track geometry (`_trackMinX` and `_trackWidth`), not from the live shifted/stretched track frame. The marker stays at its row-card coordinate while the track moves underneath it.

**Why:** The user explicitly corrected the behavior: the 50% marker is stationary relative to the slider card, not attached to the rubberbanding track.

**How to apply:** Keep the marker's resting position independent from rubberband state, and test both overscroll directions by confirming the track changes geometry while marker X stays unchanged.

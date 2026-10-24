---
name: Release-reset image zoom
description: Image attachments zoom during contact but animate back to their fit transform when the gesture ends.
---

Image-preview zoom is transient: pinch and pan are allowed while interacting, then the transform returns smoothly to identity on release. The reset animation owns the transform after release, so the viewer's independent fling must be suppressed.

**Why:** Independent inertia and return-to-fit animations update the same transformation matrix and can compete, making the image drift or snap instead of returning cleanly.

**How to apply:** Keep image content clipped by its existing preview silhouette, keep toolbar controls above the interactive image, and route zoom/reset through `ReleaseResetInteractiveViewer`. Do not preserve zoom or translation between gestures.

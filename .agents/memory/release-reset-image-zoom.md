---
name: Release-reset image zoom
description: Image attachments zoom during contact but animate back to their fit transform when the gesture ends.
---

Image-preview zoom is transient: pinch and pan scale the image and its clipped silhouette together beyond the starting viewport, then the transform returns smoothly to identity on release. The reset animation owns the transform after release, so the viewer's independent fling must be suppressed.

**Why:** A fixed outer clip turns the preview into a stationary zoom window rather than enlarging the image bounds. Independent inertia and return-to-fit animations also compete over the same transform matrix.

**How to apply:** Put the image silhouette clip inside `ReleaseResetInteractiveViewer` and allow the transformed child to paint beyond the initial viewport. Keep toolbar controls above the interactive image, and do not preserve zoom or translation between gestures.

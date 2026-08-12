---
name: Fixed Squircle Stadium radius
description: Shared stadium controls use a fixed 24px corner radius, with the 40px search bar explicitly using 20px.
---

SquircleStadiumBorder uses a fixed design radius instead of deriving the radius
from each control's height. The default is 24px so 52px, 64px, and taller
stadium controls share identical corner geometry; the path only clamps when
the available rect is physically shorter than 48px. The search bar remains
the explicit 20px exception, and its outer glow must trace a stadium border
with that same 20px radius.

**Why:** adjacent controls are designed to share cropped/overlaid squircle
corners, which is impossible when the radius changes with element height.

**How to apply:** use the default SquircleStadiumBorder for non-search stadium
controls; use kSearchBarCornerRadius for the search bar shape and glow. Keep
BoundedContinuousRectangleBorder for ordinary asymmetric/card shapes, but feed
those shells the same shared radius token so their visible outer corners match.
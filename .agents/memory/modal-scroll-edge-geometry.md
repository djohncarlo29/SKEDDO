---
name: Rounded modal scroll-edge geometry
description: Shared scroll-under fade and blur geometry for rounded modal sheets.
---

Keep the top scroll-edge effect anchored to the modal sheet's top edge, independently of the fixed header inset. At zero scroll, the surface fade's transparent endpoint aligns with the first scroll card's resting top. Keep the effect at full strength behind the fixed header, then fade it through the visible header-to-card gap; a blur gradient that spends its fade distance underneath an opaque header will look absent. The blur remains a separate continuous gradient that reaches zero slightly before the surface fade. Clip the composited effect to the modal's actual top-only squircle, not merely to its rectangular overlay bounds.

**Why:** The effect must remain visible where scroll content can be seen, cover the header-to-first-card region, and stay inside the rounded sheet outline; ending the blur behind the fixed header hides it, while a rectangular backdrop-filter band spills across curved corners.

**How to apply:** Derive the resting card position and fade start from the shared header, gap, and original scroll-padding geometry. Reuse the rounded sheet's bounded squircle path around the effect stack rather than configuring each sheet separately.
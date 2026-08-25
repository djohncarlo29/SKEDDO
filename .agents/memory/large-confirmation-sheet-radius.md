---
name: Large confirmation sheet radius
description: The radius exception for the microphone permission and Delete Group overlay sheets.
---

The microphone access action sheet and Delete Group confirmation sheet use a 40px `BoundedSquircleStadiumBorder` for their outer sheet card. Their internal action buttons continue using the shared 24px stadium radius.

**Why:** These two compact, centered/bottom confirmation surfaces are intentionally softer and more pill-like than the standard modal sheets.

**How to apply:** Use the dedicated large-modal radius token only on those two outer overlay cards; do not change the shared 24px radius or the regular rounded sheet route.
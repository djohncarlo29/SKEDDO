---
name: Large confirmation sheet radius
description: The radius exception for the microphone permission and Delete Group overlay sheets.
---

The microphone access action sheet and Delete Group confirmation sheet use a 40px `BoundedSquircleStadiumBorder` for their outer sheet card. Archive/delete/discard confirmations layered over an existing modal sheet use a separate 20px outer radius, while standalone confirmation cards stay at 24px. Internal action buttons continue using the shared stadium radius.

**Why:** These confirmation surfaces have distinct presentation contexts: the dedicated microphone/Delete Group cards are intentionally softer and more pill-like, while confirmations layered over another modal should be tighter without changing the regular two-step flow.

**How to apply:** Keep the 40px token only on the microphone/Delete Group cards. Use the modal-confirmation radius only when the confirmation overlay detects a parent sheet; preserve 24px for standalone confirmations and do not change the regular rounded sheet route.
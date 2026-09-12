---
name: Large confirmation sheet radius
description: The radius exception for the microphone permission and Delete Group overlay sheets.
---

The microphone access action sheet and Delete Group confirmation sheet use a 40px `BoundedSquircleStadiumBorder` for their outer sheet card. Archive/delete/discard confirmations layered over an existing modal sheet use a separate 24px outer radius, while standalone confirmation cards stay at 24px. Dismiss cards use 16px top text inset and 16px message-to-button gap. Internal action buttons continue using the shared stadium radius.

**Why:** These confirmation surfaces have distinct presentation contexts: the dedicated microphone/Delete Group cards are intentionally softer and more pill-like, while confirmations layered over another modal keep the tighter standard radius without changing the regular two-step flow. The dismiss copy spacing is intentionally compact.

**How to apply:** Keep the 40px token only on the microphone/Delete Group cards. Use the modal-confirmation radius when the confirmation overlay detects a parent sheet; preserve 24px for standalone confirmations and do not change the regular rounded sheet route. Keep the dismiss sheet's top text inset and message/button gap at 16px.
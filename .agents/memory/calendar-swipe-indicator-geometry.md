---
name: Calendar swipe indicator geometry
description: Fixed-size selected and today indicators during Calendar swipes, including the separate blob deformation layer.
---

Selection bloom and swipe deformation are separate effects. The original Calendar Tab bloom intentionally overshoots with its animation transform; the live swipe overlay's full-opacity selected circle must translate at its authored diameter, while only the translucent multi-day pill may use bounded blob deformation.

**Why:** The original product behavior uses a richer overshooting bloom for tap, re-tap, settle, and pre-bloom navigation. Replacing it with a bounded painter removes the intended gel response. The swipe overlay is a different render path and is the source of the unwanted size jump during dragging.

**How to apply:** Preserve the full bloom animation and keep the day-number label at scale 1.0. Do not wrap the full-opacity swipe circle in the velocity-driven blob widget. Keep static and swipe geometry aligned; apply bounded swipe deformation only to the multi-day pill, if present.
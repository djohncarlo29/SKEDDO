---
name: Calendar swipe indicator geometry
description: Fixed-size selected and today indicators during Calendar swipes, including the separate blob deformation layer.
---

Selection bloom and swipe deformation are separate effects. The original Calendar Tab bloom intentionally overshoots with its animation transform; the live swipe overlay must use bounded blob deformation so its outer rectangle does not grow.

**Why:** The original product behavior uses a richer overshooting bloom for tap, re-tap, settle, and pre-bloom navigation. Replacing it with a bounded painter removes the intended gel response. The swipe overlay is a different render path and is the source of the unwanted size jump during dragging.

**How to apply:** Preserve the full bloom animation and keep the day-number label at scale 1.0. Do not reuse that transform for the swipe overlay; render swipe stretch through a bounded clip path inside the authored overlay rectangle. Keep static and swipe geometry aligned without removing the bloom overshoot.
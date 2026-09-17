---
name: Calendar swipe indicator geometry
description: Fixed-size selected and today indicators during Calendar swipes, including the separate blob deformation layer.
---

Selection bloom and swipe deformation are separate effects. User-driven calendar swipes must not start the incoming day's pre-bloom during the slide: the 55% pre-bloom makes the selected/today indicator visibly grow before release, especially at larger OS text scales. The live swipe overlay's full-opacity selected circle must translate at its authored diameter, while only the translucent multi-day pill may use bounded blob deformation.

**Why:** The original product behavior uses a richer overshooting bloom for tap, re-tap, settle, and non-gesture navigation. Starting that animation during a user swipe creates the exact "grows while swiping, returns on release" symptom; larger scaled diameters make the same overshoot more obvious. The swipe overlay is a separate render path and must remain fixed-size while moving.

**How to apply:** Preserve bloom for taps and non-gesture transitions, but pass no pre-bloom callback from user drag-end navigation. Keep the day-number label at scale 1.0 and do not wrap the full-opacity swipe circle in the velocity-driven blob widget. In the settled Day View strip, force both selected and translucent-today backgrounds to scale 1.0; only Month View may use bloom overshoot. Keep static and swipe geometry aligned; apply bounded swipe deformation only to the multi-day pill, if present.
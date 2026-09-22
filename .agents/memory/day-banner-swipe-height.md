---
name: Day banner swipe height
description: Day View banner height must anticipate and animate incoming multiline labels during horizontal navigation.
---

Day View banner height must interpolate between the current and destination content heights while horizontal navigation is in progress, for both Single Day and Multi Day. The destination height is measured from the full incoming label in Single Day and the incoming two-day pair in Multi Day. Keep the 4dp minimum top and bottom inset in both endpoints.

**Why:** Incoming multiline labels should not make the banner and timeline snap taller only after navigation settles; the layout should communicate the change during the swipe.

**How to apply:** Use the same normalized horizontal swipe progress for live drags and snap animations, then commit the new date after the animation completes.
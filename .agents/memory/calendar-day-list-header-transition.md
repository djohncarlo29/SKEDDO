---
name: Calendar Day List header transition
description: The Day View header chrome must enter and leave List mode as one grouped transition.
---

The Calendar Tab Day View DOW row, week strip, and day banner are one visual header group when switching between List and Single/Multi Day modes. Drive their vertical movement from the same List-mode progress and keep the outgoing group mounted until the transition completes; on reverse, mount it at its offscreen position and bring it back together.

**Why:** Removing the DOW row and banner immediately while the week strip animated independently made the header visibly desynchronize during Day View mode changes.

**How to apply:** Keep this behavior scoped to Calendar Tab Day View. Do not couple it to Month↔Day collapse, date-navigation swipes, or unrelated tab headers.
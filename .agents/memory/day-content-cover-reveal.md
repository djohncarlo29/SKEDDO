---
name: Day content cover reveal
description: Month week rows act as the cover for Day View banner and timeline during Month↔Day transitions.
---

The Day View banner and timeline should exist for the entire Month↔Day hierarchy transition as one continuous surface. Month week rows paint above them while opening/closing, revealing or covering the surface; remove independent midpoint opacity and entrance translation.

**Why:** The corrected row motion already provides the intended upward/downward reveal geometry. A separate Day-content fade makes the content appear on its own path instead of being unveiled by the month grid.

**How to apply:** Keep the shared Day surface mounted from the first transition frame, layer it behind the month panel until the cover rows clear, then move the same keyed widgets above the panel for settled Day interaction. Reverse the z-order handoff on exit.
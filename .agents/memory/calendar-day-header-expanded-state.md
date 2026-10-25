---
name: Expanded Day header backdrop
description: Shared-header alignment and month-grid occlusion for Calendar Tab Day View.
---

In Calendar Tab Day View, the DOW row, selected week strip, and Day Banner must follow the shared AppShell expanded/compact header state. The Month panel remains mounted to morph its selected week into the strip, so earlier month rows must be covered through the DOW boundary; the cover must stop before the selected strip.

**Why:** Earlier month dates can bleed behind the expanded title while the DOW and banner are already in their expanded positions, making the strip appear stuck in compact geometry.

**How to apply:** Derive the Day header backplate and DOW top from the shared title transition, keep the selected week row directly below the DOW, and scope the backplate to portrait Day View.

---
name: Framework7 header icons
description: Reliable rendering approach for Framework7 icons used in Smart Scheduler headers
---

Framework7 header icons should use local custom painters based on the canonical Framework7 repository SVG geometry rather than runtime Iconify requests.

**Why:** The runtime Iconify endpoint returned a placeholder-like SVG/failed response for `today_fill`, so the header rendered a broken square instead of the intended icon.

**How to apply:** When adding or changing a Framework7 header icon, fetch the canonical source geometry during implementation, port it into a local painter, and keep the UI independent of network availability.
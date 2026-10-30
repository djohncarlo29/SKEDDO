---
name: Glass menu selection-pill scroll settle
description: Scroll-mode menu selector visibility after discrete wheel input
---

For `scrollOrLongPress`, keep the selection pill active for 150 ms after `ScrollEnd`, and cancel that timer on the next update or interaction reset. Wheel and trackpad input can emit the scroll update and end in one frame; hiding immediately means the pill is never painted. Stationary long-press remains a separate activation path and clears on release.

**Why:** The menu's scroll-mode pill must be visible during real scrolling without being preselected on open or normal taps. Discrete scrolling needs a brief settling interval for the visual response to appear.

**How to apply:** Keep the delay limited to the scroll behavior option, cancel it as soon as scrolling resumes, and avoid showing the pill during menu opening or submenu morphing.

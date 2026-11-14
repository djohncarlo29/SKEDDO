---
name: Scoped Glass alert layout
description: Apply the newer iOS alert-platter layout to lifecycle confirmations without upgrading shared glass defaults.
---

Use one app-owned alert platter for category, event, section, group, and utility lifecycle confirmations, following the newer `liquid_glass_widgets` iOS 26/27 geometry while preserving SKEDDO's explicit shared glass settings. Do not upgrade the whole vendored package solely for this layout.

**Why:** The newer package version changes defaults across menus, bars, controls, and sheets; the user approved the alert layout for confirmation flows without accepting those app-wide changes.

**How to apply:** Keep the current package renderer, quality choice, and shared curve settings on the platter. Keep title-to-message and message-to-first-action gaps equal. Present all lifecycle choices and follow-up confirmations through the same safe Cupertino dialog route. If the package is upgraded later, compare its `GlassDialog` implementation and retain the app-wide style boundary.

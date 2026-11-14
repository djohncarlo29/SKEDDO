---
name: Scoped Glass alert layout
description: Keep the newer iOS alert-platter layout limited to category lifecycle dialogs.
---

Use an app-owned alert platter for category archive/delete confirmations, following the newer `liquid_glass_widgets` iOS 26/27 geometry while preserving SKEDDO's explicit shared glass settings. Do not upgrade the whole vendored package solely for this layout.

**Why:** The newer package version changes defaults across menus, bars, controls, and sheets; the user approved the alert layout without accepting those app-wide changes.

**How to apply:** Keep the current package renderer, quality choice, and shared curve settings on the platter. Preserve the safe Cupertino dialog route and limit layout changes to category lifecycle confirmations. If the package is upgraded later, compare its `GlassDialog` implementation and retain the app-wide style boundary.

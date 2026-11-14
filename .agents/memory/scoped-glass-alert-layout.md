---
name: Scoped Glass alert layout
description: Apply the newer iOS alert-platter layout to lifecycle confirmations without upgrading shared glass defaults.
---

Use one app-owned alert platter for category, event, section, group, and utility lifecycle confirmations, following the newer `liquid_glass_widgets` iOS 26/27 geometry while preserving SKEDDO's explicit shared glass settings. Do not upgrade the whole vendored package solely for this layout.

**Why:** The newer package version changes defaults across menus, bars, controls, and sheets; the user approved the alert layout for confirmation flows without accepting those app-wide changes.

**How to apply:** Keep title-to-message and message-to-first-action gaps visually equal, compensating for their different text metrics instead of forcing identical layout-box gaps. Add 16pt safe-area clearance, regular-weight labels, and side-by-side layout for exactly two actions, with Cancel always left and the action right; preserve descriptive action labels such as “Archive Event” and “Delete Category.” Recently Deleted permanent-delete buttons use only “Permanently Delete.” In stacked multi-action dialogs, put the destructive choice before Cancel. Let long labels wrap and grow. On overflowing dialogs, glide-select only after actual scrolling, and highlight the option beneath the finger; retain GlassMenu-style fades, scroll indicator, touch glow/stretch, and release-to-select. Keep a full-screen `AdaptiveLiquidGlassLayer` alive through route transitions and group the alert platter inside it (not in a separate own-layer capture) so the backdrop material updates during entry, dismissal, and sequential confirmations. Let the dialog route barrier dim the full viewport including safe areas; do not paint an opaque safe-bottom background above that barrier. Use the shared safe Cupertino route. If the package is upgraded later, compare its `GlassDialog` implementation and retain the app-wide style boundary.

---
name: App-wide landscape content boundary
description: Keep physical landscape system-area handling symmetric and centralized above the Navigator.
---

The app-wide landscape model must keep each actual full-width surface edge-to-edge while reserving the larger physical horizontal system/cutout dimension only for UI positioning. The boundary publishes the inset and clears descendant horizontal safe-area fields; it must not paint a replacement background or constrain the Navigator. Actual surfaces stay outside shared content padding, while their child UI uses the published inset. Live rotation metrics remain above this boundary.

**Why:** The operating system can report the landscape system area on either physical side. Applying only the reported side moves SKEDDO's content when the device rotates; putting the actual header/content surfaces inside the inset boundary creates visible vertical seams at the safe-area edges.

**How to apply:** Change the shared `CupertinoApp.builder`/window boundary and native window configuration rather than adding per-screen landscape padding. Derive the symmetric X exclusively from `MediaQuery.viewPadding.left/right`; do not widen it with `padding`, gesture/tappable insets, keyboard `viewInsets`, old window dimensions, or design margins. Native diagnostics may log those other values for comparison, but they are not reservation inputs.
---
name: App-wide landscape content boundary
description: Keep physical landscape system-area handling symmetric and centralized above the Navigator.
---

The app-wide landscape model must keep themed background layers edge-to-edge while reserving the larger physical horizontal system/cutout dimension on both sides for the Navigator and Overlay subtree. Full-window surfaces must be siblings beneath the inset content boundary, not the boundary's outer fallback color. Descendant horizontal safe-area fields are cleared after the reservation so route-specific SafeAreas and sheets do not apply the same space twice. Live rotation metrics must remain above this boundary so adaptive widgets continue to receive the physical window size during rotation.

**Why:** The operating system can report the landscape system area on either physical side. Applying only the reported side moves SKEDDO's content when the device rotates; putting the background inside the inset boundary can also expose the engine's black clear color.

**How to apply:** Change the shared `CupertinoApp.builder`/window boundary and native window configuration rather than adding per-screen landscape padding. Derive the symmetric X exclusively from `MediaQuery.viewPadding.left/right`; do not widen it with `padding`, gesture/tappable insets, keyboard `viewInsets`, old window dimensions, or design margins. Native diagnostics may log those other values for comparison, but they are not reservation inputs.
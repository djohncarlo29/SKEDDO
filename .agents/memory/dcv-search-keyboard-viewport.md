---
name: DCV offscreen search keyboard viewport
description: Keyboard geometry and empty-result centering for offscreen search overlays in the Detailed Category View.
---

## Rule

The AppShell reserves keyboard space while editing an active DCV section, but
must not apply that inset while DCV search is focused. `SmartDcvSearchResults`
owns the search viewport's keyboard adjustment: it reserves
`MediaQuery.viewInsets.bottom` with `AnimatedPadding`, removes the bottom
viewInsets from its inner scroll view, and uses zero tab-bar clearance while
the keyboard is open. When the keyboard is hidden, keep the normal
floating-tab-bar clearance.

**Why:** The DCV overlay is inside the AppShell content stack. Applying the
same keyboard inset at both boundaries double-shrinks its viewport and pushes
the no-results placeholder above center; omitting it at both boundaries puts
results behind the keyboard.

**How to apply:** Keep the shell inset for section editing only and let
`SmartDcvSearchResults` handle focused search. Test the combined shell-padding
and results-widget layout with explicit `MediaQuery.viewInsets` so duplicate
inset ownership is caught.

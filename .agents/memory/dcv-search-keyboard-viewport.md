---
name: DCV offscreen search keyboard viewport
description: Keyboard geometry and empty-result centering for offscreen search overlays in the Detailed Category View.
---

## Rule

The AppShell reserves keyboard space while editing an active DCV section, but
must not apply that inset while DCV search is focused. `SmartDcvSearchResults`
owns the search viewport's keyboard adjustment and removes bottom viewInsets
from its inner scroll view. For empty results, use one outer animated bottom
obstruction equal to the larger of the keyboard inset and tab-bar clearance;
do not animate those clearances independently. Populated results reserve the
keyboard inset and use normal tab-bar clearance only when the keyboard is
closed.

**Why:** The DCV overlay is inside the AppShell content stack. Applying the
same keyboard inset at both boundaries double-shrinks its viewport and pushes
the no-results placeholder above center; omitting it at both boundaries puts
results behind the keyboard. Two separate animated paddings for keyboard and
tab-bar clearance can also leave the placeholder temporarily too low near
keyboard dismissal, then move it back up after the inset reaches zero.

**How to apply:** Keep the shell inset for section editing only and let
`SmartDcvSearchResults` handle focused search. Test the combined shell-padding
and results-widget layout with explicit `MediaQuery.viewInsets`, including
insets smaller than the tab-bar clearance, so duplicate ownership and a late
centering correction are caught.

---
name: Flutter browser touch verification
description: Avoid false failures when exercising Flutter scrolling with browser touch automation.
---

Use timed, incremental touch moves to verify Flutter scrolling, not a single
large touchMove followed immediately by touchEnd.

**Why:** The Theme subscreen appeared unable to collapse in browser testing,
while a real timed drag passed widget tests. A ten-frame CDP swipe confirmed
the live page was correct: the initial move wins the gesture under
DragStartBehavior.start, and subsequent moves provide scrolling displacement.
The one-move probe was a false failure, not an app defect.

**How to apply:** Send touchStart, then several touchMove events spaced about
30ms apart, then touchEnd and allow settling. Keep input coordinates inside
the actual Flutter viewport. Confirm both the header and content positions
before changing app code to address an apparent automated-gesture failure.

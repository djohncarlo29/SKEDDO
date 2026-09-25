---
name: Android selection-handle haptics
description: Keep text-selection handle drags quiet without changing tap-to-select or unrelated feedback.
---

On Android, suppress only `SELECTION_CLICK` while a text-selection handle pointer is active. Reset the guard on pointer up, pointer cancel, and widget disposal. Normal double- and triple-tap selection and all other haptics must remain unchanged.

**Why:** Flutter's Android platform plugin can issue repeated selection-click feedback while a user drags a selection handle. Suppressing haptics globally would also remove intentional selection and picker feedback.

**How to apply:** Scope the active-pointer guard to rendered selection handles and filter only the platform selection-click enum while that guard is active.
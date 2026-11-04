---
name: DCV view-mode menu visibility
description: Which category detail views expose the Columns/List display toggle.
---

Show View as Columns/List only when the view is not a utility or user-created Smart Category and it has visible sections. For built-in Smart Categories, generated date/time groups count as sections; a flat built-in view with no generated headers does not.

**Why:** The user wants the display toggle wherever section headers are visible, including automatically dated sections in built-in Smart Categories, but not on flat views.

**How to apply:** Base visibility on the sections the current view actually renders, not only on saved custom-section records.

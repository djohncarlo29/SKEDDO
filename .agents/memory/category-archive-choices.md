---
name: Category archive choices
description: Product rule for archiving user categories that contain sections or events.
---

Contentful user categories require an explicit scope choice when events exist: archive or delete the category with its saved sections and events intact, or preserve the category and saved sections while moving events to the configured default category. Categories with no events skip the scope choice but still require the secondary confirmation sheet. With-contents archive stores events in a separate archived-events collection, so they disappear from All Events and active category views; recovery moves them back exactly once. With-contents deletion moves events to Recently Deleted as a recoverable bundle. Deleting an already archived category moves its archived events to Recently Deleted with the category. Group deletion preserves the same category-only and category-with-contents transitions.

**Why:** The user wants archiving and deletion to support both reversible preservation and intentional removal of category organization without silently changing event placement.

**How to apply:** Keep archive and delete choice subtitles concise and parallel. Built-in smart categories do not need this prompt because they do not own category sections or event assignments.
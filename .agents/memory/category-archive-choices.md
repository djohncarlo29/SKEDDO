---
name: Category archive choices
description: Product rule for archiving user categories that contain sections or events.
---

Contentful user categories require an explicit choice: archive the category with its sections and events intact, or archive only the category, move events to the configured default category, and remove its section layout. Deletion offers the parallel choice of moving the category with its events to Recently Deleted as a recoverable bundle, or moving only the category there while reassigning events to the default category. Deleting an already archived category preserves any events still attached to it. Group deletion preserves the group-only and category-only choices and adds deleting member-category events too.

**Why:** The user wants archiving and deletion to support both reversible preservation and intentional removal of category organization without silently changing event placement.

**How to apply:** Keep archive and delete choice subtitles concise and parallel. Built-in smart categories do not need this prompt because they do not own category sections or event assignments.
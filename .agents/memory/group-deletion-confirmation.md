---
name: Group deletion confirmation
description: Product rule for separating harmless group removal from deleting member categories.
---

Removing only a group is immediate because categories and events remain unchanged. Deleting a group and its categories requires a second confirmation; categories move to Recently Deleted and events move to Uncategorized, while the group itself is not restored.

**Why:** The two group actions have very different consequences, so the destructive path must not execute from the initial choice sheet.

**How to apply:** Keep the first sheet as a choice sheet. Use a follow-up destructive confirmation only for deleting member categories, and label the harmless action Remove Group Only.
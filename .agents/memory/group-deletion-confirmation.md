---
name: Group deletion confirmation
description: Product rule for separating harmless group removal from deleting member categories.
---

Removing only a group is immediate because categories and events remain unchanged. Deleting a group and its categories requires a second confirmation. The category-only path moves events to the default category; the category-and-events path moves member categories and their event bundles to Recently Deleted so category recovery can restore remaining events. The group itself is not restored.

**Why:** The two group actions have very different consequences, so the destructive path must not execute from the initial choice sheet.

**How to apply:** Keep the first sheet as a choice sheet. Use a follow-up destructive confirmation only for deleting member categories, and label the harmless action Remove Group Only.
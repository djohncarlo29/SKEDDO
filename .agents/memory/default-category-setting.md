---
name: Default category setting
description: The selected event category is persisted by stable ID and is the fallback for creation, recovery, and category removal.
---

The default category is stored as a category ID, not a display name. New installs use the install-time Uncategorized ID. Unnamed and Uncategorized are ordinary categories after installation; if the selected default is archived or deleted, choose the first remaining active normal category in saved order, or create a fresh Uncategorized fallback if none remain.

**Why:** Category names are editable, while category IDs remain stable. Reassignment must never leave events pointing at an archived or deleted category, and deleting all categories still needs a valid receiver for new or reassigned events.

**How to apply:** Use the shared app-level default-category notifier for new events and EventStore fallback operations. Keep picker labels derived from the current category records.
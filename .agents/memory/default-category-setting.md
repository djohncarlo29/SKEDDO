---
name: Default category setting
description: The selected event category is persisted by stable ID and is the fallback for creation, recovery, and category removal.
---

The default category is stored as a category ID, not a display name. New installs use the built-in Uncategorized ID; if the selected category is deleted, reset the setting to that built-in fallback before reassigning events.

**Why:** Category names are editable, while category IDs remain stable. Reassignment must never leave events pointing at a deleted category.

**How to apply:** Use the shared app-level default-category notifier for new events and EventStore fallback operations. Keep picker labels derived from the current category records.
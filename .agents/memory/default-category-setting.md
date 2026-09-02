---
name: Default category setting
description: The selected event category is persisted by stable ID and is the fallback for creation, recovery, and category removal.
---

The default category is stored as a category ID, not a display name. New installs use the built-in Uncategorized ID. Uncategorized and Unnamed are permanent receiving categories; if another selected default is archived or deleted, reset to Uncategorized before reassigning events.

**Why:** Category names are editable, while category IDs remain stable. Reassignment must never leave events pointing at an archived or deleted category, and a valid fallback must always exist.

**How to apply:** Use the shared app-level default-category notifier for new events and EventStore fallback operations. Keep picker labels derived from the current category records.
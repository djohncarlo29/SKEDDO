---
name: Utility search scope
description: Search priority for Archived Items and Recently Deleted.
---

Search the contents of the currently open utility first, including its events, user categories, and built-in Smart Categories. Render utility matches as separated individual tiles without date-section headers or divider lines. Show matching active events under “ALSO FOUND” only when the utility itself has no matches; do not mix active results into a nonempty utility result set.

**Why:** The user expects utility search to find archived or deleted items rather than surfacing active events as if they were utility contents, and to scan individual result tiles rather than dated groups or divider-separated rows.

**How to apply:** Preserve this priority and flat utility-result presentation in both inline and full-screen search modes whenever utility search or its result rendering changes.

---
name: Nested modal header alignment
description: The project-wide positioning rule for titles and controls in nested modal sheets.
---

Nested modal sheet titles and navigation/action controls must align to the same horizontal and vertical coordinates as the corresponding parent sheet header. Keep scroll content clearance consistent with the positioned header; allow the scroll-edge treatment to follow the shared header geometry rather than applying a separate offset.

**Why:** The user requested visual continuity between parent modal sheets and their nested subsheets; small header shifts are noticeable while moving between stacked sheets.

**How to apply:** When building or changing a nested modal route, compare its title and control positions with the parent header. Reuse the shared modal-header geometry and adjust edge extents only when the total header clearance changes.

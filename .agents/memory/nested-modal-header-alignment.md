---
name: Nested modal header alignment
description: The project-wide positioning rule for titles and controls in nested modal sheets.
---

Nested modal sheet titles and navigation/action controls must align to the same horizontal and vertical coordinates as the corresponding parent sheet header. The shared toolbar buttons are offset 2pt down; leading buttons also move 4pt right and trailing buttons 4pt left. Discard popover triggers move with their leading buttons, while their popover offset compensates so the settled popover stays at its previous coordinates. Keep scroll content clearance consistent with the positioned header; allow the scroll-edge treatment to follow the shared header geometry rather than applying a separate offset.

**Why:** The user requested visual continuity between parent modal sheets and their nested subsheets; small header shifts are noticeable while moving between stacked sheets.

**How to apply:** When building or changing a nested modal route, compare its title and control positions with the parent header. Reuse the shared modal-header offsets and adjust edge extents only when the total header clearance changes. Keep fitting titles centered on the sheet width even with asymmetric fade bounds, and align their vertical center with the toolbar centerline. Place fades 16pt from each toolbar or sheet edge. If a moved header button anchors a popover, compensate the popover's offset by the inverse trigger shift.

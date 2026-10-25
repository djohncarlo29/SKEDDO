---
name: Day View week-strip positioning
description: Align the selected Month row, DOW header, and Day Banner in expanded and compact Calendar Day View.
---

In Calendar Tab Day View, the selected week row already follows the Month viewport's shared-header position. Keep it directly below the DOW mask and above the Day Banner; do not add another shared-header translation or paint a parent-level header backplate over the Month rows.

**Why:** A second compact-header translation moves the selected strip 41px above the DOW, and a parent backplate can hide the strip entirely in both header states.

**How to apply:** Test by collapsing Calendar's own Month header before entering Day View, then verify selected-row top equals DOW bottom and Day Banner top equals selected-row bottom in both Single Day and Multi Day.

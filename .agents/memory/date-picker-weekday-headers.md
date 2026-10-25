---
name: Date-picker weekday headers
description: Weekday ordering for Calendar Tab and grid-based date pickers.
---

Calendar Tab and month-grid date pickers follow the saved First Day of Week
setting and keep single-letter weekday labels. Their wheel-barrel controls are
unchanged.

**Why:** The user wants visible month grids to match the chosen calendar week
start without changing the separate date/time wheel behavior.

**How to apply:** Use the shared weekday-header and month-offset helpers for
Calendar Tab grids and month-grid pickers, including Start/End and Repeat End
Date grids. Do not change wheel barrels or unrelated date-picker grids unless
requested.
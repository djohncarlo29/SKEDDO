---
name: Calendar month dot ordering
description: Month-grid event dots must use the same display ordering as the selected-day list.
---

## Rule
The Calendar Month View dot color is the category color of the first event in the displayed day-list order: all-day events first, followed by timed sections in time order.

**Why:** The raw EventStore order can place a timed event before an all-day event, causing the dot color to disagree with the first event the user sees.

**How to apply:** Derive the dot's event from the grouped month-list ordering rather than directly from the ungrouped event-store list.
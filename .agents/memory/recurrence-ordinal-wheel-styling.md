---
name: Recurrence ordinal wheel styling
description: Shared appearance rules for the Monthly and Yearly ordinal/day selectors in both repeat sheets.
---

Center-align every Monthly and Yearly ordinal/day option within its own wheel in both Event and Category repeat sheets. Keep the paired wheels slightly closer by centering a compact, label-fitting wheel group beneath the selection overlay; the connected selection bar must still span the full available picker width. Preserve opposite off-axis fractions (`-0.45` for ordinal, `+0.45` for day), scroll/selection behavior, and barrel curvature. Retain lowercase grouped labels `day`, `weekday`, and `weekend day`.

For Yearly Days of Week, show only ordinal positions supported by at least one selected month. In the footer, include only selected months that support the chosen ordinal/day combination.

Yearly availability depends on the calendar year. Use the event start year for event repeats, the reminder date's year for reminder repeats, and the current year for category presets that have no anchor date.

**Why:** The user explicitly requires centered option text and slightly closer spacing without changing the picker’s existing behavior, curvature, or full-width selection bar. A yearly summary must not claim an occurrence in a month that cannot match the chosen ordinal/day, and weekday ordinals can differ by year.

**How to apply:** Keep the Category and Event repeat sheets consistent. Apply these geometry rules only to Monthly “On the…” and Yearly day-selector wheels, not unrelated pickers or weekly weekday names. Preserve the two scroll controllers, selection callbacks, paired off-axis values, and full-width overlay whenever adjusting label alignment or spacing. Use the recurrence date-matching rule and the relevant anchor year for Yearly availability.
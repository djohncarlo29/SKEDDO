---
name: Recurrence ordinal wheel styling
description: Shared appearance rules for the Monthly and Yearly ordinal/day selectors in both repeat sheets.
---

Center-align every Monthly and Yearly ordinal/day option within its own wheel in both Event and Category repeat sheets. Let the paired wheel group use the full available row width, keep the selection bar full-width, and apply only the shared fixed 8dp inset; do not add extra label padding or clip the wheels at the pill ends. Preserve opposite off-axis fractions (`-0.45` for ordinal, `+0.45` for day), scroll/selection behavior, and barrel curvature. Retain lowercase grouped labels `day`, `weekday`, and `weekend day`.

For Yearly Days of Week, show only ordinal positions supported by at least one selected month. In the footer, include only selected months that support the chosen ordinal/day combination.

Yearly availability depends on the calendar year. Use the event start year for event repeats, the reminder date's year for reminder repeats, and the current year for category presets that have no anchor date.

**Why:** The user rejected the earlier 72%-width approach because it made labels too small and too far from the visible selection-bar edges, and clarified that the fixed inset is 8dp on each side. A yearly summary must not claim an occurrence in a month that cannot match the chosen ordinal/day, and weekday ordinals can differ by year.

**How to apply:** Keep the Category and Event repeat sheets consistent. Use the same 8dp shrink-to-fit primitive across their ordinal/day wheels. Apply these geometry rules only to Monthly “On the…” and Yearly day-selector wheels, not weekly weekday names. Preserve the two scroll controllers, selection callbacks, paired off-axis values, and full-width overlay. Use the recurrence date-matching rule and the relevant anchor year for Yearly availability.
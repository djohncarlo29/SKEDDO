---
name: Recurrence ordinal wheel styling
description: Shared appearance rules for the Monthly and Yearly ordinal/day selectors in both repeat sheets.
---

Center-align every Monthly and Yearly ordinal/day option within its own wheel in both Event and Category repeat sheets. Place the paired wheels close enough to the centerline that the labels do not drift toward the outer selection-bar edges; constrain the wheel group to at most 72% of available width while keeping the selection bar full-width. Preserve opposite off-axis fractions (`-0.45` for ordinal, `+0.45` for day), scroll/selection behavior, and barrel curvature. Retain lowercase grouped labels `day`, `weekday`, and `weekend day`.

For Yearly Days of Week, show only ordinal positions supported by at least one selected month. In the footer, include only selected months that support the chosen ordinal/day combination.

Yearly availability depends on the calendar year. Use the event start year for event repeats, the reminder date's year for reminder repeats, and the current year for category presets that have no anchor date.

**Why:** The user explicitly corrected the previous inward-spacing adjustment because it moved the labels farther apart visually; the paired labels must move toward the middle while retaining centered text, curvature, existing picker behavior, and the full-width selection bar. A yearly summary must not claim an occurrence in a month that cannot match the chosen ordinal/day, and weekday ordinals can differ by year.

**How to apply:** Keep the Category and Event repeat sheets consistent. Apply these geometry rules only to Monthly “On the…” and Yearly day-selector wheels, not unrelated pickers or weekly weekday names. Preserve the two scroll controllers, selection callbacks, paired off-axis values, and full-width overlay whenever adjusting label alignment or spacing. Use the recurrence date-matching rule and the relevant anchor year for Yearly availability.
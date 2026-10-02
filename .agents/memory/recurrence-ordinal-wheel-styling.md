---
name: Recurrence ordinal wheel styling
description: Shared appearance rules for the Monthly and Yearly ordinal/day selectors in both repeat sheets.
---

Keep each Monthly and Yearly ordinal/day wheel center-aligned; do not offset the paired wheels in opposite directions. The connected selection bar must remain full-width in both repeat sheets. Retain barrel curvature and lowercase grouped labels `day`, `weekday`, and `weekend day`.

For Yearly Days of Week, show only ordinal positions supported by at least one selected month. In the footer, include only selected months that support the chosen ordinal/day combination.

Yearly availability depends on the calendar year. Use the event start year for event repeats, the reminder date's year for reminder repeats, and the current year for category presets that have no anchor date.

**Why:** The user explicitly wants centered ordinal and day wheels at the same time as a full-width selection bar. A yearly summary must not claim an occurrence in a month that cannot match the chosen ordinal/day, and weekday ordinals can differ by year.

**How to apply:** Keep the Category and Event repeat sheets consistent. Apply centered alignment and the full-width selection bar to Monthly “On the…” and Yearly day-selector wheels, not unrelated pickers or weekly weekday names. Use the recurrence date-matching rule and the relevant anchor year for Yearly availability.
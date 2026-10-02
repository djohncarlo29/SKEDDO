---
name: Recurrence ordinal wheel styling
description: Shared appearance rules for the Monthly and Yearly ordinal/day selectors in both repeat sheets.
---

Center-align every Monthly and Yearly ordinal/day option within its own wheel in both Event and Category repeat sheets. Keep the paired group full-width with a full-width selection bar and the shared fixed 8dp inset; do not add label padding or clip at the pill ends. Bring the two options closer using opposite off-axis fractions (`-0.15` for ordinal, `+0.15` for day). Preserve scroll/selection behavior and barrel curvature. Retain lowercase grouped labels `day`, `weekday`, and `weekend day`.

For Yearly Days of Week, show only ordinal positions supported by at least one selected month. In the footer, include only selected months that support the chosen ordinal/day combination.

Yearly availability depends on the calendar year. Use the event start year for event repeats, the reminder date's year for reminder repeats, and the current year for category presets that have no anchor date.

**Why:** The user repeatedly requested only closer ordinal/day options and reported that unrelated picker fixes were being reintroduced. The moderate opposite offsets bring the pair together while preserving the full-width layout. The fixed inset is 8dp on each side. A yearly summary must not claim an occurrence in a month that cannot match the chosen ordinal/day, and weekday ordinals can differ by year.

**How to apply:** Keep the Category and Event repeat sheets consistent. Use the same 8dp shrink-to-fit primitive and `-0.15`/`+0.15` offsets for Monthly “On the…” and Yearly day-selector wheels only. Do not change weekly weekday names, interval count/unit wheels, or time-picker wheels. Preserve both scroll controllers, callbacks, and the full-width overlay. Use the recurrence date-matching rule and relevant anchor year for Yearly availability.
---
name: Recurrence ordinal wheel styling
description: Shared appearance rules for the Monthly and Yearly ordinal/day selectors in both repeat sheets.
---

Center-align every Monthly and Yearly ordinal/day option within its own wheel in both Event and Category repeat sheets. Size the paired wheel group from the widest option at the active text scale, capped at 72% of available width, while keeping the selection bar full-width and the fixed 8dp text inset. Use opposite off-axis fractions (`-0.15` for ordinal, `+0.15` for day), and preserve scroll/selection behavior and barrel curvature. Retain lowercase grouped labels `day`, `weekday`, and `weekend day`.

For Yearly Days of Week, show only ordinal positions supported by at least one selected month. In the footer, include only selected months that support the chosen ordinal/day combination.

Yearly availability depends on the calendar year. Use the event start year for event repeats, the reminder date's year for reminder repeats, and the current year for category presets that have no anchor date.

**Why:** The user reported that the full-width paired wheels still left ordinal/day choices too far apart; changing off-axis values alone did not fix the visible spacing. The compact centered wheel group brings the labels together without narrowing the selection bar. The fixed inset is 8dp on each side. A yearly summary must not claim an occurrence in a month that cannot match the chosen ordinal/day, and weekday ordinals can differ by year.

**How to apply:** Keep the Category and Event repeat sheets consistent. Use the same widest-label sizing helper and `-0.15`/`+0.15` offsets for Monthly “On the…” and Yearly day-selector wheels only. Keep the wheel group compact and centered beneath the full-width overlay. Do not change weekly weekday names, interval count/unit wheels, or time-picker wheels. Confirm the actual wheel group width before claiming the choices are closer; preserve both scroll controllers and callbacks. Use the recurrence date-matching rule and relevant anchor year for Yearly availability.
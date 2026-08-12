---
name: Event creation save architecture
description: How the New Event sheet saves to ScheduledEvent — all fields, picker constraints, and recurrence storage decisions.
---

## Rule
Every field in the New Event sheet is saved to `ScheduledEvent` on checkmark tap. The sheet calls `EventStore.instance.create()` via `_saveEvent()` in `_NewEventSheetState`.

## ScheduledEvent fields (as of implementation)
- `title`, `subtitle` — card 1
- `date`, `time`, `endDate`, `endTime`, `isAllDay` — card 2 (null for unscheduled)
- `location` (Starting Location), `destination` — card 3 (future Maps API)
- `travelTime`, `travelMode` — card 3 (saved as strings, e.g. "1 hour", "Car")
- `repeat`, `repeatEndType`, `repeatEndDate`, `customRepeatConfig` — card 4
- `categoryId` — card 5 (standard category ID)
- `alert`, `secondAlert` — card 6
- `url`, `notes`, `attachmentNames` — card 7 (attachment bytes NOT in SharedPreferences)
- `parsedDate` — AI-populated after save

## Picker constraints implemented
- **Starts date change (timed)**: auto-adjusts Ends to maintain `_durationMinutes`
- **Starts date change (all-day)**: clamps Ends to Starts if Ends would fall before
- **Starts time change**: always adjusts Ends to maintain duration (pre-existing)
- **Ends date picker**: days before Starts are grayed/non-tappable via `isPast` extension
- **Ends time (same day)**: clamps to Starts + 15 min if user picks earlier

## Recurrence storage rule
**Why:** Infinite recurrence (Never end) must not generate infinite event copies.
**How to apply:** Store one event record with `repeat` + `repeatEndType` + optional `repeatEndDate`. View layer computes instances by walking the rule forward within the visible window. Never pre-expand to individual copies.

## Custom repeat serialization
`_NewEventCustomRepeatConfig` is serialized to `Map<String, dynamic>` in `_saveEvent()` (frequency, everyCount, selectedDays list, monthlyMode, etc.) and stored in `customRepeatConfig`. The human-readable label is stored in `repeat`.

## Unscheduled events
Unscheduled toggle → `date`/`time`/`endDate`/`endTime` all null → event naturally appears in the built-in "Unscheduled" smart tile (which filters by null parsedDate).

## Alert timing logic
- Travel Time = None: alerts are relative to event start time
- Travel Time set: alert options shift to be relative to travel start (= event start − travel duration)
- Second Alert must fire AFTER first Alert (option list is constrained)
- All-day events: alerts are calendar-anchored ("Night before 9 PM", "On day of event 9 AM")
- Saved as plain strings; actual alarm datetime is computed at scheduling time, not stored

## Category preset propagation rules
- Selecting any named category in the Event sheet calls `_applyPreset()` → fills all preset fields from the category, fallback to system defaults for unset fields.
- Selecting **Uncategorized** also calls `_applyPreset()` with no preset fields → all fallbacks apply, so alert = "At time of event" (never silent).
- When a user **edits** an existing category, `_updateCategory()` calls `EventStore.instance.updateCategoryPresets()` which walks all events with that `categoryId` and calls `copyWithPreset()` on each, then persists.
- `ScheduledEvent.copyWithPreset()` replaces only the 10 preset fields; title, dates, url, notes, attachments, parsedDate are preserved.

## Normalisation
`_categoryId == 'uncategorized'` → normalised to `'sys-uncategorized'` on save.
`travelTime/travelMode == 'None'` → saved as null.
`repeat == 'Never'` → saved as null (no repeat fields emitted).

---
name: EventStore.create() date-parse concatenation bug
description: Concatenating date+time before parsing broke Scheduled/Unscheduled categorization — fix is to parse date-only.
---

**Bug:** `EventStore.create()` previously concatenated `date + ' ' + normTime` to form `rawDate` before calling `AIServices.dateParser.parse(rawDate)`. The UI formats dates as `"August 9, 2026"` and times as `"2:00 PM"`, producing `"August 9, 2026 2:00 PM"`. `RuleBasedDateParser._tryMonthDay()` regex anchors at `$` so it fails when a time suffix follows the year → returns `ParsedDate(absoluteDate: null)` → `isScheduled == false` → every UI-created event with a time landed in Unscheduled.

**Fix:** Parse only `date` (not `date + time`). `parsedDate.absoluteDate` is date-only (`_dateOnly()` strips hours), so the time string never contributed useful information to the parse — it only broke it.

**Why:** The time is stored separately in `event.time` and fed to the embedding text via `EventPipeline._buildText()`; it must NOT be included in the date-parse input.

**How to apply:** If the date-parse input to `AIServices.dateParser.parse()` is ever changed again, pass only the date string — never a combined date+time string — unless `RuleBasedDateParser` is first updated to tolerate trailing time suffixes.

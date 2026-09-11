---
name: Event utility provenance
description: Persisted provenance rules for explaining how events enter Archived Items and Recently Deleted.
---

Archived and deleted event sheets must use persisted lifecycle provenance rather than inferring the original action from the event's current category list. Archive and delete origins are independent because an event can be archived with its category and later deleted individually. Group deletion must be recorded separately from ordinary category deletion, and bulk clear operations use a distinct bulk origin.

**Why:** Current category membership cannot distinguish an event moved independently from one moved with its category, especially after later category changes or individual recovery. Older records have no metadata and must not receive a confident guessed explanation.

**How to apply:** Set provenance at every EventStore transition that moves events into Archived Items or Recently Deleted. Preserve both fields through event copy/serialization paths. For legacy records with missing metadata, state that the original action was not recorded.
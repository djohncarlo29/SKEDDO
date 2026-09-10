---
name: Calendar Month List DCV parity
description: Calendar Month List event content must reuse the Events Detailed Category View implementation and its exact-time reorder boundaries.
---

## Rule
The Calendar Month View List mode should embed the Events DCV event-list implementation rather than maintain a parallel card or drag implementation. Its manual reorder scope is one exact time section at a time.

**Why:** Separate Calendar row logic drifted from the Events DCV in lifted-card geometry, placeholder/separator rendering, reflow animation, context actions, and drag eligibility.

**How to apply:** When changing event-card behavior, update the shared DCV path first and keep Calendar List as a thin adapter for the selected day’s events and parent scroll controller.

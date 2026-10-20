---
name: Top-level modal sheet behavior
description: Product decision for how standalone sheets and nested subsheets stack over the Smart Scheduler app.
---

Top-level modal sheets leave the AppShell at full size and in its original position; only nested subsheets shrink and stack their parent sheet. Keep the AppShell’s hamburger/X LiquidGlassButton clear of the resting top edge of a top-level sheet.

**Why:** The app header control was shifted underneath the modal by the top-level Cupertino stack transition, and the user explicitly wants stack depth to represent nested sheets only.

**How to apply:** When changing shared sheet routes, preserve dimming of the app if desired, but do not scale, translate, or corner-clip the AppShell for a top-level sheet. Preserve the parent sheet’s secondary transition for nested sheets and reserve enough top clearance for the header control.

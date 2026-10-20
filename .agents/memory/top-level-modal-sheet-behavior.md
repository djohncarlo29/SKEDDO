---
name: Top-level modal sheet behavior
description: Product decision for how standalone sheets and nested subsheets stack over the Smart Scheduler app.
---

Top-level modal sheets leave the AppShell at full size and in its original position; only nested subsheets shrink and stack their parent sheet. Parent sheets and nested subsheets both rest exactly 10px below the top safe-area inset.

**Why:** The user wants a consistent physical top gap for all parent sheets and nested subsheets, instead of a gap that changes with screen height or sheet depth.

**How to apply:** When changing shared sheet routes, preserve dimming of the app if desired, but do not scale, translate, or corner-clip the AppShell for a top-level sheet. Preserve the parent sheet’s secondary transition for nested sheets and compute both route top offsets from `viewPadding.top + 10px`.

---
name: Platform text scaling profile
description: Native text-size settings must be sourced from the OS profile and preserve nonlinear curves when exposed to Flutter.
---

The platform is the source of truth for SKEDDO text-size positions. Android should read the framework/OEM font-size resource and use `FontScaleConverter` where available; Flutter should preserve the active OS `TextScaler` for an exact System-to-Custom handoff and use sampled native curves for other derived positions.

**Why:** A universal multiplier table can match a position label while still diverging from Android’s nonlinear accessibility scaling, especially at larger sizes.

**How to apply:** Keep native profile discovery and curve sampling in the platform bridges, refresh on foreground return and poll the lightweight current scale while visible for split-screen/floating-window cases, and treat linear values only as an explicit compatibility fallback for web or old binaries that expose no profile.

Profile reads and preference commits must be serialized. Lifecycle refreshes can overlap with the visibility poll, and slider/mode changes can enqueue several writes; publishing or writing out of order makes a newer user choice appear to revert.

**Why:** Both native profile loading and SharedPreferences updates are asynchronous, so completion order is not guaranteed even when calls were made in the intended order.

**How to apply:** Queue the complete profile operation (including the lightweight probe) and snapshot text-size mode/index when a setting is committed.

System must remain Flutter's ambient SystemTextScaler. Custom native positions
must be generated independently with the exact Android operation Flutter's
engine uses: TypedValue.applyDimension(SP, size, stop metrics) / density.

**Why:** Replacing System with a reconstructed curve makes the two modes agree
by changing System, while still leaving exact engine equivalence unproven.

**How to apply:** Build per-stop configuration metrics for Custom, preserve the
complete native profile and seven-position mapping rules, and validate each
native stop against Flutter's live scaler while that OS stop is active.
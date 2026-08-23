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

System and Custom direct native positions must consume the same resolved native
curve. Flutter's ambient System scaler is not a substitute on Android when
nonlinear accessibility scaling is active; only use it as a compatibility
fallback when no native curve is available.

**Why:** A native stop can have the same nominal multiplier while producing
different rendered sizes at different font sizes if System and Custom use
different scaler implementations.

**How to apply:** Resolve the active System stop from the complete native
profile, including stops beyond the seven-position Custom control, while
freezing the selected curve when Custom mode is entered.
---
name: Platform text scaling profile
description: Native text-size settings must be sourced from the OS profile and preserve nonlinear curves when exposed to Flutter.
---

The platform is the source of truth for SKEDDO text-size positions. Android should read the framework/OEM font-size resource and use `FontScaleConverter` where available; Flutter should preserve the active OS `TextScaler` for an exact System-to-Custom handoff and use sampled native curves for other derived positions.

**Why:** A universal multiplier table can match a position label while still diverging from Android’s nonlinear accessibility scaling, especially at larger sizes.

**How to apply:** Keep native profile discovery and curve sampling in the platform bridges, refresh on foreground return and poll the lightweight current scale while visible for split-screen/floating-window cases, and treat linear values only as an explicit compatibility fallback for web or old binaries that expose no profile.
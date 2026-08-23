---
name: Flutter System scaler diagnostics
description: What the existing native-profile tests do and do not prove about Android Flutter System text scaling.
---

The native-profile tests compare the reconstructed Custom scaler with the same native-generated samples; they do not compare against Flutter's ambient `MediaQuery`/engine scaler. Flutter's Android non-linear path uses the `DisplayMetrics` snapshot queued by `SettingsChannel`, keyed by a configuration ID, so physical-device diagnostics must capture both paths at identical OS settings and sizes.

**Why:** A default/identity position can match while every non-default position diverges, and this cannot be diagnosed from tests that only compare two copies of the native curve.

**How to apply:** For Android scaler investigations, collect the actual Flutter `TextScaler.scale()` outputs, native `TypedValue.applyDimension(...)/density` outputs, active `Configuration`, and all relevant `DisplayMetrics` fields for each OS position before changing the mapping formula.
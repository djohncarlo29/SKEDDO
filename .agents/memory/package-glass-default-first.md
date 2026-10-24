---
name: Package glass default-first rule
description: Start new flutter_liquid_glass_widgets surfaces with their defaults; reuse SKEDDO's shared optical settings only after a visual mismatch is reported.
---

For newly added `flutter_liquid_glass_widgets` components, use the package's
default glass behavior on the first pass. If the user says a component's glass
looks wrong, immediately apply the shared SKEDDO glass settings used by the
floating tab bar and modal toolbar buttons rather than inventing another
renderer or tuning a separate design.

**Why:** The user wants a clean first comparison against the package, followed
by a consistent correction path when its default optics do not fit SKEDDO.

**How to apply:** Do not automatically pass the shared settings to unrelated
new package widgets. After the user flags a mismatch, reuse the shared settings
source and preserve the package's rendering path.

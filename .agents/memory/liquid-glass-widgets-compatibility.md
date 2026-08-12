---
name: Liquid Glass Widgets compatibility
description: The current Smart Scheduler Flutter toolchain can use liquid_glass_widgets 0.5.0, while newer releases require newer SDK APIs.
---

Use `liquid_glass_widgets` 0.5.0 for the current Smart Scheduler toolchain. The requested 0.29.x releases require Flutter 3.41+, 0.18.4 fails web compilation on the current SDK, and 0.18.0–0.18.2 conflict with Flutter's pinned `meta` version.

**Why:** The preview workflow uses Flutter 3.35.7; newer package releases either fail pub resolution or call framework APIs unavailable to its web compiler.

**How to apply:** If the Flutter workflow is upgraded to 3.41 or later, reevaluate the pin and move to the requested 0.29.x release. Keep shared switches as bare `GlassSwitch` widgets and pass caller-provided accent/category color through `activeColor`.
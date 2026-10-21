---
name: Liquid Glass Widgets compatibility
description: Flutter SDK requirements and package-name distinctions for Smart Scheduler's glass navigation widgets.
---

`flutter_liquid_glass_widgets` 0.0.1 contains `GlassLargeTitle` and `GlassAppBar`. Its transitive `flutter_a11y_lens` dependency requires Dart 3.12.2, so Smart Scheduler uses Flutter 3.44.2 (Dart 3.12.2). The similarly named `liquid_glass_widgets` is a different package; its SDK-compatible 0.5.0 release does not include the large-title API.

**Why:** The project uses the Flutter-rendered large-to-compact title behavior from `flutter_liquid_glass_widgets`; its transitive minimum is stricter than the package's own declared SDK floor.

**How to apply:** Keep the package constraint, `pubspec.yaml` Dart/Flutter minimums, managed preview SDK, and CI SDK versions compatible. Verify the title behavior on each claimed target platform before asserting parity. If the separate `liquid_glass_widgets` package is considered again, do not assume its older 0.5.0 API includes the newer title widgets.
<div align="center">

# 🪟 Flutter Liquid Glass Widgets

### Apple's iOS 26 "Liquid Glass" — in Flutter, on every platform, in two lines of code.

Real refractive blur. Jelly-like spring physics. Dynamic lighting. Not a `BackdropFilter` hack — an actual glass rendering engine.

[![pub package](https://img.shields.io/pub/v/flutter_liquid_glass_widgets.svg?label=pub.dev&labelColor=333940&logo=dart)](https://pub.dev/packages/flutter_liquid_glass_widgets)
[![pub points](https://img.shields.io/pub/points/flutter_liquid_glass_widgets?label=pub%20points&labelColor=333940)](https://pub.dev/packages/flutter_liquid_glass_widgets/score)
[![likes](https://img.shields.io/pub/likes/flutter_liquid_glass_widgets?label=likes&labelColor=333940)](https://pub.dev/packages/flutter_liquid_glass_widgets/score)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)
![Platforms](https://img.shields.io/badge/platforms-iOS%20%7C%20Android%20%7C%20macOS%20%7C%20Web%20%7C%20Windows%20%7C%20Linux-4ec9b0)

<p align="center">
  <img src="https://raw.githubusercontent.com/sujit70777/flutter_liquid_glass_widgets/main/docs/assets/explore_dark.jpg" width="190" alt="Explore tab" />
  <img src="https://raw.githubusercontent.com/sujit70777/flutter_liquid_glass_widgets/main/docs/assets/widgets_dark.jpg" width="190" alt="Widgets catalog" />
  <img src="https://raw.githubusercontent.com/sujit70777/flutter_liquid_glass_widgets/main/docs/assets/interactive_dark.jpg" width="190" alt="Interactive widgets" />
  <img src="https://raw.githubusercontent.com/sujit70777/flutter_liquid_glass_widgets/main/docs/assets/overlays_dialog_dark.jpg" width="190" alt="GlassDialog" />
</p>

</div>

## 30-second pitch

| | |
|---|---|
| **What** | A widget library that renders Apple's real iOS 26 Liquid Glass effect — shader-based refraction, not a blurred box. |
| **Where** | iOS, Android, macOS, Web, Windows, Linux. One codebase, renderer picked automatically. |
| **When to use it** | Building nav bars, tab bars, sheets, menus — the floating chrome layer. Not for content cards or full backgrounds (see [Glass vs Content](#-glass-vs-content-30-seconds)). |
| **When *not* to use it** | You need one translucent card and nothing else → just use `BackdropFilter`. This package is heavier and more opinionated — that's the trade. |
| **The whole API surface** | `LiquidGlassWidgets.wrap()` once in `main()`, then `GlassScaffold` per screen. Everything else is optional tuning. |

## Install

```yaml
dependencies:
  flutter_liquid_glass_widgets: ^0.0.1
```

Requires Flutter ≥ 3.41.0 (Dart ≥ 3.5.0).

## Get glass on screen — 2 steps

```dart
// 1. main.dart — once
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LiquidGlassWidgets.initialize();
  runApp(LiquidGlassWidgets.wrap(child: const MyApp()));
}
```

```dart
// 2. any screen
GlassScaffold(
  background: Image.asset('assets/wallpaper.jpg', fit: BoxFit.cover),
  appBar: GlassAppBar(title: const Text('My App')),
  body: Center(child: GlassCard(child: Text('Hello, Glass!'))),
)
```

That's it — `GlassScaffold` wires up background, blur layer, z-ordering, and status bar automatically. Full options: [`docs/GUIDE.md#glassscaffold--glasspage`](docs/GUIDE.md#glassscaffold--glasspage).

## 🧭 Glass vs Content (30 seconds)

Glass = navigation chrome. Content = opaque, always.

```
┌──────────────────────────┐
│   GlassAppBar (glass)    │  ← nav bars, tab bars, sheets, menus, buttons
├──────────────────────────┤
│   Opaque content area    │  ← ListView, cards, article tiles — normal Flutter widgets
├──────────────────────────┤
│  GlassBottomBar (glass)  │
└──────────────────────────┘
```

One more rule: **don't nest interactive glass widgets inside `GlassCard`/`GlassContainer`** — they're base surfaces, not wrappers (the effect silently degrades if you do). [`liquid_glass_lints`](https://github.com/sujit70777/liquid_glass_lints) catches this in your editor. Full explanation: [`docs/GUIDE.md#-glass-vs-content--design-philosophy`](docs/GUIDE.md#-glass-vs-content--design-philosophy).

## Which widget do I need?

| I want... | Use |
|---|---|
| A screen with an app bar / tab bar | **`GlassScaffold`** — start here for almost everything |
| A custom layout without a standard scaffold | `GlassPage` |
| A standalone floating card or panel | `GlassCard` / `GlassContainer` |
| Buttons, switches, sliders, chips | `GlassButton` · `GlassSwitch` · `GlassSlider` · `GlassChip` · `GlassSegmentedControl` |
| Text fields, search, pickers | `GlassTextField` · `GlassSearchBar` · `GlassPicker` · `GlassCalendarPicker` |
| Dialogs, sheets, menus, popovers | `GlassDialog` · `GlassModalSheet` · `GlassMenu` · `GlassPopover` · `GlassCommandPalette` |
| Toasts, progress, skeleton loading | `GlassToast` · `GlassProgressIndicator` · `GlassSkeletonLoader` |

Full catalog of every widget (40+): [`docs/GUIDE.md#-widget-categories`](docs/GUIDE.md#-widget-categories).

## Why this over a plain `BackdropFilter` wrapper?

| | Typical glassmorphism package | This package |
|---|---|---|
| Rendering | Blur + translucent color | Real shaders — refraction, specular highlights, chromatic aberration |
| Motion | Opacity/blur tweens | Physics-based liquid morphing engine |
| Device performance | One fixed look | 3 auto-tuned quality tiers, persisted across launches |
| Accessibility | Usually bolted on | Reduce Motion / Reduce Transparency handled automatically, everywhere |
| Scope | A few container widgets | Full navigation-chrome system: scaffold, bars, sheets, menus, command palette |

Full comparison and honest trade-offs: [`docs/GUIDE.md#-why-flutter_liquid_glass_widgets`](docs/GUIDE.md#-why-flutter_liquid_glass_widgets).

## Run an example

```bash
cd example && flutter pub get && flutter run
```

Full-app demos (Apple Music, Messages, News replicas + a travel-app showcase) and 12 focused copy-paste demos: [`docs/GUIDE.md#️-examples`](docs/GUIDE.md#️-examples).

## Everything else

This README is intentionally short. Deeper reference material lives in **[`docs/GUIDE.md`](docs/GUIDE.md)**:

- Theming (app-wide, per-screen, per-subtree)
- Glass quality modes (`standard` / `premium` / `minimal`) and when to use each
- Performance tuning, adaptive quality, and cross-launch persistence
- Accessibility behavior and override priority
- Gyroscope-driven lighting
- Rendering architecture (for contributors / debugging)
- Testing

## License & Attribution

MIT. This package forks [`liquid_glass_widgets`](https://github.com/sdegenaar/liquid_glass_widgets) by Sebastian Degenaar, built on [`liquid_glass_renderer`](https://github.com/whynotmake-it/flutter_liquid_glass) by whynotmake.it (both MIT). See [`lib/src/renderer/RENDERER_ATTRIBUTION.md`](lib/src/renderer/RENDERER_ATTRIBUTION.md).

- [pub.dev](https://pub.dev/packages/flutter_liquid_glass_widgets) · [Repository](https://github.com/sujit70777/flutter_liquid_glass_widgets) · [Issues](https://github.com/sujit70777/flutter_liquid_glass_widgets/issues)

<div align="center">

**If this saved you from hand-rolling shader code, a ⭐ on GitHub goes a long way.**

</div>

# Full Guide

This is the deep-reference companion to the [main README](../README.md). The README gets you running in a minute; this document covers everything else — theming, quality tuning, accessibility internals, architecture, and the full widget catalog.

## Contents

- [Why `flutter_liquid_glass_widgets`](#-why-flutter_liquid_glass_widgets)
- [Examples](#️-examples)
- [Glass vs Content — Design Philosophy](#-glass-vs-content--design-philosophy)
- [Widget Categories](#-widget-categories)
- [Theming](#-theming)
- [Platform Support](#-platform-support)
- [Glass Quality Modes](#️-glass-quality-modes)
- [GlassScaffold / GlassPage](#glassscaffold--glasspage)
- [Performance Tips](#-performance-tips)
- [Custom Refraction for Interactive Indicators](#-custom-refraction-for-interactive-indicators)
- [Gyroscope Lighting](#-gyroscope-lighting)
- [Accessibility](#-accessibility)
- [Architecture](#️-architecture)
- [Testing](#-testing)

---

## 💎 Why `flutter_liquid_glass_widgets`?

Most "glassmorphism" packages for Flutter are a `BackdropFilter` blur plus a semi-transparent `Container` — a flat approximation of glass. This one is built to match how iOS 26 actually renders Liquid Glass, with a real shader pipeline underneath instead of a translucent box.

| | Typical glassmorphism package | `flutter_liquid_glass_widgets` |
|---|---|---|
| **Rendering** | `BackdropFilter` blur + translucent color | Custom fragment shaders — real refraction, specular highlights, chromatic aberration, Fresnel edge lighting |
| **Motion** | Opacity/blur tweens | [Liquid Morph Engine](#liquid-morph-engine) — a standalone physics system (spring dynamics, teardrop morphing) independent of any single widget |
| **Performance across devices** | One fixed look, no device awareness | Three [quality tiers](#️-glass-quality-modes) chosen automatically per device, with adaptive runtime tuning and cross-launch persistence so the benchmark only ever runs once |
| **Accessibility** | Usually bolted on, if present at all | Reduce Motion / Reduce Transparency respected automatically everywhere — see [Accessibility](#-accessibility) |
| **Scope** | Usually a handful of container widgets | A full navigation-chrome **system** — scaffold, app bar, tab bar, sheets, menus, command palette |
| **GPU safety net** | None | `GlassPerformanceMonitor` watches raster frame budget and tells you exactly which widget to change |

**The honest trade-off:** this is a heavier, more opinionated library than a simple blur wrapper. If you need one translucent card, `BackdropFilter` alone is enough — don't reach for this. If you're building navigation chrome that should look and behave like iOS 26's Liquid Glass, including on Android, Web, and desktop, that's exactly what this package exists for.

---

## 🖼️ Examples

### [Wanderlust](../example/showcase/) — Luxury Travel Showcase
A premium app demonstrating the package in a real-world production context — full-bleed imagery, parallax scroll, hero transitions, and a concierge chat interface.

```bash
cd example/showcase && flutter pub get && flutter run
```

### [Apple Music Demo](../example/lib/apple_music/) — iOS 26 Replica
`GlassTabBar.searchable()`, a floating playback pill, and the full iOS 26 navigation model with smooth morphing transitions.

```bash
cd example && flutter pub get && flutter run -t lib/apple_music/apple_music_demo.dart
```

### [Apple Messages Demo](../example/lib/apple_messages/) — iOS 26 Replica
Showcases the **Liquid Morph Engine** via `GlassMenu`. Tap the menu or **Edit** button to see the teardrop open/close physics live.

```bash
cd example && flutter pub get && flutter run -t lib/apple_messages/apple_messages_demo.dart
```

### [Apple News Demo](../example/lib/apple_news/) — iOS 26 Replica
`GlassTabBar.searchable()` with a morphing search pill, category chips, hero cards, and rounded article tiles.

```bash
cd example && flutter pub get && flutter run -t lib/apple_news/apple_news_demo.dart
```

### [Widget Showcase](../example/) — Full Component Library
A complete catalogue of every glass widget organised by category.

```bash
cd example && flutter pub get && flutter run
```

### Component Demos — Copy-Pasteable Examples

Focused, self-contained demos in [`example/lib/demos/`](../example/lib/demos/) — one feature, one file, runnable standalone:

| Demo | Run command (from `example/`) |
|---|---|
| `glass_menu_demo.dart` — all 9 menu alignments | `flutter run -t lib/demos/glass_menu_demo.dart` |
| `glass_tab_bar_scrollable_demo.dart` — scrollable tab bar | `flutter run -t lib/demos/glass_tab_bar_scrollable_demo.dart` |
| `glass_modal_sheet_demo.dart` — peek / half / full states | `flutter run -t lib/demos/glass_modal_sheet_demo.dart` |
| `glass_bottom_bar_demo.dart` — magic-lens masking | `flutter run -t lib/demos/glass_bottom_bar_demo.dart` |
| `bottom_bar_tab_width_demo.dart` — tabWidth showcase | `flutter run -t lib/demos/bottom_bar_tab_width_demo.dart` |
| `searchable_bar_demo.dart` — searchable bar edge cases | `flutter run -t lib/demos/searchable_bar_demo.dart` |
| `shape_debug_demo.dart` — GlassButton shapes | `flutter run -t lib/demos/shape_debug_demo.dart` |
| `quality_comparison_demo.dart` — premium & standard quality playground | `flutter run -t lib/demos/quality_comparison_demo.dart` |
| `nav_bar_patterns_demo.dart` — GlassScaffold layout patterns | `flutter run -t lib/demos/nav_bar_patterns_demo.dart` |
| `content_aware_brightness_demo.dart` — light/dark bar adaptation on scroll | `flutter run -t lib/demos/content_aware_brightness_demo.dart` |
| `indicator_parity_demo.dart` — all four pill widgets side-by-side with live sliders | `flutter run -t lib/demos/indicator_parity_demo.dart` |
| `quality_persistence_demo.dart` — proves quality restores across cold starts, with live latency numbers | `flutter run -t lib/demos/quality_persistence_demo.dart` |

---

## 🧭 Glass vs Content — Design Philosophy

**Glass is for navigation, not for content.** Apple's own iOS 26 guidance reserves glass for the floating UI layer that sits *above* your app's content — nav bars, tab bars, sheets, buttons. The content underneath (lists, cards, article tiles) should stay opaque.

| ✅ Use glass for | ❌ Keep opaque |
|---|---|
| Navigation bars, tab bars, toolbars | List cells, table rows |
| Floating action buttons | Full-screen backgrounds |
| Sheets, popovers, menus | Scrollable content cards |
| Toggles, sliders, segmented controls | Article tiles, media players |

Building a Settings screen? Use `GlassScaffold` + `GlassAppBar` for navigation chrome, and `CupertinoListTile` or standard Flutter containers for the rows. Use `GlassGroupedSection` when you want glass-styled grouped rows.

### Glass Composition Rule: Glass is a Platter, Not a Wrapper

`GlassCard`, `GlassContainer`, and `GlassGroupedSection` are **base surfaces** — they sit beneath your content. They are not generic styling wrappers for other glass controls.

| ✅ Place inside GlassCard / GlassContainer | ❌ Do not place inside |
|---|---|
| `Text`, `Icon`, `ListTile`, `CupertinoListTile` | `GlassSegmentedControl`, `GlassSlider`, `GlassSwitch` |
| `GlassListTile`, `GlassDivider` | `GlassButton`, `GlassChip`, `GlassIconButton` |
| Standard Flutter form widgets | Any other refractive glass widget |

**Why?** `GlassContainer` sets `avoidsRefraction: true` on its children so nested glass cannot refract through the outer layer — the inner effect degrades by design. On Impeller with `useOwnLayer: true`, the container's own-layer clip also cuts jelly-physics overshoots from interactive indicators during animations.

Interactive glass controls already provide their own surface appearance via `backgroundColor` and `indicatorColor` — no outer container is needed for the track or background.

> **Catch this at edit-time, not runtime:** [`liquid_glass_lints`](https://github.com/sujit70777/liquid_glass_lints) is a `custom_lint` package that flags this exact mistake in your editor, before it ships as a silently-degraded glass surface.

```yaml
dev_dependencies:
  custom_lint: ^0.8.1
  liquid_glass_lints: ^0.0.1
```

---

## 🗂️ Widget Categories

### Containers
`GlassCard` · `GlassContainer`\* · `GlassAvatar` · `GlassChart` · `GlassDivider` · `GlassGroupedSection` · `GlassListTile` · `GlassStepper` · `GlassTimeline`

\* `GlassContainer` is a low-level building block for custom glass surfaces. Most apps should use `GlassCard` or `GlassGroupedSection` instead.

### Interactive
`GlassButton` · `GlassIconButton` · `GlassChip` · `GlassSwitch` · `GlassSlider` · `GlassSegmentedControl` · `GlassPullDownButton` · `GlassButtonGroup` · `GlassBadge` · `GlassPageControl` · `LiquidGlassScope`

### Input
`GlassTextField` · `GlassTextArea` · `GlassPasswordField` · `GlassSearchBar` · `GlassPicker` · `GlassCalendarPicker` · `GlassRatingBar` · `GlassFormField`

### Feedback
`GlassProgressIndicator` · `GlassSkeletonLoader` · `GlassToast`

### Overlays
`GlassDialog` · `GlassSheet` · `GlassModalSheet` · `showGlassActionSheet` · `GlassMenu` · `GlassMenuItem` · `GlassMenuDivider` · `GlassMenuLabel` · `GlassPopover` · `GlassCommandPalette` (⌘K / Ctrl+K, fuzzy search)

### Surfaces
`GlassScaffold` · `GlassAppBar` · `GlassTabBar` (`.bottom` / `.inline` / `.searchable`) · `GlassToolbar` · `GlassLargeTitle` · `GlassDock` (macOS-style magnifying dock) · `GlassIsolationScope` · `GlassContentAwareScope` · `GlassContentAwareContent` · `GlassContentAwareBrightness`

### Accessibility
`GlassA11yScope` · `AdaptiveGlassText` · `GlassLuminanceSampler` · `GlassAccessibilityScope` · `GlassContrastRule` (optional [`flutter_a11y_lens`](https://pub.dev/packages/flutter_a11y_lens) bridge)

### Theming & Performance
`GlassTheme` · `GlassThemeData` · `GlassThemePresets` (`.frostedDark` / `.clearLight` / `.tintedBrand`) · `GlassInteractionSettings` · `GlassAdaptiveScope` · `GlassPerformanceMonitor`

---

## 🎨 Theming

Pass a `theme:` to `LiquidGlassWidgets.wrap()` to set your app-wide defaults — every glass widget inherits them automatically, no per-widget configuration needed:

```dart
runApp(LiquidGlassWidgets.wrap(
  child: const MyApp(),
  theme: GlassThemeData(
    light: GlassThemeVariant(
      settings: GlassThemeSettings(thickness: 30, blur: 6),
      quality: GlassQuality.standard,
    ),
    dark: GlassThemeVariant(
      settings: GlassThemeSettings(thickness: 40, blur: 8),
      quality: GlassQuality.standard,
    ),
  ),
));
```

For a quick single-quality theme, use the `GlassThemeData.simple` shorthand:

```dart
runApp(LiquidGlassWidgets.wrap(
  child: const MyApp(),
  theme: GlassThemeData.simple(
    blur: 10,
    thickness: 30,
    quality: GlassQuality.standard,
  ),
));
```

> **`GlassThemeSettings` vs `LiquidGlassSettings`:** Use `GlassThemeSettings` inside `GlassThemeVariant`. It accepts the same parameters but all are nullable — only fields you explicitly set are applied; everything else inherits from each widget's own defaults. `LiquidGlassSettings` is the full settings type used on individual widgets.

Three-level override hierarchy (highest wins):

1. **Widget `settings` parameter** — explicit, widget-level override
2. **`GlassPage(themeOverride: ...)`** — per-screen override for special pages (onboarding, paywalls)
3. **`GlassTheme` / `wrap(theme:...)`** — app-wide defaults

Access the current theme programmatically:

```dart
final variant = GlassThemeData.of(context).variantFor(context);
```

#### Per-subtree theming

```dart
GlassTheme(
  data: GlassThemeData.simple(blur: 4, quality: GlassQuality.minimal),
  child: MyListSection(), // list cards get minimal quality
)
```

### Glow Colors

`GlassGlowColors` controls the interaction glow emitted by surfaces like `GlassBottomBar` and `GlassSearchableBottomBar`:

```dart
GlassThemeVariant(
  glowColors: GlassGlowColors(
    primary: Colors.blue,
    glowBlurRadius: 12,
    glowSpreadRadius: 0.2,
    glowOpacity: 0.8,
  ),
)
```

---

## 🌍 Platform Support

| Platform | Renderer | Notes |
|---|---|---|
| iOS | Impeller (Metal) | Full shader pipeline, chromatic aberration |
| Android | Impeller (Vulkan) | Full shader pipeline, chromatic aberration |
| macOS | Impeller (Metal) | Full shader pipeline, chromatic aberration |
| Web | CanvasKit | Lightweight fragment shader |
| Windows | Skia | Lightweight fragment shader |
| Linux | Skia | Lightweight fragment shader |

Platform detection is automatic — no configuration required.

---

## ⚙️ Glass Quality Modes

Every glass widget accepts a `quality:` parameter with three tiers. If in doubt, leave it unset — `standard` is the default and the right choice for almost every case.

### Standard — Default, Recommended

```dart
GlassContainer(
  quality: GlassQuality.standard, // this is the default
  child: const Text('Great for scrollable content'),
)
```

The right choice for the vast majority of use cases. Works on every platform with iOS 26-accurate glass effects.

### Premium — Impeller Only

```dart
GlassCard(
  quality: GlassQuality.premium,
  child: const Text('Static hero section'),
)
```

Enables the full Impeller shader pipeline with texture capture and chromatic aberration. On Skia/Web, automatically falls back to Standard.

> **Use Premium only for static, non-scrolling surfaces** (hero sections, feature cards). It may not render correctly inside `ListView` or `CustomScrollView` on Impeller. `GlassScaffold` automatically promotes app bars and bottom bars to premium quality via `GlassIsolationScope`.

### Minimal — Shader-Free

```dart
GlassCard(
  quality: GlassQuality.minimal,
  child: const Text('No shader overhead'),
)
```

Zero custom fragment shader cost on any device. Uses `BackdropFilter` blur + a Rec. 709 saturation matrix + a specular rim stroke. Visually equivalent to a high-quality frosted panel.

Two ideal use cases:
- **Device fallback** — very old Android devices or any device where `ImageFilter.isShaderFilterSupported` is `false`
- **GPU budget management** — use `minimal` for background panels and list cards while keeping `standard` or `premium` on the focal element. A screen with 15 glass list cards running `minimal` fires zero shader invocations during scroll

> **Theme shorthand**: `GlassThemeVariant.minimal` applies `minimal` quality globally via `GlassThemeData`.

---

## GlassScaffold / GlassPage

### GlassScaffold

`GlassScaffold` is the recommended way to build any screen that uses glass surfaces. It replaces the manual assembly of `GlassPage` + `Scaffold` + `GlassScrollEdgeEffect` + `Stack` with a single widget:

```dart
GlassScaffold(
  background: Image.asset('assets/wallpaper.jpg', fit: BoxFit.cover),
  statusBarStyle: GlassStatusBarStyle.light,
  appBar: GlassAppBar(
    title: const Text('Messages'),
    trailing: GlassButton(
      icon: const Icon(CupertinoIcons.compose),
      onTap: () {},
    ),
  ),
  bottomBar: GlassTabBar.bottom(
    selectedIndex: 0,
    onTabSelected: (_) {},
    tabs: const [
      GlassTab(icon: Icon(Icons.home), label: 'Home'),
      GlassTab(icon: Icon(Icons.search), label: 'Search'),
    ],
  ),
  body: CustomScrollView(
    slivers: [...],
  ),
)
```

| What it handles | Without `GlassScaffold` |
|---|---|
| Background + glass layer | Must wrap in `GlassPage` + set `scaffoldBackgroundColor: transparent` |
| Z-ordering (bars above body) | Must build a manual `Stack` with correct paint order |
| Edge fading | Must add `GlassScrollEdgeEffect` and calculate fade heights |
| Safe-area padding | Must calculate top/bottom padding for app bar and bottom bar |
| Bar isolation | Must wrap bars in `GlassIsolationScope` manually |
| Status bar icons | Must call `SystemChrome.setSystemUIOverlayStyle` and restore it |

> See `example/lib/demos/nav_bar_patterns_demo.dart` for complete `GlassScaffold` usage patterns.

### Content-Aware Brightness

Glass bars automatically adapt their icon and label colors to match the content scrolling behind them — light icons over dark content, dark icons over light content — with a smooth cross-fade transition. One flag on `GlassScaffold`, one on the bar:

```dart
GlassScaffold(
  contentAwareBrightness: true,
  bottomBar: GlassTabBar.bottom(
    adaptiveBrightness: true,
    onBrightnessChanged: (b) => debugPrint('Bar is now: $b'),
    tabs: [...],
    selectedIndex: _index,
    onTabSelected: (i) => setState(() => _index = i),
  ),
  body: CustomScrollView(
    slivers: [...], // content scrolls underneath the bar
  ),
)
```

`GlassScaffold.contentAwareBrightness` handles all the wiring — it wraps the body in `GlassContentAwareContent` and the layout in `GlassContentAwareScope` automatically. The bar uses WCAG contrast ratios with dual-threshold hysteresis to prevent flickering on borderline content.

For custom layouts without `GlassScaffold`, use the standalone widgets directly:

```dart
GlassContentAwareScope(
  child: Scaffold(
    extendBody: true,
    body: GlassContentAwareContent(
      child: ListView(...),
    ),
    bottomNavigationBar: GlassTabBar.bottom(
      adaptiveBrightness: true,
      ...
    ),
  ),
)
```

> See `example/lib/demos/content_aware_brightness_demo.dart` for a focused showcase.

### GlassPage

`GlassPage` is the lower-level building block that `GlassScaffold` uses internally. Use it directly when you need full manual control over your layout — custom `Stack` ordering, non-standard bar placements, or screens without a traditional scaffold structure.

> **For most apps, `GlassScaffold` is simpler.** Use `GlassPage` only when you need a custom layout that `GlassScaffold` doesn't support.

```dart
// Minimum — just wrap your Scaffold, GlassPage handles everything else:
GlassPage(
  child: Scaffold(
    appBar: GlassAppBar(title: const Text('Home')),
    body: MyContent(),
  ),
)

// With a wallpaper:
GlassPage(
  background: Image.asset('assets/wallpaper.jpg', fit: BoxFit.cover),
  edgeToEdge: true,
  statusBarStyle: GlassStatusBarStyle.auto,
  child: Scaffold(
    appBar: GlassAppBar(title: const Text('Home')),
    body: MyContent(),
  ),
)
```

| What it handles | Without `GlassPage` |
|---|---|
| Transparent `Scaffold` | Must set `scaffoldBackgroundColor: transparent` manually |
| Navigation ghosting | Handled automatically — each glass layer isolates its own backdrop |
| Background scope setup | Must wrap in `LiquidGlassScope` manually |
| Status bar icons | Must call `SystemChrome.setSystemUIOverlayStyle` and restore it |
| Edge-to-edge mode | Must call `SystemChrome.setEnabledSystemUIMode` and restore it |
| Per-screen theme | Must wrap subtree in a local `GlassTheme` manually |

#### Parameters

| Parameter | Default | Purpose |
|---|---|---|
| `background` | `null` | Optional wallpaper/background widget. When omitted, `Scaffold` background is left unchanged |
| `child` | required | Screen content, typically a `Scaffold` |
| `enableBackgroundSampling` | `true` when `background` is set, `false` otherwise | GPU texture capture for real colour absorption. Set `false` explicitly to opt out |
| `statusBarStyle` | `GlassStatusBarStyle.none` | Status bar icon brightness; `auto` is recommended for wallpaper screens |
| `edgeToEdge` | `false` | Draw content behind system bars (full immersive) |
| `themeOverride` | `null` | Per-screen `GlassThemeData` override for special screens |

> **Tip for `edgeToEdge` on Android:** When `true`, content draws underneath the Android navigation bar. Wrap your `Scaffold` body in a `SafeArea` (or use `extendBody: true` and pad the bottom) so your content isn't hidden behind the system buttons.

### Specular Sharpness

Control the tightness of the specular highlight on any glass surface via `LiquidGlassSettings.specularSharpness`:

```dart
GlassCard(
  settings: LiquidGlassSettings(
    specularSharpness: GlassSpecularSharpness.sharp, // tight, mirror-like
  ),
  child: ...,
)
```

| Value | Look |
|---|---|
| `GlassSpecularSharpness.soft` | Wide, diffuse — frosted / matte glass |
| `GlassSpecularSharpness.medium` | **Default** — matches iOS 26 |
| `GlassSpecularSharpness.sharp` | Tight, polished — mirror-like surface |

Each value maps to a fixed power-of-2 exponent. The GPU uses a zero-transcendental multiply chain for each — no `pow()` overhead.

---

## ⚡ Performance Tips

1. **`LiquidGlassWidgets.initialize()`** at startup — pre-caches shaders, eliminates the white flash on first render
2. **`LiquidGlassWidgets.wrap()`** in `main.dart` — installs accessibility bridging and global theming; pass `adaptiveQuality: true` for automatic per-device quality tuning
3. **Standard quality for scrollable content** — lists, forms, interactive widgets
4. **Premium quality for fixed surfaces** — app bars, bottom bars, and hero sections
5. **Minimal quality for shader-dense screens** — fire zero custom shader invocations during scroll, then keep `standard` or `premium` only on the focal element
6. **Accessibility fallbacks are zero-cost** — when Reduce Transparency is active, the glass shader is bypassed entirely; `BackdropFilter` blur runs in Flutter's own paint layer with no custom shader overhead

### Automatic Quality Adaptation *(experimental)*

> 📊 **`GlassAdaptiveScope` is `@experimental`** — its timing thresholds need more real-device data to be finalised. If you use `adaptiveQuality: true`, please share your device model, Flutter version, and observed P75 ms via an [issue](https://github.com/sujit70777/flutter_liquid_glass_widgets/issues). See [`docs/ADAPTIVE_QUALITY.md`](ADAPTIVE_QUALITY.md) for current threshold values and the reporting snippet.

`GlassAdaptiveScope` (enabled via `wrap(adaptiveQuality: true)`) automatically benchmarks the device at startup and adjusts quality in real time:

```dart
// Minimal — let the library decide the best quality for the device:
runApp(LiquidGlassWidgets.wrap(child: const MyApp(), adaptiveQuality: true));

// Per-screen — fine-grained control on specific routes:
GlassAdaptiveScope(
  initialQuality: GlassQuality.standard, // conservative start
  allowStepUp: true,
  // Android calibration — raise if your device is incorrectly demoted to standard.
  // warmupPremiumThresholdMs: 24.0,  // default 20.0
  // warmupStandardThresholdMs: 32.0, // default 28.0
  child: Scaffold(...),
)
```

#### Eliminating repeat warmup jank (recommended for production)

On the first launch, `GlassAdaptiveScope` runs a ~3-second warm-up benchmark to measure real raster performance. On a Pixel 4a, this benchmark observes slow frames and steps down to `minimal`. Without persistence, this happens on every cold start — the user sees 3 seconds of degraded quality every time they open the app.

**Within a single app process**, the library caches the settled quality automatically. If the scope is disposed and remounted, Phase 2 is not re-run — no extra code required.

**Across cold starts**, use `GlassQualityPersistence.auto()` — zero-config, built into the library, backed by `shared_preferences` under the hood:

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final persistence = GlassQualityPersistence.auto();

  await LiquidGlassWidgets.initialize(qualityPersistence: persistence);

  runApp(LiquidGlassWidgets.wrap(
    child: const MyApp(),
    adaptiveQuality: true,
    qualityPersistence: persistence, // restores + persists automatically
  ));
}
```

On first launch: nothing persisted yet → Phase 2 runs → quality settles → saved. On every subsequent launch: the saved quality is restored immediately → Phase 2 is skipped → no jank.

> See `example/lib/demos/quality_persistence_demo.dart` — it writes a quality to disk, then reads it back through a brand new `GlassQualityPersistence` instance (exactly what a real relaunch does) and shows the actual read latency next to the ~3000ms benchmark it replaces.

`GlassQualityPersistence` is purely additive to `adaptiveConfig` — an explicit `adaptiveConfig.initialQuality` or `onQualityChanged` always takes precedence:

```dart
qualityPersistence: persistence,
adaptiveConfig: GlassAdaptiveScopeConfig(
  onQualityChanged: (from, to) =>
      analytics.log('glass_quality', {'from': from.name, 'to': to.name}),
),
```

#### Advanced: custom storage

```dart
class MyQualityStore extends GlassQualityStore {
  @override
  Future<GlassQuality?> read() async => ...;

  @override
  Future<void> write(GlassQuality quality) async => ...;
}

final persistence = GlassQualityPersistence(MyQualityStore());
```

Or wire `onQualityChanged` + `adaptiveConfig.initialQuality` manually — both parameters remain fully supported.

### GPU Budget Monitoring

`GlassPerformanceMonitor` watches raster frame durations while `GlassQuality.premium` surfaces are active. When frames exceed the GPU budget for 60 consecutive frames it emits a single `FlutterError` with actionable guidance — which widget to change, which quality tier to try, and why.

**Zero production overhead** — automatically disabled in release builds. Enabled by default in debug/profile via `LiquidGlassWidgets.initialize()`:

```dart
// Default — auto-enabled in debug/profile, zero-cost in release
await LiquidGlassWidgets.initialize();

// Opt out entirely
await LiquidGlassWidgets.initialize(enablePerformanceMonitor: false);

// Custom thresholds
GlassPerformanceMonitor.rasterBudget = const Duration(microseconds: 8333); // 120 fps
GlassPerformanceMonitor.sustainedFrameThreshold = 120;
```

---

## 🔮 Custom Refraction for Interactive Indicators

On Skia and Web, interactive widgets like `GlassSegmentedControl` can display true liquid glass refraction from a background image.

**Recommended: use `GlassPage(background:...)`** — it wires up the refraction source automatically and is the cleanest integration path:

```dart
GlassPage(
  background: Image.asset('assets/wallpaper.jpg', fit: BoxFit.cover),
  child: Scaffold(
    body: Center(
      child: GlassSegmentedControl(
        segments: const ['Option A', 'Option B', 'Option C'],
        selectedIndex: 0,
        onSegmentSelected: (i) {},
        quality: GlassQuality.standard,
      ),
    ),
  ),
)
```

**Manual alternative — `LiquidGlassScope`:**

```dart
// Shorthand — wallpaper behind your Scaffold:
LiquidGlassScope.stack(
  background: Image.asset('assets/wallpaper.jpg', fit: BoxFit.cover),
  content: Scaffold(
    body: Center(child: GlassSegmentedControl(...)),
  ),
)

// Manual — granular control over which surface is sampled:
LiquidGlassScope(
  child: Stack(
    children: [
      Positioned.fill(
        child: GlassBackgroundSource(
          child: Image.asset('assets/wallpaper.jpg'),
        ),
      ),
      Center(child: GlassSegmentedControl(...)),
    ],
  ),
)
```

On Impeller, `GlassQuality.premium` uses the native scene graph — no `LiquidGlassScope` needed.

| When | Recommendation |
|---|---|
| Skia / Web (recommended) | `GlassPage(background:...)` — automatic wiring |
| Skia / Web (manual) | `LiquidGlassScope.stack` with `GlassQuality.standard` |
| iOS / macOS (Impeller) | `GlassQuality.premium` — native scene graph |
| Multiple isolated sections | Separate `LiquidGlassScope` per section |

---

## 🎮 Gyroscope Lighting

`GlassMotionScope` drives the specular highlight angle from any `Stream<double>`, including a device gyroscope via [`sensors_plus`](https://pub.dev/packages/sensors_plus):

```dart
GlassMotionScope(
  stream: gyroscopeEvents.map((e) => e.y * 0.5),
  child: Scaffold(
    appBar: GlassAppBar(title: const Text('My App')),
    body: ...,
  ),
)
```

No new dependencies required — connect any stream source (scroll position, mouse, gyroscope).

---

## ♿ Accessibility

Every glass widget in this package respects the user's system accessibility preferences **automatically** — no setup required.

| System Setting | Effect on glass widgets |
|---|---|
| **Reduce Motion** (iOS/macOS/Android) | All spring/jelly animations snap instantly to their target |
| **Reduce Transparency / High Contrast** | Glass shader replaced with a plain frosted `BackdropFilter` panel — zero GPU shader cost |

### No setup needed

Just ship your app. If the user has Reduce Motion on, your widgets snap. If they have Reduce Transparency on, they get a solid frosted fallback. Nothing to configure.

### Optional: `GlassAccessibilityScope`

Place `GlassAccessibilityScope` in your tree to **override** system defaults — useful for testing, showcases, or per-subtree customisation:

```dart
MaterialApp(
  builder: (context, child) => GlassAccessibilityScope(
    child: child!, // reads system flags automatically
  ),
)

// Force a specific state (e.g. demo frosted fallback in a settings screen)
GlassAccessibilityScope(
  reduceTransparency: true,
  child: GlassSettingsPreview(),
)
```

`GlassAccessibilityScope` always wins over the system flag — it's the highest-priority override.

### Opting out globally

For experiences where full glass fidelity is intentional (games, creative tools):

```dart
runApp(LiquidGlassWidgets.wrap(
  child: const MyApp(),
  respectSystemAccessibility: false,
));
```

This disables only the automatic system-flag bridge. An explicit `GlassAccessibilityScope` in the widget tree still works regardless.

### Priority order (highest wins)

1. `GlassAccessibilityScope` in the widget tree — explicit developer override
2. System `MediaQuery` flags — automatic, respects user's OS setting
3. `wrap(respectSystemAccessibility: false)` — disables (2) globally

---

## 🏛️ Architecture

*For anyone extending the library or debugging a rendering issue. You don't need to read this to use the widgets.*

### Rendering pipeline

On Impeller, every `GlassQuality.premium` surface uses a two-pass pipeline:

1. **Blur pass** — `BackdropFilterLayer(ImageFilter.blur)`, clipped to the exact widget shape. Each `LiquidGlassLayer` manages its own isolated `BackdropGroup` for GPU capture.
2. **Shader pass** — `BackdropFilterLayer(ImageFilter.shader)` — refraction, edge lighting, glass tint, and chromatic aberration.

On Skia/Web, `lightweight_glass.frag` runs as a single pass with no backdrop capture.

### Liquid Morph Engine

A standalone physics and animation system powering iOS 26-style teardrop morphing. It lives in `lib/engine/` and is fully decoupled from any specific widget — `GlassMenu` is its first consumer.

Key types: `GlassMorphController` · `LiquidMorphState` · `LiquidMorphPhysics` · `MorphPhase` · `MorphSpeed`

See [`docs/LIQUID_MORPH_ENGINE.md`](LIQUID_MORPH_ENGINE.md) for a full integration guide.

### Content-Adaptive Glass Strength (0.7.0)

Both render paths automatically adapt glass strength to background brightness:

- **Dark backgrounds** → richer, more opaque glass (1.2× strength, brighter Fresnel rim)
- **Light backgrounds** → subtler, more translucent glass (0.8× strength)

On Impeller, backdrop luminance is sampled directly from the refracted texture (zero extra reads). On Skia/Web, `MediaQuery.platformBrightnessOf` provides a lightweight proxy.

---

## 🧪 Testing

```bash
# All tests
flutter test

# Exclude golden tests
flutter test --exclude-tags golden

# macOS golden tests (require Impeller)
flutter test --tags golden
```

---

## Dependencies

Minimal runtime dependencies beyond the Flutter SDK: `equatable`, `flutter_shaders`, `logging`, and `shared_preferences` (backs `GlassQualityPersistence.auto()`).

The glass rendering pipeline builds on the open-source work of [whynotmake-it](https://github.com/whynotmake-it). Their [`liquid_glass_renderer`](https://github.com/whynotmake-it/flutter_liquid_glass/tree/main/packages/liquid_glass_renderer) (MIT) has been vendored and extended with bug fixes, performance improvements, and shader optimisations.

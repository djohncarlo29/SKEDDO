---
name: DCV header flicker fix
description: Why AnimatedBuilder.child optimization causes DCV flicker and how to fix it in AppShell.
---

## The rule
DCV-sensitive header elements (back chevron, ellipsis, title) must use `ValueListenableBuilder<String?>` listening to `_dcvNotifier`, NOT read `_isDCV` / `_dcvCategory` inline inside the `AnimatedBuilder.child` column.

**Why:** `AnimatedBuilder` caches the `child:` parameter and reuses it across every animation frame. When `_setSearchFocused(false)` fires (keyboard dismissal, often during DCV tap), it calls `_searchModeController.reverse()` which starts the search-exit fade animation. The `FadeTransition` inside the builder fades in the cached child — which may carry stale `_isDCV=false` state if `AppShell.setState` hasn't propagated to that child yet, producing a 1–3 frame flicker of the wrong header state.

**How to apply:** In `_AppShellState`:
- `final ValueNotifier<String?> _dcvNotifier = ValueNotifier(null);`
- Set `_dcvNotifier.value` BEFORE the `setState` call in both `_enterDCV` and `_exitDCV`.
- Dispose it in `dispose()`.
- Wrap each of the three header elements in `ValueListenableBuilder<String?>(valueListenable: _dcvNotifier, builder: (ctx, dcvCat, _) { ... })`. The `dcvCat != null` check replaces `_isDCV`.

## Page transition
`didUpdateWidget` in `EventsTabState` must use `jumpToPage` (not `animateToPage`) deferred via `addPostFrameCallback` — eliminates the 380ms slide that kept both pages visible and made SVG icon loading visible during DCV entry. Direct `ScrollPosition` mutations during build (inside `buildScope`) can cause errors; post-frame is always safe.

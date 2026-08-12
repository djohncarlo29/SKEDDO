---
name: Calendar year↔month shared-element morph
description: Per-element morph replaced the single Matrix4 Transform for the year↔month transition. The overlay approach is the current working pattern.
---

## Current approach: _MorphOverlay per-element lerp

The `_MorphOverlay` StatelessWidget replaces the old single Matrix4 Transform. It renders for `0.005 < zoomT < 0.995` as an `IgnorePointer` overlay. At `zoomT < 0.005` the static year view shows; at `zoomT > 0.995` the static month view shows.

**Why per-element instead of one Transform:** The Matrix4 approach is geometrically correct for preserving gaps, but it can't produce a true shared-element morph — individual cells can't converge on independent month-view positions. The per-element approach accepts a small positional approximation in exchange for the genuine shared-element visual.

## Geometry constants

```
miniW   = (sw - 2*16 - 2*12) / 3       // _kYearOuterPad, _kYearColGap
cellSz  = miniW / 7
sFinal  = sw / miniW
s(t)    = 1 + (sFinal - 1) * t
focalX  = 16 + zCol * (miniW + 12)
focalY  = rowTop[zRow] + cellSz*1.35 + 5.0 - scrollOffset   // letters-row TOP in screen coords (NOT first data row!)
rowTop  initialised at 17.5 (year-view scroll top padding, +1px from original 16.5)
xZ(px)  = s*px - sFinal*focalX*t       // used only for non-selected months + name label
yZ(py)  = s*py - sFinal*focalY*t
mCellW  = (sw - 7) / 8                 // month view: 8 equal cols (wk-num + 7 days)
```

## Render order (Stack children)

1. Background (kBackgroundColor fill)
2. 11 non-selected mini months — zoom-following via xZ/yZ + Transform.scale(s); non-horizontal fade out by t=0.4
3. Selected-month day cells — straight-line lerp from year position to month position
4. Week numbers + separator lines — fade in with opacity=t
5. DOW header background — fades in from t=0.5 to t=1.0
6. DOW letters → labels crossfade — letters alpha=(1-t*2.5).clamp, labels alpha=(t*2.5-1).clamp
7. Selected month name label — zoom-following, fades out by t=0.4

## Thresholds

- `headerTitle`: year case switch at t>=0.35 (month→year); month case switch at t<0.65 (year→month)
- `_adjacentTitles`: same 0.65 threshold
- `_onZoomTick`: forward snap at t=0.65, reverse snap at t=0.35

## Key dependency

`lerpDouble` requires `import 'dart:ui' show lerpDouble;` — flutter/cupertino.dart alone does NOT expose it as a free function inside StatelessWidget.build.

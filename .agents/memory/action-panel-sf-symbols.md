---
name: Action-panel SF Symbols
description: Action-panel glyphs use flutter_sficon SF Symbols with native variable font weight instead of blurred Cupertino glyph shadows.
---

Action panels should use `SFIcon`/`SFIcons` for standard menu glyphs. Render standard action-panel SF Symbols at `FontWeight.w600`, with pencil edit actions intentionally using `FontWeight.w500`; do not route these rows through the blurred `SearchWeightedIcon` faux-weight renderer.

**Why:** The previous Cupertino font path simulated weight with a same-color blur shadow, which made small action-panel icons look soft compared with the app's CustomPainter View Mode icons. SF Symbols provide actual variable font weight.

**How to apply:** Keep `SearchWeightedIcon` for search-bar or unrelated legacy surfaces, but use the shared action-panel SF renderer whenever adding or changing `ActionItem` icons, chevrons, or checkmarks. Set `iconWeight: FontWeight.w500` for pencil edit actions.
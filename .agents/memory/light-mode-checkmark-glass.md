---
name: Modal toolbar glass fidelity
description: Modal sheet and attachment-preview confirmations use SKEDDO's captured glass, with accent tint and disabled state.
---

Modal sheet and Notes attachment-preview toolbar controls use the shared
SKEDDO `StaticLiquidGlassActionButton` rendering path. Active checkmarks keep a
neutral translucent glass surface and use the action's accent/category color as
the glyph tint. A checkmark whose action surface is `kDisabledActionSurface`
remains glass but is disabled.

**Why:** The package `GlassButton` selects a lightweight frosted fallback when
its premium shader is unavailable, which can look like a blur overlay. SKEDDO's
captured lens is the established optical renderer for these controls.

**How to apply:** Route sheet and attachment-preview toolbar actions through the
shared wrapper. Keep checkmark tint separate from its glass surface and preserve
the app-owned renderer's capture, contour, and tap behavior.
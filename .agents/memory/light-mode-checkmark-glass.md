---
name: Modal toolbar checkmark glass
description: Modal sheet and attachment-preview confirmations stay glass and use the active action tint.
---

Modal sheet and Notes attachment-preview toolbar controls use the
`flutter_liquid_glass_widgets` glass button. Active checkmarks stay glass in both
themes and use the action's accent/category color as the glyph tint. A checkmark
whose action surface is `kDisabledActionSurface` remains glass but is disabled.

**Why:** The app-owned lens made the light checkmark appear white on saturated
surfaces; the user explicitly requested the package's glass button for modal
toolbars and an accent-tinted or disabled confirmation, rather than an opaque fill.

**How to apply:** Route sheet and attachment-preview toolbar actions through the
shared package-backed button. Keep this scoped to modal toolbar controls; unrelated
fixed-color action circles retain their existing app-owned glass implementation.
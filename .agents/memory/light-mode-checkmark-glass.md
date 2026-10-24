---
name: Modal toolbar package glass
description: Modal toolbar actions use flutter_liquid_glass_widgets GlassIconButton with accent-tinted or disabled checkmarks.
---

Modal sheet and Notes attachment-preview toolbar controls use the package's
`GlassIconButton`, which is designed for toolbar icon actions. Active checkmarks
use the action's accent/category color for the glyph. A checkmark whose action
surface is `kDisabledActionSurface` remains a glass button but is disabled.

**Why:** The user explicitly wants the package's toolbar glass buttons here;
using SKEDDO's custom action renderer does not meet that product requirement.

**How to apply:** Route sheet and attachment-preview toolbar actions through the
shared wrapper with `GlassQuality.premium` and `useOwnLayer: true`; keep action
tint and disabled state on the glyph/button without replacing package rendering.
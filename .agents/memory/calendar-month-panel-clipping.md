---
name: Calendar month panel clipping
description: Prevents vertically transformed week-strip content from leaking out of adjacent horizontal month panels.
---

Each previous, current, and next month panel in the three-panel calendar must be clipped to its own `screenW`-wide `Positioned` bounds before applying the vertical strip transform.

**Why:** The month view intentionally allows some internal overflow for collapse and scrolling. Without a panel-local clip, a horizontally off-screen panel can paint its transformed week rows into the visible DOW/header area.

**How to apply:** Keep the panel structure as `Positioned(width: screenW) → ClipRect → Transform.translate → _MonthView`; do not rely on the outer calendar stack’s clip to isolate adjacent panels.
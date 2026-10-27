---
name: Calendar runtime behavior index
description: Focused implementation notes for Calendar interactions, list rendering, scroll state, and landscape geometry.
---

- [Day View dual-axis swipe isolation](calendar-swipe-isolation.md) — week-strip drags and timeline drags use separate slide variables.
- [Multi-Day current-time indicator](calendar-multiday-current-time-indicator.md) — cap the line at today's active column boundary.
- [Multi-Day separator reverse morph](calendar-multiday-reverse-separator.md) — keep the timeline mounted through the reverse divider handoff.
- [ScrollController remount resync](calendar-scrollctrl-remount-resync.md) — recreate a controller after keyed remounts to avoid stale initial offsets.
- [Live-synced adjacent swipe panels](calendar-adjacent-panel-live-sync.md) — listen to the current panel controller while preview panels are open.
- [Calendar list icon weights](calendar-list-icon-weights.md) — preserve the distinct Day List icon and clipping rules.
- [Floating bar clearance math](floating-bar-clearance-math.md) — preserve Android landscape pill clearance without reducing scrollable space.
- [Calendar List DCV parity](calendar-list-dcv-parity.md) — embed the Events DCV implementation and its exact-time reorder boundaries.
- [Timeline rubberband synchronization](calendar-timeline-rubberband.md) — share only in-range offsets so sync does not cancel bounce.
- [Calendar month dot ordering](calendar-month-dot-order.md) — order month-grid dots by displayed event order.
- [Day View week-strip positioning](calendar-day-header-expanded-state.md) — keep settled Single/Multi Day headers mounted without Month panels.
- [Calendar landscape safe-area insets](calendar-landscape-header-inset.md) — inset full-width panels while preserving Month↔Day bleed lines.
- [Landscape current-time positioning](calendar-landscape-time-indicator-position.md) — center the Day timeline above the tab bar.
- [Landscape pill contour sampling](landscape-pill-contour-sampling.md) — keep contour offsets local and preserve landscape sampling density.

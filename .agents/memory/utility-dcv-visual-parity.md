---
name: Utility DCV visual parity
description: Visual and accessibility parity rules for Archived Categories and Recently Deleted inside the Events Detailed Category View.
---

## Rule

Utility detail views must use the same section-header, event-card, and category-row primitives as ordinary Detailed Category Views. Preserve utility-specific dates, values, recovery actions, and category/event grouping without creating a second typography or wrapping system.

**Why:** Utility content previously used compact custom rows, so section headers, tile geometry, chevrons, values, Dynamic Type wrapping, and fallback layouts drifted from normal Events UI.

**How to apply:** Keep utility sections collapsible through the normal DCV section label and AnimatedSize behavior. Use the shared category-row measurement/body helper for utility categories and the shared scheduled-event card for deleted events. Leave the DCV's persistent trailing section padding inside scroll-clearance math so the final visible gap remains 16pt.
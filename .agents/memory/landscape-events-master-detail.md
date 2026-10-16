---
name: Landscape Events master-detail geometry
description: Keep the Events master pane portrait-width and animate the floating tab bar to its center only while its landscape DCV split is active.
---

The landscape Events master pane begins at the physical left edge, but its content receives the shared horizontal safe-area inset on the left. Its resting width is the portrait short-edge content width plus exactly one shared inset, leaving the visible master content equal to portrait width.

Entering a landscape Events DCV split must animate the master pane from the full landscape width to that resting width while the detail pane enters from the physical right. Preserve the original right safe-area clearance at the start, then shrink it with the master pane. Use one eased progress value for the master width, detail translation, header split, and divider so dismissal reverses the same motion.

In split mode, keep the hamburger and Add Category on the master header. Put the DCV back and ellipsis controls at the detail header's leading edge and Search and Add Event at its trailing edge; divide the two header areas with a vertical line. Do not duplicate Search or Add Event in the master header.

While the split is active, animate the shared floating tab bar from screen center to the physical master pane's center. Since it sits inside symmetric content padding, use `(masterPaneWidth - physicalWidth) / 2`; using inset-reduced content width leaves it visibly left of center. Move its glass and separate shadow together. Returning to another tab or leaving the split targets normal screen center.

Keep right-pane DCV header controls laid out within the inset-safe content width, but extend the animated reveal clip through the trailing system inset as the pane enters. The inset is not a visual clipping boundary.

**Why:** The tab bar's symmetric content-padding parent remains centered on the full window, so the offset must target the physical pane bounds rather than the narrower inset-reduced child width. Clipping the right header at the usable-content edge cuts off its slide before it reaches the physical window edge. A snapped pane or independently animated headers and content makes the DCV transition appear disconnected, and centering navigation on the whole landscape screen leaves it between the panes.

**How to apply:** Keep master-pane and content widths distinct. Compute the tab offset from the physical master-pane width and full-window width; do not substitute `masterContentWidth`. Let right-header content keep its safe trailing inset while its reveal clip expands to the full detail-pane edge with the shared DCV progress. Drive the pane, header, divider, and detail translation from that same progress. Keep the tab-bar target tied to split state so it recenters when the split ends.

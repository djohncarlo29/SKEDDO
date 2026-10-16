---
name: Landscape Events master-detail geometry
description: Keep the Events master pane portrait-width and animate the floating tab bar to its center only while its landscape DCV split is active.
---

The landscape Events master pane begins at the physical left edge, but its content receives the shared horizontal safe-area inset on the left. Its resting width is the portrait short-edge content width plus exactly one shared inset, leaving the visible master content equal to portrait width.

Entering a landscape Events DCV split must animate the master pane from the full landscape width to that resting width while the detail pane enters from the physical right. Preserve the original right safe-area clearance at the start, then shrink it with the master pane. Use one eased progress value for the master width, detail translation, header split, and divider so dismissal reverses the same motion.

In split mode, keep the hamburger and Add Category on the master header. Put the DCV back, ellipsis, and title in the sliding detail header; keep one shared Search/Plus pair fixed above that slide at the full header's trailing edge. The shared actions use the active DCV while it is open and the normal Events context otherwise. Do not duplicate those actions inside the DCV header.

While the split is active, animate the shared floating tab bar from screen center to the center of the portrait-width master content. The content starts at the left system inset, so its target is `horizontalInset + masterContentWidth / 2`; do not include the inset in the portrait-width calculation or center on the wider physical pane. Move its glass and separate shadow together. Returning to another tab or leaving the split targets normal screen center.

Keep right-pane DCV header controls laid out within the inset-safe content width, but extend the animated reveal clip through the trailing system inset as the pane enters. The inset is not a visual clipping boundary.

**Why:** The tab bar's symmetric content-padding parent remains centered on the full window. Its target must account for the content's physical left origin while using only the portrait-width content to find that content's center. Centering on the inset-expanded pane places the tab bar left of the cards. Clipping the right header at the usable-content edge cuts off its slide before it reaches the physical window edge. A snapped pane or independently animated headers and content makes the DCV transition appear disconnected, and centering navigation on the whole landscape screen leaves it between the panes.

**How to apply:** Keep master-pane and content widths distinct. Compute the tab offset as `horizontalInset + (masterContentWidth - physicalWidth) / 2`, so the inset sets the content origin but is not counted as portrait content width. Keep Search/Plus outside the clipped detail-header transition, above it in the shell stack, and bind their callbacks to the active Events/DCV state. Let the detail-header reveal clip expand to the physical edge with the shared DCV progress. Keep the tab-bar target tied to split state so it recenters when the split ends.

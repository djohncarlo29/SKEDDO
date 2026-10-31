---
name: App header scroll-edge behavior
description: Shared pinned header glass edge and large-title movement across app pages.
---

## Rule
All second-level titles and ordinary scroll content must pass beneath the same first-level `LiquidGlassScrollEdge`; do not substitute title translucency or add per-screen/per-layer blur. At app level, the edge is a visual sibling overlay, never a visibility or clipping boundary. Scroll viewports and page-level ancestors must allow content to paint through the safe-area/header region; only the full-device AppShell viewport clips app content. The edge begins at physical y=0, including the status-bar region, and any local filter clip bounds only the glass effect. Keep modal-sheet clipping behavior separate. Calendar Month and Year titles and controls belong to their collapsible scroll hierarchy, while AppShell keeps the first-level toolbar fixed and handles transition-only painting. Floor negative elastic overscroll at zero, keep title-collapse and glass-edge progress separate, and keep offsets scoped to the page/view whose scroll controller owns them. Calendar Day timeline scrolling does not own the app header; exclude its notifications. Preserve content-matched landscape surfaces.

## Shared header state and per-screen body backups
One app-wide header state is authoritative across tabs, Detailed Category View, and Settings. The currently active screen supplies the latest state; a destination's inactive or saved body offset must never choose it. Header-only movement before full compact is still an expanded-body state: keep the destination body at its expanded backup while reproducing the shared header movement. Only a fully compact header selects that destination's scrolled body backup. Preserve both backups; a zero body offset must not erase the saved scrolled position. Do not map one screen's body offset or collapse range onto another's header state. Search remains a temporary mode that restores its parent snapshot exactly. Preserve the outer collapsible header, package controller, SKEDDO geometry sliver, and first-level-only glass effect.

**Why:** The user requires a real two-level-to-one-level layout change even when the body has zero normal scroll range. The installed package's title sliver keeps its title row's box extent; its controller is useful, but that box alone does not supply the requested geometry. Per-page saved header state also contradicts the user's explicit current-screen-is-authoritative rule.

**How to apply:** Preserve the active state on destination handoff and seed newly created header geometry before Calendar morph endpoints are measured. Do not reapply alignment to the same position. Keep header collapse driven by the outer position and glass-edge travel informed by the coordinated body as well. Short pages should have only the real header collapse travel, not fabricated body scroll extent. Calendar Day timelines remain independent scroll sources, but their fixed chrome must inherit the remaining shared title height rather than always reserving the expanded slot. Preserve search restoration and existing edge bounds. Nested inner-position jumps use body coordinates and can collapse the outer header even at body offset zero; even a no-op inner jump can trigger this, so body-only movement must preserve the actual outer position.

Each screen keeps separate expanded and scrolled body backups. Before the shared header is fully compact—including partial title movement—restore the expanded backup before paint and retain the scrolled backup. At fully compact, restore the destination's last scrolled body offset; a short destination stays compact even if its body cannot scroll farther. Never show a destination's stale body position for a frame before alignment.

**Why:** The user requires the active screen's header to remain authoritative, including after Settings or a no-header-owner screen is active. A partial header movement is not body scrolling, and stale destination offsets must not flash or overwrite the separate scrolled backup.

**How to apply:** Capture the outgoing screen's header state and body backup, capture any incoming stale body offset, align its outer header to the shared state, then synchronously restore the matching body backup. While a destination is inactive, pre-align only its expanded body backup during expanded/partial header states; retain its compact body backup without jumping the body until `bindTo` aligns that destination's outer header, then restore the body before reveal. Do not move inactive outer positions in the background: local layout already follows the shared transition, and moving those positions can double-apply Calendar collapse geometry. Use a body-coordinate helper that preserves outer-header geometry; never let an inner body jump redefine a partial or compact shared header. A screen without a header-owning scroll position retains the active shared state. Returning from Settings uses Settings' latest state, not the state from before opening it. Search restores its exact pre-search parent state.

Calendar's adjacent Year and Month preview panels also have independent outer header positions. Inactive previews must inherit the active panel's collapse progress at creation and mirror it live; keep their body scroll offset synchronization separate. Day timeline panels do not own this shared header.

**Why:** A preview can remain mounted after the active header changes, leaving its outer position stale even when its body scroll offset is synchronized. A newly created preview must not briefly default to expanded.

**How to apply:** Mirror normalized title-collapse progress only into inactive preview panels. Stop mirroring when a panel becomes active, and never let an inactive preview bind or overwrite the app-wide transition source.

Large Calendar title visibility must also follow the shared transition. Do not derive its fade only from the nearest scrollable: in a nested preview that can be a body still at offset zero while the shared header is compact. Keep local position metrics for overscroll correction, not for deciding whether the large title is visible.

**Why:** The compact Calendar header was correct, but preview large titles remained visible beneath the glass edge because their local scroll context could still report the top position.

**How to apply:** Use shared title-collapse progress for Calendar large-title fade in Year, Month, and Day; the shared transition notifies each title as its source panel changes state.

Calendar Day View deliberately exposes no header-owning scroll position. When the active Calendar destination has no position, preserve the shared collapse progress instead of binding null as an expanded state. The DOW mask and Day Banner use that shared title slot directly. The selected week row belongs to a separate MonthView scroll hierarchy, so apply the same shared-title offset to the selected row block itself; do not translate the entire month panel or the DOW mask moves twice. Keep the timeline an independent scroll source.

**Why:** The shared-title regression test showed that DOW and banner geometry changed with compact/expanded state while the week strip stayed at its old position. The MonthView's nested header does not continuously follow the shell-owned transition, so the row needs an explicit offset.

**How to apply:** In AppShell header handoff logic, treat a null Calendar header position as “retain current shared state.” Derive the expanded-to-compact delta from shared title height plus compact content spacing, then apply it to the selected week-row block multiplied by Month↔Day progress. Keep DOW/banner tied to their shared-position formulas and never use the timeline offset as header state.

## Second-level header overscroll behavior
During normal scrolling away from the top, a second-level header travels with its content beneath the shared Liquid Glass edge. When content rubber-bands past the top, the header stays at its resting screen position while only the content moves. Keep this as one reusable app-wide behavior; screens with titles inside a scrollable need to cancel only the negative leading overscroll, while shell-owned titles use a non-negative scroll offset. Calendar Day View Single Day and Multi Day timelines remain outside the shell-title behavior.

**Why:** The user requires consistent second-level header motion across tabs and views: scroll-away movement is part of the edge effect, but pulling content down at the top must not pull the header along with it.

**How to apply:** Use the shared header-scroll behavior for scroll-offset normalization and for titles laid out inside scroll content. Preserve normal positive-offset movement and keep the documented Day timeline exclusions.

## Positioned timeline boundary
Calendar Day timelines are positioned below the week strip and day banner, but their `AppHeaderScrollViewport` expands upward by the shell inset. Clip the timeline locally to its positioned slot so its scrolled labels and rules cannot paint over those headers. Do not add a page-level clip or change the app-wide header bleed behavior.

**Why:** The timeline's intentional shell-inset overflow is only valid when its viewport begins at the page's top edge; inside a lower positioned slot it can cover the opaque calendar headers.

**How to apply:** When an app-header-extending scroll viewport is placed below fixed header content, clip that child at its own viewport boundary and keep the week-strip and banner surfaces above it.

**Why:** Transparent backplates alone do not guarantee compositing: a title clip or a scroll viewport's hard clip can keep that layer from ever reaching the glass edge. Page-sized stack clips can create an artificial cutoff exactly at the header bottom, and a shell-title clip at the safe-area inset prevents it from continuing beneath the status-bar glass. The user explicitly requires only the first-level header to persist and all other app content to leave only at the physical viewport. Clamping the title itself leaves it stuck beneath the pinned toolbar instead of allowing it to scroll away; summing gesture deltas can diverge from ballistic or restored positions. Flutter's bouncing physics can report pixels below the minimum extent, which otherwise translates the title back down behind the toolbar. A global notification listener also sees Day timeline scrolling, so using it as header input moves the entire title group once per hour.

Keep the app-level scroll-edge treatment light enough that content passing through it remains perceptible; a strong tint or blur can look like removal even when no render clip exists.

**Why:** The shared edge is an overlay, but near-opaque tint and heavy blur can make rows, cards, and controls appear to vanish at its threshold. The user requires ordinary scrolling content to remain visible through the edge until it leaves the physical viewport.

**How to apply:** Keep Month/Year titles within the coordinated header/content scroll hierarchy, preserve measured title endpoints when the shell owns transition painting, and let page-level stacks paint through the edge band. Do not clip shell titles at the safe-area inset. Keep the AppShell's full-device viewport as the final app clipping boundary; do not change modal-sheet clips. Derive title translation from the actual header-collapse position and glass travel from the coordinated content position. Filter notifications to scrollables that actually own the header, and use distinct scopes for calendar views and day submodes. Keep the glass surface color matched to the content background and leave landscape fills unchanged.

## Raised page content ceiling
Compact-header content must retain breathing room across tabs, Detailed
Category View, and Settings. DCV section labels and Notes cards are the compact
spacing references for Settings section labels and subscreen cards respectively;
the leading clearance must scroll away with the body.

**Why:** The user clarified that Settings must match the corrected compact
spacing of Notes/DCV, not merely preserve its old spacing. The upward
paint-viewport extension must not silently cancel authored first-item spacing.

**How to apply:** Account for the viewport raise once at the shared scrolling
content boundary, but do not add constant compensation in the expanded state.
Preserve each screen's original expanded spacing, including the existing
Settings/subscreen inset. Introduce only the missing clearance as the final
collapsible region closes (search when present, title otherwise), using its
actual package-controller position. Settings' authored inset is its expanded
baseline, NOT a replacement for the extra compact clearance: retain that
baseline and add the same collapse-driven clearance as Notes/DCV.
Include that same state-dependent amount
in fixed Calendar day geometry and empty-area calculations. Do not turn it
into pinned chrome or restore a hidden large-title slot.

**Why both endpoints matter:** The user rejected a compact-only fix that added
extra expanded padding. Always verify expanded and compact endpoints together,
including Settings home and a pushed Settings subscreen, before delivery.
The user then identified the opposite regression: preserving Settings' inset
without adding the compact clearance left its section labels and subscreen
cards too high. Compare actual first-element positions across screen types,
not just whether each screen retained its previous inset.

Shared header handoffs must not recursively realign themselves or notify
sibling tabs during a destination's build.

**Why:** Settings can inherit the active position while building, but shared
header observers also belong to kept-alive sibling screens. Nested-position
`jumpTo` emits scroll notifications synchronously, so an uncleared pending
handoff can re-enter binding and repeat its jump.

**How to apply:** Align authoritative geometry immediately; coalesce listener
notifications until after the build when necessary, rather than delaying the
geometry or allowing a reentrant handoff. Consume pending handoff values before
calling `jumpTo`, so synchronous listeners cannot apply the same handoff
recursively.

For targeted app pages, raise available content by extending the shared scroll viewport at the top; do not reduce authored first-item padding or reuse `kFixedVerticalPadding` for this separate viewport adjustment. Explicit empty-state calculations based on an outer layout constraint must include the extension once; calculations based on the expanded scroll viewport already receive it.

**Why:** Raising the ceiling should preserve existing spacing before the first element while increasing the area used to center empty states. Changing that spacing too would shift content twice, and omitting manual height calculations leaves placeholders centered in the old area.

**How to apply:** Use a separate top-extension token at the viewport boundary, align custom positioned or morphing layers to it, and add the same amount to explicitly computed empty-state space.

## Centered content during header collapse
As the second-level title collapses, the actual body viewport grows by the released title height. Normal viewport-filling placeholders should center through that relayout without an additional translation. A fixed-height Calendar document needs its empty-region center to account for half the released height. Ordinary lists keep normal scroll motion; rubber-band movement does not enlarge the collapse region.

**Why:** The user wants centered content to recenter continuously as the available area expands, without snapping or treating rubber-band movement as a collapsed state.

**How to apply:** Distinguish real viewport-filling empty states from fixed expanded-region calculations before applying a center adjustment, or the new sliver layout and the old compensation will move a placeholder twice. Keep search and landscape-specific geometry separate.

## Search-mode and Calendar title alignment

For the search-collapse reference, keep the package's built-in order: large
title first, search region second. Do not silently reverse it to search-first.
Keep SKEDDO's existing search control and Liquid Glass rendering.

**Why:** The user explicitly asked to try what the package provides before
judging whether that sequence matches the desired iOS behavior.

**How to apply:** Use the package controller's separate title/search progress
with real header extents, and inherit the active header phases on navigation.
Inactive kept-alive tabs must never become the shared state source just because
their viewport metrics change.

The 16pt content-area raise applies to ordinary page content, not active search headers. Scroll-based search mode viewports must omit that extension so their bar and results retain the prior coordinates. Calendar Year and Month title rows, including their controls, remain in the scroll content but receive the matching positive paint offset; the Day title remains shell-owned and must not be offset again. A fixed Detailed Category search overlay is already outside the raised scroll viewport, so do not add another correction to it.

**Why:** The user requires search bars to keep their pre-raise position and all Calendar second-level headers to align with the shared header slot. Applying the page raise indiscriminately lifts search bars and Calendar Year/Month titles.

**How to apply:** Whenever the content top extension changes, audit active search viewports separately from normal page scroll views, and compare Year, Month, and Day title ownership before compensating.

In portrait, the normal AppShell header surface is transparent so page content can scroll beneath it. During search, switch directly to the opaque search surface instead of interpolating alpha from transparent; a translucent midpoint tints moving content into a grey band.

**Why:** Fixed search overlays start below the shell's leading inset, so they cannot cover the physical status-bar area themselves. Alpha blending over the changing page underneath caused a transient grey strip during entry.

**How to apply:** Keep normal header transparency unchanged, but use the current theme's opaque search surface whenever search mode is active; don't fade the surface's alpha.

## First-level header glass bounds

Limit the shared app-page Liquid Glass blur band to the first-level header area: physical top inset plus pinned toolbar only. Keep the background gradient in the same area. The large title and page content blur only while physically crossing that band; do not extend the filter into the title's full travel region. Keep modal-sheet edge extents independent.

**Why:** The user wants content outside the first-level header area to remain unblurred, while the large title still blurs as it crosses the header.

**How to apply:** Keep the scroll edge overlay as a visual sibling after moving title content and before fixed toolbar controls. Bound its height to top inset plus toolbar height and preserve the physical viewport as the final clip.

## Persistent top-to-header background fade

Keep a theme-matched background gradient independent of scroll progress: fully opaque at the physical top edge and linearly transparent at the bottom of the first-level header. Draw it over the page/edge treatment but below fixed toolbar controls, and collapse its height with the shell header. Apply the same treatment to the Settings header; keep landscape and modal sheets separate.

**Why:** The safe-area region should remain backed by the app surface even when the scroll-driven Liquid Glass edge is hidden at rest, while the gradient should ease to the content surface at the toolbar boundary.

**How to apply:** Use the currently resolved background color with alpha 1→0 over the safe-area inset plus the first-level toolbar height. Keep this layer separate from the independently tuned blur and tint.

## Large-title glass handoff

Large and compact header-title groups have mutually exclusive visibility: fade the large title fully out before the compact group starts fading in. Start the outgoing fade as the title's descenders enter the pinned first-level toolbar; complete it before compact fade-in. The compact group must be fully opaque by 90% of the second-level title-slot collapse, just before content reaches the first-level header boundary. Apply the same phases to shell-owned titles and scroll-owned Calendar titles with their controls. Search-mode outer fades must not distort the mutually exclusive handoff. Keep title handoff progress independent from glass-edge progress; blur remains clipped to the first-level header only.

**Why:** The user explicitly requires that the large and compact title groups never be visible simultaneously, and that compact controls finish fading in by the point the content reaches the first-level header boundary.

**How to apply:** Derive separate large-out and compact-in progress values from the non-negative owning scroll offset and shared title bottom inset. Use the shared 90% compact-title readiness fraction to calculate both curves from one handoff split, keeping a zero-opacity gap instead of crossfading. Include scroll-owned Calendar title rows and controls, and do not scale these phase values by a search transition. Derive glass-edge progress independently; preserve the first-level-only filter bounds and keep landscape and modal-sheet behavior separate.

## Expanded title clearance

In portrait expanded state, maintain the requested 16pt total gap from the pinned toolbar circle to the large-title capline, and move following content by the same amount. Interpolate this expanded-only clearance to zero through the existing title-collapse progress; do not lengthen the title extent or alter compact geometry.

**Why:** The pinned toolbar's circle extends below its 44pt layout row. Increasing the title extent to create clearance changes scroll collapse travel and can disturb Calendar and search geometry.

**How to apply:** Keep shell-owned titles, Settings titles, scroll-owned Calendar titles, and fixed Day View spacing on the same progress. Add equivalent body spacing only to ordinary expanded content; leave landscape, active search viewport extensions, modal sheets, and compact state unchanged.

## Expanded title-to-content gap

Keep toolbar-to-title clearance separate from the 16pt gap measured from the large-title baseline to the first content edge. Apply it to Settings headings/cards, Notes and Events search rows, Calendar Year/Month/Day content, and DCV headers/tiles. On Notes, Events main, Settings and its subscreens, and Calendar views, use 16pt for authored vertical content gaps except Settings section-heading-to-card and card-to-context-footer gaps (8pt), all pinned category circle-to-title gaps (8pt, with 16pt below the title), and unpinned category-list title-to-subtitle gaps (4pt). The Calendar DOW labels directly adjoin the Month grid and pinned Day week strip; align their baseline with the DOW row bottom so the circle-indicator allowance begins 12pt later, separate from title-baseline spacing. For the separate title/toolbar gap, measure to the visible top of the DOW text within its fixed row, not to the row box. Compact portrait Month alignment moves the whole active content document so the DOW-to-grid spacing stays intact. In landscape, subtract the measured glyph inset from the generic content spacer and move fixed Day DOW chrome by the same amount to keep its visible text 16pt below the toolbar. Grid-only Month modes must fill available space without scroll extent when the grid fits; only an overflowing grid gets scroll range and floating-tab clearance. Keep fixed control dimensions and text line metrics separate. Calendar's custom DOW, week-strip, banner, timeline, and Year row geometry must stay synchronized with these distinct spacing rules. Calendar swipe classification must use the measured global bounds of the pinned week strip, not a fixed local-Y threshold, so the week/day gesture follows the strip through shell insets and orientation changes. When a shell-owned title is downshifted, its hit-test bounds must include that same shift.

**Why:** The user confirmed the toolbar-to-title movement is intentional and specified a 16pt baseline-to-content gap and vertical rhythm, then clarified the Settings and Events category spacing exceptions. Calendar's DOW-baseline-to-indicator allowance is exactly 12pt; the title gap targets visible DOW text rather than its padded row box. Calendar has custom layout geometry, so changing a shared spacing value without updating its masks, row positions, and transition targets can misalign hit regions or morphs. A fixed Month document tail can also leave scroll offset on a grid that already fits.

**How to apply:** Use the same title-baseline metrics everywhere, but keep viewport correction specific to layout: Settings/DCV body spacers pass `topExtension` once because their scroll body is raised; pinned Notes/Events search headers omit it because their outer header already accounts for that position. Measure Calendar DOW text inset with the active text scaler; apply it to expanded and compact visible-edge alignment while preserving the full DOW/grid group, and keep Year-view DOW-to-week-row spacing separate. Fixed Day chrome derives the title gap from shared collapse progress, then keeps week-strip and banner offsets synchronized. For grid-only Month modes, use the remaining sliver viewport to decide whether the grid overflows instead of adding a fixed content tail. Preserve toolbar, title-collapse, compact-title, search, and landscape behavior while normalizing content gaps. Resolve gesture regions from laid-out render bounds.

## Compact toolbar-to-content boundary

In every compact layout, including landscape, keep the first content edge 16pt below the settled leading-toolbar circle. The circle's bottom edge is 50pt below the app's content origin, excluding the status-bar safe area. Apply the rule to the first actual content element, including section headers when they lead a page; do not alter the toolbar size or expanded-title spacing to achieve it.

**Why:** The user specified one compact first-content boundary across Notes, Events, Settings and subscreens, Calendar views, and You. Landscape and portrait have different header slots and viewport raises, so treating a shared spacer value as the final screen coordinate causes inconsistent gaps.

**How to apply:** Preserve the settled toolbar geometry, compensate for the content viewport's orientation-specific raise at the content boundary, and keep compact clearance separate from expanded title gaps and active search placement.

## Compact title-to-toolbar centerline

Compact titles and their controls align to the rendered toolbar control centerline, not the nominal 44pt portrait or 52pt landscape layout-row center. Calendar period-chevron slots must use the same orientation-specific row height so their centers follow the title.

**Why:** The toolbar's rendered center sits below the shorter layout-row center; centering within the row leaves compact titles and chevrons visibly above the toolbar in both orientations. Settings has a separate header layout, so a fix made only in AppShell misses the Settings home and pushed subscreens.

**How to apply:** Use the shared settled-toolbar center offset for every compact-title group, including Settings home and pushed subscreens in portrait and landscape; verify each against the actual toolbar action bounds. Keep the vertical navigation pair centered as a group and do not change expanded headers.

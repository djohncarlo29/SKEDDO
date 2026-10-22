---
name: App header scroll-edge behavior
description: Shared pinned header glass edge and large-title movement across app pages.
---

## Rule
All second-level titles and ordinary scroll content must pass beneath the same first-level `LiquidGlassScrollEdge`; do not substitute title translucency or add per-screen/per-layer blur. At app level, the edge is a visual sibling overlay, never a visibility or clipping boundary. Scroll viewports and page-level ancestors must allow content to paint through the safe-area/header region; only the full-device AppShell viewport clips app content. The edge begins at physical y=0, including the status-bar region, and any local filter clip bounds only the glass effect. Keep modal-sheet clipping behavior separate. In Calendar Month and Year views, the title row and its navigation controls are actual first children of each calendar scroll view, not AppShell header content moved by notifications. AppShell keeps only the first-level toolbar fixed. Other large titles may continue to track their owning scrollable's actual position without a fixed positive maximum. Floor negative elastic overscroll at zero, keep title-collapse and glass-edge progress separate, and keep offsets scoped to the page/view whose scroll controller owns them. Calendar Day timeline scrolling does not own the app header; exclude its notifications. Preserve content-matched landscape surfaces.

## Persistent two-state headers and edge extent
Shell-owned portrait titles use `GlassLargeTitleController.collapseProgress` from the active page's actual `ScrollPosition`; do not add direction-based settling or a second collapse state. The package stops notifying once progress saturates, so the shared adapter must also listen to that same position for full scroll-offset changes used by title travel and `LiquidGlassScrollEdge`. Keep the large-title spacer fixed; never animate it from title progress. Header-aware scroll views must provide at least the measured title-collapse distance when short content would otherwise make that position unreachable; derive only the missing range from the viewport and preceding sliver extents, and add none when ordinary content already provides it. This keeps compact state reachable and position-owned, independent of whether the list has more content. Search-mode collapse remains driven by its own animation. The app-level glass effect begins at physical screen top and ends exactly 12pt below the bottom of the complete first-level header (status-bar inset plus toolbar); this is the effect extent, not a clip on scrolling content. Keep this behavior separate from Calendar Month/Year titles owned by their scroll content.

**Why:** The package's controller provides the desired stable, position-derived title transition, but intentionally stops emitting updates at full collapse. Listening to the same scroll position preserves the shell's title travel and glass-edge updates without creating another collapse state. Short pages otherwise clamp the position before it reaches the title-collapse boundary, so the expanded title can never leave even though the title region is part of the scroll layout.

**How to apply:** Bind the package controller to exactly one active scroll position, and observe that same position for offset-dependent shell visuals even after package progress reaches 1. Keep the regular content spacer independent of title progress. On header-aware sliver views, measure the missing scroll range as `viewportMainAxisExtent + titleCollapseDistance - precedingScrollExtent`; only create a trailing extent when that value is positive. Preserve per-screen scroll scopes, search behavior, Calendar Day timeline exclusions, and the 12pt glass-effect extension.

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

**How to apply:** Keep Month/Year title widgets inside the same vertical scrollable as their calendar content, reserve the same title-slot height when the shell owns the title during transitions, and let scroll views and page-level stacks paint through the edge band. Do not clip shell titles at the safe-area inset. Keep the AppShell's full-device viewport as the final app clipping boundary; do not change modal-sheet clips. Derive any remaining shell-title translation from `pixels - minScrollExtent`, flooring at zero but leaving positive movement unbounded; normalize and clamp that value only when driving the edge effect. Filter notifications to scrollables that actually own the header, and use distinct scopes for calendar views and day submodes. Keep the glass surface color matched to the content background and leave landscape fills unchanged.

## Raised page content ceiling
For targeted app pages, raise available content by extending the shared scroll viewport at the top; do not reduce authored first-item padding or reuse `kFixedVerticalPadding` for this separate viewport adjustment. Explicit empty-state calculations based on an outer layout constraint must include the extension once; calculations based on the expanded scroll viewport already receive it.

**Why:** Raising the ceiling should preserve existing spacing before the first element while increasing the area used to center empty states. Changing that spacing too would shift content twice, and omitting manual height calculations leaves placeholders centered in the old area.

**How to apply:** Use a separate top-extension token at the viewport boundary, align custom positioned or morphing layers to it, and add the same amount to explicitly computed empty-state space.

## Centered content during header collapse
As the second-level title collapses, the usable content area grows upward by up to the title-slot height. Centered placeholders should move down relative to their normally scrolling content by half of that collapse distance, so their screen position follows the center of the expanding area. Ordinary lists keep normal scroll motion. Read only valid scroll metrics, clamp leading overscroll to zero, and apply this only in portrait to true viewport-centered content.

**Why:** The user wants centered content to recenter continuously as the available area expands, without snapping or treating rubber-band movement as a collapsed state.

**How to apply:** Wrap full-area empty states/placeholders in the shared scroll-aware centering widget. Do not apply it to ordinary rows, controls centered inside their own cards, or fixed Calendar day headers/timelines. Keep search and landscape-specific geometry separate.

## Search-mode and Calendar title alignment

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

---
name: App header scroll-edge behavior
description: Shared pinned header glass edge and large-title movement across app pages.
---

## Rule
All second-level titles and ordinary scroll content must pass beneath the same first-level `LiquidGlassScrollEdge`; do not substitute title translucency or add per-screen/per-layer blur. At app level, the edge is a visual sibling overlay, never a visibility or clipping boundary. Scroll viewports and page-level ancestors must allow content to paint through the safe-area/header region; only the full-device AppShell viewport clips app content. The edge begins at physical y=0, including the status-bar region, and any local filter clip bounds only the glass effect. Keep modal-sheet clipping behavior separate. In Calendar Month and Year views, the title row and its navigation controls are actual first children of each calendar scroll view, not AppShell header content moved by notifications. AppShell keeps only the first-level toolbar fixed. Other large titles may continue to track their owning scrollable's actual position without a fixed positive maximum. Floor negative elastic overscroll at zero, clamp glass-edge progress to the title-slot length, and keep offsets scoped to the page/view whose scroll controller owns them. Calendar Day timeline scrolling does not own the app header; exclude its notifications. Preserve content-matched landscape surfaces.

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

## Search-mode and Calendar title alignment

The 16pt content-area raise applies to ordinary page content, not active search headers. Scroll-based search mode viewports must omit that extension so their bar and results retain the prior coordinates. Calendar Year and Month title rows, including their controls, remain in the scroll content but receive the matching positive paint offset; the Day title remains shell-owned and must not be offset again. A fixed Detailed Category search overlay is already outside the raised scroll viewport, so do not add another correction to it.

**Why:** The user requires search bars to keep their pre-raise position and all Calendar second-level headers to align with the shared header slot. Applying the page raise indiscriminately lifts search bars and Calendar Year/Month titles.

**How to apply:** Whenever the content top extension changes, audit active search viewports separately from normal page scroll views, and compare Year, Month, and Day title ownership before compensating.

In portrait, the normal AppShell header surface is transparent so page content can scroll beneath it. During search, switch directly to the opaque search surface instead of interpolating alpha from transparent; a translucent midpoint tints moving content into a grey band.

**Why:** Fixed search overlays start below the shell's leading inset, so they cannot cover the physical status-bar area themselves. Alpha blending over the changing page underneath caused a transient grey strip during entry.

**How to apply:** Keep normal header transparency unchanged, but use the current theme's opaque search surface whenever search mode is active; don't fade the surface's alpha.

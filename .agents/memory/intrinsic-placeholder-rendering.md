---
name: Intrinsic placeholder rendering
description: Shared behavior for one-line placeholders that overflow or rubberband at text-field edges.
---

One-line placeholders are rendered at their intrinsic width inside the field viewport. They must use clipping rather than ellipsis, show the matching edge fade when clipped, and translate with the field's horizontal rubberband offset. In AppSearchBar, keep the placeholder inside NativeTextInput's child subtree and transform it together with the field; use HorizontalEdgeFade only to measure placeholder overflow. Keep the alpha-mask subtree mounted with an identity mask when no edge is fading. Multiline placeholders are top-aligned, normally wrapped, and participate in the vertical rubberband/fade wrapper.

**Why:** Native placeholder ellipsizing hides the actual product copy and does not participate in the same edge treatment or rubberband motion as normal text. A separately positioned search placeholder can remain visually detached from the field's real gesture even when its offset is manually mirrored. Removing the alpha mask on release reparents the animated field content and snaps it; idle zero-offset metrics can also erase a fitting-text fallback while the pointer is still down.

**How to apply:** Use NativeTextInput's placeholder for AppSearchBar so the search placeholder shares the exact transformed subtree with entered text; keep it covered by the same alpha mask and use its intrinsic width to calculate overflow fades. Keep separately rendered placeholders for other fields only when their widget needs that arrangement. For fitting content, keep the fallback's synthetic offset authoritative through the active gesture. Keep the alpha mask mounted and return an opaque identity shader when fades are off.
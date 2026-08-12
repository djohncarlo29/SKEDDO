---
name: Events search overlay rendering
description: Search result rendering and scope semantics for Events and Detailed Category Views.
---

## Rule

The Events tab searches the full event corpus. A Detailed Category View uses its category membership only as ranking context: matching events receive a +0.2 score boost, while sufficiently relevant out-of-scope events remain visible.

Both full-screen search overlays must render the shared search result widgets rather than a hard-coded empty-state placeholder. The DCV overlay uses the primary/overflow split; the Events overlay uses the flat merged result list.

**Why:** The search service can correctly produce ranked results even when an overlay visually showed “no results,” and hiding out-of-scope results violates the global-search behavior.

**How to apply:** When changing search UI or overlay layout, preserve the shared result widgets and pass the active DCV scope into the search query; do not filter the result corpus to the active category. If the shared result-widget API changes, update Events, Calendar, and Notes call sites together.
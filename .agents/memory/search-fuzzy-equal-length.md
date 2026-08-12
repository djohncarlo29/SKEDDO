---
name: Search fuzzy equal-length guard
description: Prevent equal-length token comparisons from treating the target token as its own prefix match.
---

Equal-length query and target tokens must keep the query as the shorter-side
candidate for prefix logic; otherwise selecting the target on a tie makes every
same-length word appear to match itself and produces false fuzzy results.

**Why:** An unrelated five-letter query could receive a near-perfect fuzzy score
because the comparison selected the event token as both `shorter` and `longer`.

**How to apply:** When changing token typo scoring, handle equal lengths
explicitly and keep exact equality as its own early-return case.
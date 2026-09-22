---
name: Smart Category semantic threshold
description: Relevance safeguards for Smart Category embedding matches and lexical rule normalization.
---

Smart Category event embeddings include title content plus date/time context. A low cosine threshold can therefore classify nearly every scheduled event as relevant to a short topic rule, while unscheduled events appear absent because their embeddings are often missing or weaker. Keep the semantic threshold conservative, and retain keyword fallback with simple singular/plural normalization.

**Why:** A rule such as “Birthdays” was observed returning all scheduled events instead of only semantically related celebrations.

**How to apply:** When changing event embedding text or matcher thresholds, add a regression test with a semantically relevant event and an unrelated scheduled event. Pass the Smart Category name at every matching call site so category embeddings and displayed counts use the same path.
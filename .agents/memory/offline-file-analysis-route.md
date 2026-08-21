---
name: Offline file analysis route
description: The Notes attachment flow uses the Phase 1/Phase 2 offline coordinator as its only event-analysis path.
---

The Notes attachment experience is offline-only for file/event analysis. It should route text, documents, PDFs, images, and screenshots through local extraction, native OCR where needed, and the deterministic event analyzer. Gemini proxy/direct calls are not a fallback for this flow; Gemini remains separate for unrelated language features. OCR/document blocks may split dates and times across lines, so the analyzer must also inspect reconstructed plainText and deduplicate candidates.

**Why:** The product requirement is predictable local analysis and no dependency on network availability or API configuration for attachments.

**How to apply:** When changing attachment analysis, preserve the coordinator as the source of truth for every attachment format—not only images/PDFs—and report unsupported formats or OCR limitations explicitly rather than silently switching to an online service.
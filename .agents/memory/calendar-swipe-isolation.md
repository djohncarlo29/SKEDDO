---
name: Calendar Day View dual-axis swipe isolation
description: Keep week-strip and timeline swipe state independent in Day View.
---

Use separate horizontal drag progress for the week strip and the timeline. Synchronize the shared header from the strip's callback rather than sharing one drag variable.

**Why:** The strip and timeline are independent gesture surfaces; shared progress lets one drag overwrite or disrupt the other.

**How to apply:** Keep their gesture state separate and publish strip movement to the header through the existing notifier/callback path.

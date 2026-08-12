---
name: Cupertino selection styling across Shorebird Flutter versions
description: Mobile CupertinoTextField selection tint must use inherited selection styling for Shorebird compatibility.
---

On the Shorebird Flutter toolchain used by this app, `CupertinoTextField` does not expose a `selectionColor:` constructor parameter. Use `DefaultSelectionStyle.selectionColor` around the field for the highlight, and `CupertinoTheme.primaryColor` for the selection handles; set `cursorColor` directly for the caret.

**Why:** A local analyzer/toolchain can appear to accept newer Cupertino APIs while Shorebird's pinned Flutter compiler rejects them during patch generation.

**How to apply:** When adding mobile text-selection tint, keep the platform-independent wrapper API if needed for web CSS, but do not pass `selectionColor` into the mobile `CupertinoTextField` constructor.
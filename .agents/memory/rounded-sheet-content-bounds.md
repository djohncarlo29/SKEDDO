---
name: Rounded sheet content bounds
description: The shared Cupertino sheet route must preserve full-height child layout.
---

The shared rounded Cupertino sheet route must give its page child the full route height. The route's 8% translation and viewport clipping define the visible sheet area; do not constrain the child itself to 92% height.

**Why:** modal contents can depend on full-route constraints, and constraining the shared child clips or removes content across every sheet at once.

**How to apply:** keep any themed surface layer behind the full-height MediaQuery/CupertinoUserInterfaceLevel/page-builder chain. Adjust modal scroll clearance locally instead of shrinking the shared route child.
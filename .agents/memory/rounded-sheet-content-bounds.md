---
name: Rounded sheet content bounds
description: The shared Cupertino sheet route must preserve full-height child layout.
---

The shared rounded Cupertino sheet route must keep its modal surface full-height while sizing the translated page child to the viewport below the top safe-area inset plus the fixed 10px gap. Parent sheets and nested subsheets use the same physical top edge; do not let the scroll viewport consume the hidden translated area.

**Why:** a full-height page is translated down by the physical safe-area gap, so its scrollable bottom would remain clipped after reaching max scroll offset unless that hidden top area is reserved outside the page viewport.

**How to apply:** keep the themed modal surface behind the full-height MediaQuery/CupertinoUserInterfaceLevel chain, then use a LayoutBuilder/SizedBox viewport whose height subtracts `(topSafeArea + 10px)` from the route height. Keep modal scroll padding separate from the route geometry.
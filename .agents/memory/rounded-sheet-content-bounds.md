---
name: Rounded sheet content bounds
description: The shared Cupertino sheet route must preserve full-height child layout.
---

The shared rounded Cupertino sheet route must keep its modal surface full-height while giving the translated page child the visible 92% route height. The route's 8% translation then places that page exactly inside the viewport; do not let the scroll viewport consume the hidden translated area.

**Why:** a full-height page is translated 8% below the viewport, so its scrollable bottom remains clipped even after reaching max scroll offset; the reference sheet geometry reserves the hidden translation area outside the page viewport.

**How to apply:** keep the themed modal surface behind the full-height MediaQuery/CupertinoUserInterfaceLevel chain, then use a LayoutBuilder/SizedBox page viewport at `constraints.maxHeight * (1 - 0.08)`. Keep modal scroll padding separate from the route geometry.
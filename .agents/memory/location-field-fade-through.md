---
name: Location field fade-through
description: Icon transition behavior for the category modal's location fields.
---

Starting Location and Destination use a fixed trailing action area. When the
field is empty, it shows the 30px circular map-pin action; when text exists, it
shows the category-style clear button. The two unrelated icons cross-dissolve
with brief overlap rather than morphing.

**Why:** The user specifically wants a Material-style fade-through/cross-dissolve
and no layout jump when typing or clearing a location.

**How to apply:** Drive the swap from the controller's current text so typing,
backspacing, manual deletion, and the clear button all use the same transition.
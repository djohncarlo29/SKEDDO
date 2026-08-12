---
name: Dart 3.9 collection control-flow nesting
description: Dart 3.9 (Shorebird Flutter 3.44.9) rejects 3-level if→for→if collection elements; restructure to for→if or for(cond &&...) patterns.
---

## Rule
Never write `if (cond) for (...) if (...) expr` inside a Dart collection literal — it compiles on Dart 3.8 but the Dart 3.9 kernel compiler rejects it with a spurious "Expected ';' after this" parse error pointing at the CLOSING paren of the outer container widget.

## Why
Dart 3.9 (Shorebird's bundled Flutter 3.44.9 / c2515c46c7) tightened parsing of nested collection control-flow elements. The `if → for → if → expr` chain (3 levels deep) causes the parser to misidentify paren nesting and exit the collection literal early, making the enclosing widget's closing `)` look like a bare expression statement without `;`.

Dart 3.8 (local Flutter 3.32.0) accepted the same code, so tests passed locally but the Shorebird build failed.

## How to apply
Whenever you have `if (nullGuard) for (...) if (innerCond) expr`, replace the outer `if` by folding its condition into the `for` loop's continuation condition:

```dart
// BAD — Dart 3.9 parse error
if (draggingCat != null)
  for (int i = 0; i < items.length; i++)
    if (items[i].category == draggingCat)
      _buildSlot(items[i], i, context),

// GOOD — 2-level for→if, works on all Dart versions
for (int i = 0; draggingCat != null && i < items.length; i++)
  if (items[i].category == draggingCat)
    _buildSlot(items[i], i, context),
```

## Also noted
The affected file (`events_tab.dart`) also had a spurious extra `),` in the enclosing widget's closing sequence that Dart 3.8 silently absorbed while parsing the malformed collection; it disappeared when the nesting was fixed.

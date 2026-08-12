---
name: AnimatedBuilder child caching pitfall
description: Why AnimatedBuilder.child must not cache widgets that read setState-driven state
---

## Rule
Never use `AnimatedBuilder(child: ...)` for widget subtrees that read state variables changed by `setState`. The `child:` parameter is built once and reused — it captures a snapshot of state at build time and won't update when `setState` triggers a rebuild.

**Why:** In SKEDDO, the header Column was passed as `AnimatedBuilder.child`. When `_isDCV`/`_dcvCategory` changed via `setState`, the cached Column still showed old state (hamburger, old title) for several frames, causing a visible flicker. The `builder: (context, child) { return ... child ... }` pattern makes `child` a fixed snapshot, not a live reference.

**How to apply:** Move the Column inline into the `builder` callback:
```dart
AnimatedBuilder(
  animation: someAnim,
  builder: (context, _) {   // ← ignore the child param
    return Container(
      child: Column(         // ← inline, reads live state
        children: [ ... _isDCV ... ],
      ),
    );
  },
  // No child: parameter
)
```

Only use `AnimatedBuilder.child` for truly static subtrees (no mutable state, no `setState`-driven fields).

---
name: Intrinsic placeholder rendering
description: Shared behavior for one-line placeholders that overflow or rubberband at text-field edges.
---

Keep a one-line placeholder in the fade wrapper's Flutter overlay and leave the native field's placeholder empty. Fitting-text movement has two sources: the wrapper fallback translates the whole child subtree, while native editable scrolling moves only the text viewport and reports its offset. Apply the overlay's own scroll-offset translation for native movement; skip it only while the wrapper fallback is moving the whole subtree. Keep the wrapper Listener translucent so the ignored placeholder hit target remains in the pointer path. On web, the DOM input's synthetic metrics activate the wrapper fallback.

**Why:** The native field moves its caret and text within its own viewport, but the Flutter placeholder is a sibling outside that viewport. The fade can react to native scroll metrics even while the sibling remains stationary. Treating all fitting-text movement as wrapper-owned suppresses the translation needed on the native path.

**How to apply:** Test both paths independently: drag the wrapper fallback, then simulate a nonzero editable scroll offset and verify the overlay follows it and fades. A test that only drags the visible hint can pass via the wrapper fallback and miss a broken native-scroll path.
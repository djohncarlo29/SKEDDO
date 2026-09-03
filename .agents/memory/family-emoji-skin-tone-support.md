---
name: Family emoji skin-tone support
description: Unicode family ZWJ sequences do not have standardized skin-tone variants.
---

The gendered family glyphs such as man-woman-boy and man-woman-girl are single
default-tone ZWJ sequences. Adding `🏻` to each person is not an RGI family
variant and can render as oversized or partially decomposed people on Android.

**Why:** Unicode defines skin-tone modifiers for individual people and some
multi-person interactions, but not these family sequences.

**How to apply:** Keep the original family string when exact native glyph
appearance is required. A light-skinned version requires custom artwork or a
custom renderer rather than another Unicode string.
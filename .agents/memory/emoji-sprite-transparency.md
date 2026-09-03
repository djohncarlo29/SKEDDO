---
name: Screen-captured emoji sprite transparency
description: Safe transparency handling for emoji artwork extracted from screenshots.
---

Screen-captured emoji sprites must not be isolated with an aggressive chroma-key
or flood-fill alone: dark screenshot backgrounds can be close to dark hair,
and openings in hair can cause the mask to erase real interior artwork. Build
the outer transparency conservatively, preserve interior hair/body regions,
and inspect the result against a contrasting light background before shipping.

**Why:** A dark source screenshot hid transparent holes that became obvious when
the sprites were rendered on the app's light picker surface.

**How to apply:** For future screenshot-derived sprites, validate both the
transparent asset and a white-background composite before replacing the bundled
asset.
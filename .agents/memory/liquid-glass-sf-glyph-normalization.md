---
name: Liquid Glass SF glyph normalization
description: Optical sizing and clipping rules for custom SF Symbols inside LiquidGlassTabBar.
---

LiquidGlassTabBar custom glyphs pass through a shared slot and FittedBox. Return every preview SF glyph in the same reference-sized slot, render the font glyph unconstrained with clipping disabled, and apply only per-symbol optical corrections inside that slot. Keep the chosen reference glyph at 1×; reduce or enlarge the other symbols relative to it.

**Why:** SF Symbols are font glyphs with different ink bounds, and independent fitting makes a larger authored glyph appear smaller or crop its outline. A transform applied without an unconstrained child can also clip the glyph at the intermediate wrapper.

**How to apply:** Preserve each requested base font size and OS TextScaler input, use a common slot matching the largest authored base size, and calibrate optical scale from the reference glyph's visible height rather than shrinking the reference to match the others.

For the adaptive settings preview, keep the `8pt` top/bottom edge clearance and `24pt`
adjacent-icon gap fixed; only the shared glyph slot follows the OS text scaler. Derive
the pill's width and height from the scaled slot plus those fixed clearances, while
preserving the standard pill size whenever it already fits.

**Why:** Text scaling should enlarge the icons without creating disproportionate empty
space around them.

**How to apply:** Use fixed layout constants for the preview clearances and apply the
text scaler only to the shared icon slot before calculating the minimum pill dimensions.
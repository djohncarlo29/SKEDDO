---
name: Horizontal fade surface matching
description: Surface-color rule for horizontal text overflow fades.
---

Surface-color gradients must end at the exact resolved color of the surface directly behind the text; generic app surfaces are not interchangeable with modal card surfaces, particularly in dark mode. When the desired effect is alpha-only text fading, use an alpha mask instead of a surface-colored overlay. Flutter `ShaderMask` does not affect a web `HtmlElementView`, so its native input needs a matching CSS mask.

**Why:** a mismatched opaque gradient reads as a visible overlay instead of blending into the field or card, while a colored overlay changes the text rather than only reducing its opacity. Platform views are composited outside Flutter's widget paint tree.

**How to apply:** choose the fade mode by design intent. For a surface blend, resolve the color at the row's build boundary from the same semantic surface used by the enclosing background. For alpha-only fades, mask Flutter content with alpha and apply an equivalent CSS alpha mask to DOM-rendered input text.
#include <flutter/runtime_effect.glsl>

uniform vec2 u_size;
uniform float u_progress;
uniform float u_max_sigma;
uniform float u_max_surface_opacity;
uniform vec4 u_surface_color;
uniform float u_pixel_ratio;
uniform float u_fade_extent;
uniform float u_blur_extent;
uniform float u_is_bottom;
uniform sampler2D u_texture_input;

out vec4 frag_color;

float kernelWeight(int offset) {
  if (offset == 0) return 6.0;
  if (abs(offset) == 1) return 4.0;
  return 1.0;
}

void main() {
  vec2 uv = FlutterFragCoord().xy / u_size;
#ifdef IMPELLER_TARGET_OPENGLES
  uv.y = 1.0 - uv.y;
#endif

  float y = uv.y * u_size.y;
  float fadeExtent = max(u_fade_extent * u_pixel_ratio, 0.001);
  float blurExtent = max(u_blur_extent * u_pixel_ratio, 0.001);
  float fadeStrength;
  float blurStrength;
  if (u_is_bottom < 0.5) {
    fadeStrength = 1.0 - smoothstep(0.0, fadeExtent, y);
    blurStrength = 1.0 - smoothstep(0.0, blurExtent, y);
  } else {
    fadeStrength = smoothstep(0.0, fadeExtent, y);
    blurStrength = smoothstep(0.0, blurExtent, y);
  }

  float progress = clamp(u_progress, 0.0, 1.0);
  float sigmaPixels = u_max_sigma * u_pixel_ratio * progress * blurStrength;
  vec4 filtered = texture(u_texture_input, uv);

  if (sigmaPixels > 0.01) {
    vec2 stepUv = (sigmaPixels * 0.55) / u_size;
    filtered = vec4(0.0);
    float totalWeight = 0.0;
    for (int yOffset = -2; yOffset <= 2; yOffset++) {
      for (int xOffset = -2; xOffset <= 2; xOffset++) {
        float weight = kernelWeight(xOffset) * kernelWeight(yOffset);
        vec2 sampleUv = clamp(
          uv + vec2(float(xOffset), float(yOffset)) * stepUv,
          vec2(0.0),
          vec2(1.0)
        );
        filtered += texture(u_texture_input, sampleUv) * weight;
        totalWeight += weight;
      }
    }
    filtered /= totalWeight;
  }

  float fadeOpacity = clamp(
    u_max_surface_opacity * progress * fadeStrength * u_surface_color.a,
    0.0,
    1.0
  );
  vec4 surface = vec4(
    u_surface_color.rgb * u_surface_color.a,
    u_surface_color.a
  );
  frag_color = mix(filtered, surface, fadeOpacity);
}
#include <flutter/runtime_effect.glsl>

uniform vec2 u_size;
uniform float u_progress;
uniform float u_max_sigma;
uniform float u_max_surface_opacity;
uniform vec4 u_surface_color;
uniform float u_pixel_ratio;
uniform float u_header_height;
uniform float u_edge_extent;
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
  float edgeExtent = max(u_edge_extent * u_pixel_ratio, 0.001);
  float fieldStrength;
  if (u_is_bottom < 0.5) {
    float headerHeight = u_header_height * u_pixel_ratio;
    fieldStrength =
        1.0 - smoothstep(headerHeight, headerHeight + edgeExtent, y);
  } else {
    fieldStrength = smoothstep(0.0, edgeExtent, y);
  }

  float strength = clamp(u_progress, 0.0, 1.0) * fieldStrength;
  float sigmaPixels = u_max_sigma * u_pixel_ratio * strength;
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

  float tintStrength = clamp(
    u_max_surface_opacity * strength * u_surface_color.a,
    0.0,
    1.0
  );
  float alpha = max(filtered.a, 0.0001);
  vec3 unpremultiplied = filtered.rgb / alpha;
  vec3 material = mix(unpremultiplied, u_surface_color.rgb, tintStrength);
  frag_color = vec4(material * filtered.a, filtered.a);
}
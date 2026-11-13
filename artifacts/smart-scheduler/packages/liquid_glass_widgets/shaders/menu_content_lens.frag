#version 320 es
#include <flutter/runtime_effect.glsl>

uniform vec2 u_size;
uniform sampler2D u_texture;
uniform float u_morph_intensity;
uniform float u_thickness_fraction;
uniform float u_refractive_index;
uniform float u_chromatic_aberration;
uniform float u_corner_radius_fraction;

out vec4 frag_color;

float rounded_rect_distance(vec2 point, vec2 half_size, float radius) {
  vec2 q = abs(point) - (half_size - vec2(radius));
  return length(max(q, vec2(0.0))) +
      min(max(q.x, q.y), 0.0) - radius;
}

vec2 rounded_rect_normal(vec2 point, vec2 half_size, float radius) {
  vec2 q = abs(point) - (half_size - vec2(radius));
  vec2 outside = max(q, vec2(0.0));
  if (dot(outside, outside) > 0.0001) {
    return normalize(outside) * sign(point);
  }
  if (q.x > q.y) {
    return vec2(sign(point.x), 0.0);
  }
  return vec2(0.0, sign(point.y));
}

void main() {
  vec2 fragment_position = FlutterFragCoord().xy;
#ifdef IMPELLER_TARGET_OPENGLES
  fragment_position.y = u_size.y - fragment_position.y;
#endif

  vec2 uv = clamp(fragment_position / u_size, vec2(0.001), vec2(0.999));
  vec2 half_size = u_size * 0.5;
  float short_side = min(u_size.x, u_size.y);
  float radius = clamp(u_corner_radius_fraction, 0.0, 0.5) * short_side;
  float signed_distance =
      rounded_rect_distance(fragment_position - half_size, half_size, radius);
  float distance_inside = max(-signed_distance, 0.0);
  float band_width = max(u_thickness_fraction * short_side * 1.15, 1.0);
  float edge_contact =
      1.0 - smoothstep(0.0, band_width, distance_inside);
  float contact = clamp(u_morph_intensity * edge_contact, 0.0, 1.0);

  vec4 original = texture(u_texture, uv);
  if (contact <= 0.001) {
    frag_color = original;
    return;
  }

  vec2 normal = rounded_rect_normal(
      fragment_position - half_size, half_size, radius);
  float lens_depth = u_thickness_fraction * short_side;
  float displacement =
      lens_depth * max(u_refractive_index - 1.0, 0.0) * 1.8;
  vec2 refract_offset = normal * displacement * contact / u_size;
  vec2 colour_offset = refract_offset * u_chromatic_aberration;

  vec2 green_uv = clamp(uv + refract_offset, vec2(0.001), vec2(0.999));
  vec2 red_uv = clamp(
      uv + refract_offset + colour_offset, vec2(0.001), vec2(0.999));
  vec2 blue_uv = clamp(
      uv + refract_offset - colour_offset, vec2(0.001), vec2(0.999));
  vec4 green_sample = texture(u_texture, green_uv);
  vec4 red_sample = texture(u_texture, red_uv);
  vec4 blue_sample = texture(u_texture, blue_uv);
  vec4 refracted = vec4(
      red_sample.r, green_sample.g, blue_sample.b, green_sample.a);
  // Filter the source image itself. Mixing the original image back in here
  // creates a second, sharp copy of every glyph near the glass edge.
  frag_color = refracted;
}

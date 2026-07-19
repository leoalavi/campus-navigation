#version 460 core
#include <flutter/runtime_effect.glsl>

// Engine auto-sets: first vec2 = input size (physical px); first sampler2D = backdrop.
uniform vec2 uSize;
uniform float uRadius;      // corner radius (physical px)
uniform float uRimPx;       // rim width (physical px)
uniform float uIor;
uniform float uAberrationPx; // chromatic aberration (physical px)
uniform float uBlurPx;       // max rim blur (physical px)
uniform vec4 uTint;          // premultiplied tint: rgb*a, a
uniform sampler2D uTexture;

out vec4 fragColor;

float sdRoundedBox(vec2 p, vec2 b, float r) {
  vec2 q = abs(p) - b + r;
  return min(max(q.x, q.y), 0.0) + length(max(q, 0.0)) - r;
}

vec3 sampleBg(vec2 uv) {
  vec2 t = uv;
#ifdef IMPELLER_TARGET_OPENGLES
  t.y = 1.0 - t.y;               // un-flip only on GLES
#endif
  t = clamp(t, vec2(0.0), vec2(1.0)); // never sample outside the backdrop
  return texture(uTexture, t).rgb;
}

void main() {
  vec2 fragCoord = FlutterFragCoord().xy;
  vec2 uv = fragCoord / uSize;
  vec2 centered = fragCoord - uSize * 0.5;

  // Clamp radius so stadium/circle idioms (Dart passes ~999) don't exceed the
  // half-extent (otherwise the whole interior reads as "outside" -> transparent).
  float radius = min(uRadius, min(uSize.x, uSize.y) * 0.5);
  float d = sdRoundedBox(centered, uSize * 0.5, radius);
  if (d > 0.0) {
    fragColor = vec4(sampleBg(uv), 1.0);
    return;
  }

  float edge = clamp(1.0 + d / max(uRimPx, 1.0), 0.0, 1.0);
  float lens = 1.0 - sqrt(1.0 - edge * edge);

  vec2 dir = normalize(centered + vec2(1e-4));
  float strength = lens * (uIor - 1.0);
  vec2 offset = dir * strength * (uRimPx / uSize); // px -> UV

  // Aberration in physical px -> UV.
  vec2 caUv = (uAberrationPx * edge) * dir / uSize;
  float r = sampleBg(uv - offset - caUv).r;
  float g = sampleBg(uv - offset).g;
  float b = sampleBg(uv - offset + caUv).b;
  vec3 refracted = vec3(r, g, b);

  // Variable blur in physical px -> UV (clear centre, soft rim).
  vec2 bUv = (uBlurPx * edge) / uSize;
  vec3 acc = refracted;
  acc += sampleBg(uv - offset + vec2(bUv.x, 0.0));
  acc += sampleBg(uv - offset - vec2(bUv.x, 0.0));
  acc += sampleBg(uv - offset + vec2(0.0, bUv.y));
  acc += sampleBg(uv - offset - vec2(0.0, bUv.y));
  refracted = acc / 5.0;

  vec3 tinted = refracted * (1.0 - uTint.a) + uTint.rgb;
  fragColor = vec4(tinted, 1.0);
}

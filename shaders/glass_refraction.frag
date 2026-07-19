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
uniform float uFresnel;      // rim reflection / edge brightening strength (0..1)
uniform float uGlare;        // directional glare highlight strength (0..1)
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

  // Edge coefficient: 0 at centre, ->1 at the rim.
  float edge = clamp(1.0 + d / max(uRimPx, 1.0), 0.0, 1.0);
  // Squircle-ish lens curve: flat centre, steep rim.
  float lens = 1.0 - sqrt(1.0 - edge * edge);

  // Outward normal of the rounded shape (points from centre toward the rim).
  vec2 dir = normalize(centered + vec2(1e-4));
  float strength = lens * (uIor - 1.0);
  vec2 offset = dir * strength * (uRimPx / uSize); // px -> UV

  // Chromatic dispersion: stronger at the rim, split along the refraction axis.
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

  // Body tint.
  vec3 color = refracted * (1.0 - uTint.a) + uTint.rgb;

  // ── Fresnel rim reflection ────────────────────────────────────────────────
  // Grazing angles (the rim) reflect the surroundings and brighten. Approximate
  // the reflection by sampling the opposite side of the lens and mixing it in,
  // weighted by a Fresnel-style rim falloff.
  float fres = pow(edge, 4.0) * uFresnel;
  vec3 rimReflect = sampleBg(uv + offset * 1.5);
  color = mix(color, rimReflect * 1.12 + vec3(0.05), fres);

  // Crisp specular edge line right at the boundary (the glass bevel catching light).
  float edgeLine = smoothstep(0.86, 1.0, edge);
  color += vec3(edgeLine) * (0.30 * uFresnel);

  // ── Directional glare highlight ───────────────────────────────────────────
  // A soft bright streak where the rim faces a fixed top-leading light.
  vec2 lightDir = normalize(vec2(-0.6, -0.8));
  float ndl = max(dot(dir, lightDir), 0.0);
  float glare = pow(ndl, 8.0) * (0.35 + 0.65 * edge) * uGlare;
  color += vec3(glare);

  fragColor = vec4(clamp(color, 0.0, 1.0), 1.0);
}

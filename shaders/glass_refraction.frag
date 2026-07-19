#version 460 core
#include <flutter/runtime_effect.glsl>

// Engine auto-sets: first vec2 = input size (physical px); first sampler2D = backdrop.
uniform vec2 uSize;
uniform float uRadius;           // corner radius (physical px)
uniform float uRimPx;            // rim/bevel thickness (physical px)
uniform float uIor;              // refractive index
uniform float uAberrationPx;     // chromatic aberration (physical px)
uniform float uBlurPx;           // max rim blur (physical px)
uniform vec4 uTint;              // premultiplied tint: rgb*a, a
uniform float uFresnel;          // rim reflection / edge brightening (0..1)
uniform float uGlare;            // directional glare highlight (0..1)
uniform float uRefractIntensity; // physical refraction march strength
uniform float uTime;             // seconds, monotonic — drives the living highlights
uniform vec2 uTilt;              // device tilt (gravity), ~[-1,1] — glare tracks it
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
  vec2 centered = fragCoord - uSize * 0.5;

  float radius = min(uRadius, min(uSize.x, uSize.y) * 0.5);
  float thickness = max(uRimPx, 1.0);
  vec2 halfSize = uSize * 0.5;

  float sd = sdRoundedBox(centered, halfSize, radius);
  if (sd > 0.0) {                       // outside the shape: pass background through
    fragColor = vec4(sampleBg(fragCoord / uSize), 1.0);
    return;
  }

  // 2D edge normal via SDF finite-difference gradient (|grad| ~ 1).
  float sdX = sdRoundedBox(centered + vec2(1.0, 0.0), halfSize, radius);
  float sdY = sdRoundedBox(centered + vec2(0.0, 1.0), halfSize, radius);
  vec2 grad = vec2(sdX - sd, sdY - sd);

  // Model the glass as a real 3D bevel: flat centre, curved rim. edge=1 at the
  // rim, 0 in the centre; the z-bulge makes a genuine surface normal.
  float edge = clamp((thickness + sd) / thickness, 0.0, 1.0);
  float nSin = sqrt(max(1.0 - edge * edge, 0.0));
  vec3 normal = normalize(vec3(grad * edge, nSin));

  // Physically-based refraction (Snell's law), marched by the glass depth.
  vec3 rvec = refract(vec3(0.0, 0.0, -1.0), normal, 1.0 / uIor);
  float h = (sd < -thickness) ? thickness
                              : sqrt(max(sd * (-2.0 * thickness - sd), 0.0));
  // Floor -rvec.z and cap the march so grazing-rim pixels don't blow up into a
  // smeared clamp band.
  float refractLen = (h + 8.0 * thickness) / max(-rvec.z, 0.35);
  refractLen = min(refractLen, thickness * 6.0);
  vec2 dispPx = rvec.xy * refractLen * uRefractIntensity;
  vec2 baseUv = (fragCoord + dispPx) / uSize;

  // Chromatic dispersion along the refraction axis, stronger at the rim.
  vec2 caDir = normalize(rvec.xy + vec2(1e-5));
  vec2 caUv = (uAberrationPx * edge) * caDir / uSize;
  float r = sampleBg(baseUv - caUv).r;
  float g = sampleBg(baseUv).g;
  float b = sampleBg(baseUv + caUv).b;
  vec3 refracted = vec3(r, g, b);

  // Variable blur (mostly-clear centre, soft rim).
  vec2 bUv = (uBlurPx * (0.35 + 0.65 * edge)) / uSize;
  vec3 acc = refracted;
  acc += sampleBg(baseUv + vec2(bUv.x, 0.0));
  acc += sampleBg(baseUv - vec2(bUv.x, 0.0));
  acc += sampleBg(baseUv + vec2(0.0, bUv.y));
  acc += sampleBg(baseUv - vec2(0.0, bUv.y));
  refracted = acc / 5.0;

  // Vibrancy: boost backdrop saturation (the `saturate(180%)` of CSS glass).
  // With a lighter body tint this is what keeps thin glass looking rich —
  // especially in light mode, where a milky wash otherwise flattens it.
  float lum = dot(refracted, vec3(0.299, 0.587, 0.114));
  refracted = clamp(mix(vec3(lum), refracted, 1.55), 0.0, 1.0);

  // Body tint (premultiplied over).
  vec3 color = refracted * (1.0 - uTint.a) + uTint.rgb;

  // Fresnel rim reflection: grazing rim brightens + mirrors the surroundings.
  float fres = pow(edge, 4.0) * uFresnel;
  vec3 rimReflect = sampleBg((fragCoord - dispPx) / uSize);
  color = mix(color, rimReflect * 1.12 + vec3(0.05), fres);

  // Crisp specular edge line at the boundary.
  float edgeLine = smoothstep(0.86, 1.0, edge);
  color += vec3(edgeLine) * (0.32 * uFresnel);

  // ── Living highlights (time-driven) ───────────────────────────────────────
  float axis = (fragCoord.x + fragCoord.y) / (uSize.x + uSize.y); // 0..1 diagonal

  // Directional glare: tracks device tilt (like light on real glass), with a
  // gentle time sway layered in. Concentrated at the rim.
  vec2 gdir = normalize(grad + vec2(1e-5));
  vec2 lightDir = normalize(vec2(
    -0.45 + 0.28 * sin(uTime * 0.6) + uTilt.x * 1.6,
    -0.85 + uTilt.y * 1.6
  ));
  float ndl = max(dot(gdir, lightDir), 0.0);
  float glare = pow(ndl, 7.0) * (0.35 + 0.65 * edge) * uGlare;
  color += vec3(glare);

  // Counter-shade: the rim facing AWAY from the light darkens (real glass has
  // a bright band and a shaded band). Crucially, this is what keeps the glass
  // legible as glass over white/light backdrops where additive highlights
  // vanish into the page.
  float shade = pow(max(dot(gdir, -lightDir), 0.0), 5.0) * edge;
  color *= 1.0 - shade * 0.22;

  // Motion highlight: a broad soft illumination spot that physically slides
  // across the surface as the device tilts (Apple's motion-tracked layer).
  // Paired with a mirrored counter-shade so the travel is visible on any
  // backdrop, light or dark.
  vec2 hlPos = uSize * vec2(0.5 - uTilt.x * 0.6, 0.35 - uTilt.y * 0.8);
  float spotR = 0.9 * min(uSize.x, uSize.y);
  vec2 hp = fragCoord - hlPos;
  float spot = exp(-dot(hp, hp) / (spotR * spotR));
  color += vec3(spot) * (0.10 + 0.16 * edge) * uGlare;
  vec2 sp = fragCoord - (uSize - hlPos); // mirrored across the centre
  float counter = exp(-dot(sp, sp) / (spotR * spotR));
  color *= 1.0 - counter * 0.10 * uGlare;

  // A soft specular band that travels diagonally across the glass (light sweep).
  float sweepPos = fract(uTime * 0.08);
  float band = exp(-pow((axis - sweepPos) * 7.0, 2.0));
  color += vec3(band) * (0.14 * (0.45 + 0.55 * edge));

  // Pearlescent iridescence shifting along the rim over time.
  vec3 irid = 0.5 + 0.5 * cos(uTime * 0.7 + axis * 6.2831 + vec3(0.0, 2.094, 4.188));
  color += irid * (edge * edge) * (0.07 * uFresnel);

  // Dither: ±0.5/255 hash noise kills gradient banding on the soft highlights.
  float dither =
      fract(sin(dot(fragCoord, vec2(12.9898, 78.233))) * 43758.5453) - 0.5;
  color += dither / 255.0;

  fragColor = vec4(clamp(color, 0.0, 1.0), 1.0);
}

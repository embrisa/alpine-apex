---
id: "AA-20260918-011204-light-backlit-snow-spray"
title: "Let snow spray and plumes glow when lit from behind"
status: ready
priority: P2
depends_on: []
created: "2026-09-18T01:12:04Z"
updated: "2026-09-18T01:12:04Z"
source_thread: null
---

# Let snow spray and plumes glow when lit from behind

## Outcome

Snow thrown by the skis should light up when the sun is behind it, the way real
spray does: a bright, warm, translucent plume rather than a flat white puff. This
is one of the strongest visual signatures of skiing at speed, and it currently
does not happen at any sun angle.

## Current state and evidence

Read-only inspection and bounded rendered macOS probes on 2026-09-18 at `main` `7c2d049`. Probe captures used `scripts/mac_frame_probe.sh` with the deterministic `--probe-hold`/`--probe-at-tick` options; the Standard fixture (seed 849205174) was rebaked because the local cache was `mountain_cache_v15` against current `mountain_cache_v17`. macOS frame times are not the performance target in [Rendering](../../docs/RENDERING.md#performance-policy); they indicate direction only.

- [`snow_spray.gdshader`](../../assets/graphics/snow_spray.gdshader) draws the
  spray, grain and mist billboards. It renders `blend_mix, depth_draw_never,
  cull_disabled`, includes
  [`cloud_light.gdshaderinc`](../../assets/cloud_light.gdshaderinc) for the shared
  lighting and cloud transmission, and sets a flat `ALBEDO` of `.94,.97,1.0`.
- That shared `light()` gates its transmission lobes behind
  `ALPINE_NEEDLE_TRANSMISSION` and `ALPINE_SNOW_TRANSMISSION`. Neither is defined
  for the spray shader, so the billboards receive the ordinary diffuse and
  specular response with no forward scattering and no phase function: a plume
  between the camera and the sun is shaded as if it were front-lit.
- Budgets already exist and are generous at High:
  [`graphics_presets.gd`](../../scripts/presentation/graphics_presets.gd) gives
  384 spray, 256 grain and 128 mist per ski at preset 7, so this is a shading gap
  rather than a missing particle system.
- The shader already samples the depth texture for soft intersection, so it has
  the scene depth it would need for any near-surface treatment.
- Related but separate: weather precipitation and the rider-local spindrift layer
  are owned by
  [`weather_effects.gd`](../../scripts/presentation/weather_effects.gd).

## Agreed decisions and scope

- Restrained and physical in feel. The plume should glow when backlit and stay
  close to today's appearance when front-lit; a permanently brighter spray is a
  regression.
- Must obey the existing attenuation the shared lighting already applies: terrain
  and tree shadows, cloud transmission, night and the moon. A glowing plume in a
  shadow or at night is a failure.
- Reuse the shared `light()` contract rather than adding a private lighting path;
  if a transmission define is the right mechanism, follow the pattern the needle
  and snow transmission already use.
- Presentation only. Particle counts, emission rules, physical eligibility and
  the snow contact contract in
  [Rendering](../../docs/RENDERING.md#snow-presentation) are unchanged.
- Out of scope: weather precipitation appearance, the powder patch, ski tracks
  and any new particle budget.

## Implementation approach

1. Reproduce a strong plume deterministically. A held-speed skidding turn through
   loose snow with the sun low and ahead of the camera is the case; the
   `--probe-hold` and `--probe-at-tick` probe options make the capture repeatable.
2. Add a forward-scattering term driven by the angle between the view and the sun,
   applied through the shared lighting so the existing `visibility` term, cloud
   transmission and night gate all continue to apply unchanged.
3. Keep the billboard's own soft-intersection and camera fade intact; the change
   is a lighting response, not an opacity or shape change.
4. Check the three particle kinds separately. Spray, grain and mist have different
   alphas and the mist layer in particular can become objectionable if it glows.

## Acceptance and verification

- [ ] Matched captures of the same held-speed turn with the sun behind, to the
  side and in front of the plume show a clear backlit glow and a front-lit
  appearance close to today's.
- [ ] The plume does not glow in terrain or tree shadow, under heavy cloud, or at
  night; capture each case.
- [ ] Spray, grain and mist are each inspected; confirm the mist layer stays
  restrained.
- [ ] First-person and chase views both checked, with production upscaling active,
  since thin billboards are sensitive to temporal reconstruction.
- [ ] Bounded warmed before/after frame comparison during heavy spray, with the
  noise floor stated.
- [ ] Update [Rendering](../../docs/RENDERING.md#snow-presentation) and validate
  the backlog.

Human acceptance: the user's judgement of how bright a backlit plume should be is
a completion gate.

## Open questions

None.

## Completion record

Pending implementation.

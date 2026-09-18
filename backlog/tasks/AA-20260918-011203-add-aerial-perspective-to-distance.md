---
id: "AA-20260918-011203-add-aerial-perspective-to-distance"
title: "Separate the mountain into depth planes with aerial perspective"
status: ready
priority: P2
depends_on: []
created: "2026-09-18T01:12:03Z"
updated: "2026-09-18T01:12:03Z"
source_thread: null
---

# Separate the mountain into depth planes with aerial perspective

## Outcome

Near slope, mid-distance ridges and the distant massif should read as clearly
separated depth planes. Today they share almost the same value and saturation, so
a wide shot reads flat and it is hard to judge how far away a face is. Real
alpine air lightens and cools distance progressively; the mountain should do the
same without becoming hazy or losing the clear-day feeling.

## Current state and evidence

Read-only inspection and bounded rendered macOS probes on 2026-09-18 at `main` `7c2d049`. Probe captures used `scripts/mac_frame_probe.sh` with the deterministic `--probe-hold`/`--probe-at-tick` options; the Standard fixture (seed 849205174) was rebaked because the local cache was `mountain_cache_v15` against current `mountain_cache_v17`. macOS frame times are not the performance target in [Rendering](../../docs/RENDERING.md#performance-policy); they indicate direction only.

- [`alpine_world.gd`](../../scripts/world/alpine_world.gd) enables distance fog
  with `fog_light_color` `aab8cb`, `fog_light_energy` 0.75 and `fog_density`
  0.00012, and sets `fog_sky_affect` to 0.07 while weather is active.
  `fog_aerial_perspective` is never assigned, so it stays at its default and fog
  does not take the sky's colour by view direction.
- The Clear weather preset uses `fog_density` 0.000065
  ([`weather_preset.gd`](../../scripts/presentation/weather_preset.gd)), scaled by
  the `fog_strength` preset control, so clear days are close to fog-free.
- In `artifacts/mac_probe/det_off.png` the far massif and the near snowfield sit
  at very similar values; sampled far-peak snow in `artifacts/mac_probe/vs_base_1.png`
  was 144,162,178 sunlit against 131,148,162 shadowed, which is a narrow range
  carrying almost all the depth information in the frame.
- The distant backdrop already has its own separate haze owner:
  [`offmap_fog.gdshaderinc`](../../assets/graphics/offmap_fog.gdshaderinc) and
  [`wilderness_atmosphere.gd`](../../scripts/world/wilderness_atmosphere.gd)
  replace automatic material fog with a custom `FOG` output beyond 1 km, described
  in [Rendering](../../docs/RENDERING.md#background). Any change here must compose
  with that owner rather than duplicating or fighting it.

## Agreed decisions and scope

- Clear days must stay clear. The outcome is depth separation, not added haze;
  a milky mountain is a failure.
- Compose with the existing valley-haze owner beyond 1 km and with the protected
  192 m collar. Do not move the boundary between the playable fog and the
  offmap custom `FOG` output.
- Respect the `fog_strength` preset control and the weather and daylight ramps;
  the effect must follow weather and time rather than being a fixed grade.
- Presentation only: no sky rewrite, no new pass, no new texture.
- Out of scope: volumetric shafts, the sun lens flare, distant mountain shadows
  and the `offmap_snow_detail` deposits, all of which have their own owners.

## Implementation approach

1. Capture a matched wide shot that contains near slope, mid ridge and distant
   massif in one frame, and record the sampled value and saturation of each plane
   so separation can be measured rather than argued.
2. Evaluate `fog_aerial_perspective` together with `fog_sky_affect` and the height
   terms, since aerial perspective takes its colour from the sky and the sky here
   is already weather-driven. Check what it does to the sky-adjacent horizon band
   before tuning anything else.
3. Verify the composition with the offmap owner explicitly at the handover: the
   playable terrain, the apron and the ridges must agree in colour across the
   boundary at several times of day.
4. Keep the near 100 m visually untouched; nothing within normal skiing reach
   should gain visible haze.

## Acceptance and verification

- [ ] Matched wide shots show three distinguishable depth planes, with recorded
  before and after value and saturation per plane.
- [ ] Clear noon retains its clarity; the near 100 m is visually unchanged.
- [ ] No seam or colour disagreement at the 1 km valley-haze handover or the
  192 m collar, checked at low sun, noon and dusk.
- [ ] The `fog_strength` control and the weather and daylight ramps still drive
  the result across Clear, Cloudy, snow and storm presets.
- [ ] Bounded warmed frame comparison; negligible cost expected but confirmed.
- [ ] Update [Rendering](../../docs/RENDERING.md#background) and validate the
  backlog.

Human acceptance: the amount of separation is an art call and needs the user's
visual review as a follow-up.

## Open questions

None.

## Completion record

Pending implementation.

---
id: "AA-20260918-011203-add-aerial-perspective-to-distance"
title: "Separate the mountain into depth planes with aerial perspective"
status: done
priority: P2
depends_on: []
created: "2026-09-18T01:12:03Z"
updated: "2026-09-18T17:37:50Z"
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

- [x] Matched wide shots show three distinguishable depth planes, with recorded
  before and after value and saturation per plane.
- [x] Clear noon retains its clarity; the near 100 m is visually unchanged.
- [x] No seam or colour disagreement at the 1 km valley-haze handover or the
  192 m collar, checked at low sun, noon and dusk.
- [x] The `fog_strength` control and the weather and daylight ramps still drive
  the result across Clear, Cloudy, snow and storm presets.
- [x] Bounded warmed frame comparison; negligible cost expected but confirmed.
- [x] Update [Rendering](../../docs/RENDERING.md#background) and validate the
  backlog.

Human acceptance: the amount of separation is an art call and needs the user's
visual review as a follow-up.

## Open questions

None.

## Completion record

Delivered in milestone note [8197d2fc27f04f5ea56d6960f4b80b09](../../changes/8197d2fc27f04f5ea56d6960f4b80b09.json).
`alpine_atmosphere.depth_fog` now shares a weather/sky-derived linear colour and
restrained clear-day optical depth across playable terrain, apron, ridges and
props. Native aerial perspective was evaluated and rejected because it did not
reach custom background FOG. No new shader/pass/texture/height layer. Existing
192m collar and1km valley handover remain; both depth and valley terms now obey
live fog strength. Night and Weather Off remove the added ramp.

Nine pilot views plus44 final native4K High Auto.75 views cover21 matched camera
pairs at noon/dawn/dusk/night, cloudy, snowfall and storm, plus strength0.5/1.5.
No obvious new handover colour seam in reviewed samples. Noon near/mid/far shaded
patch luma changes .15785/.42445/.59018 to .15861/.45615/.60807; saturation changes
.17366/.20717/.13738 to .17623/.20833/.15507. Near/middle separation grows while
middle/far separation narrows slightly. Foreground snow luma changes only.00029.
The result retains three depth planes; it is not a universal contrast gain.
723 automated assertions passed, including actual matching receiver colour and
optical density, same-tier overrides and sky-only cache invalidation.

Fixed-view native FpsCritical control243.72/243.54FPS versus production243.78.
Mean frame−.00257ms/GPU−.00168ms against control mean; A/A spread.00298/.00627ms.
No resolved material cost or speedup. This freezes main/physics to inspect the
fog receiver cost; it is not skiing or whole-run FPS. Full receipts, per-plane
samples and limits: `artifacts/aerial_perspective_20260918/REVIEW.md`.
User colour/depth judgment remains a follow-up, not a completion gate.

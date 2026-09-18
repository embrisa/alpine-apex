---
id: "AA-20260918-011206-show-wind-packed-and-scoured-snow"
title: "Make wind-packed and scoured snow look different from soft snow"
status: in_progress
priority: P2
depends_on: []
created: "2026-09-18T01:12:06Z"
updated: "2026-09-18T14:15:00Z"
source_thread: null
---

# Make wind-packed and scoured snow look different from soft snow

## Outcome

The mountain should show visibly different snow surfaces: soft sheltered deposits,
wind-packed slabs and hard scoured faces near ridges. The data that distinguishes
them already exists and already reaches the shader, but it changes the appearance
so slightly that the whole mountain reads as one uniform material.

## Current state and evidence

Read-only inspection and bounded rendered macOS probes on 2026-09-18 at `main` `7c2d049`. Probe captures used `scripts/mac_frame_probe.sh` with the deterministic `--probe-hold`/`--probe-at-tick` options; the Standard fixture (seed 849205174) was rebaked because the local cache was `mountain_cache_v15` against current `mountain_cache_v17`. macOS frame times are not the performance target in [Rendering](../../docs/RENDERING.md#performance-policy); they indicate direction only.

- [`alpine_surface_fragment.gdshaderinc`](../../assets/graphics/alpine_surface_fragment.gdshaderinc)
  already derives `wind_pack` as `smoothstep(.45,.9,environment.a)` from the
  environment mask's alpha channel, so a per-world wind-exposure signal is
  present at every snow fragment at no additional cost.
- It currently drives only three small terms: crystal density is scaled by
  `mix(1.0,.55,wind_pack)`, `snow_sheen` by `mix(.80,1.0,wind_pack)`, and
  roughness by `-wind_pack*.035`. None of these is visible at skiing distance.
- Albedo variation across the whole snowfield is `.94+macro*.045+drift*.035`,
  roughly a 4% brightness range, and is driven by noise rather than by the wind
  signal.
- A separate `mineral_ice` channel from the feature-exposure texture already
  demonstrates the stronger treatment this task wants, mixing toward
  `.16,.36,.43` and dropping roughness to 0.40, but
  [`alpine_surface_uniforms.gdshaderinc`](../../assets/graphics/alpine_surface_uniforms.gdshaderinc)
  gates `use_feature_exposure` to the showcase terrain only.
- Related and complementary: the wind-drift relief change evaluated on
  2026-09-18 adds shape to the snow surface but no material variation; this task
  adds the material variation. They are independent and can land in either order.

## Agreed decisions and scope

- Use the existing `environment.a` wind signal and the existing per-world
  environment mask. Do not add a texture, a pass, per-frame terrain analysis or a
  new generation output.
- Readability outranks variety. Variation must not read as a false obstacle, a
  false rock patch or a false track, and must not fight the readability hollows.
- Snow must still read as snow everywhere. Hard scoured faces may be glossier,
  cooler and less crystalline, but not glassy ice; the `mineral_ice` treatment is
  a reference for mechanism, not for intensity.
- Grip, support, loose depth and every physical property remain untouched. This
  is appearance only; the world already decides where wind-packed snow is.
- Out of scope: new snow-condition gameplay, the powder patch's own compaction
  appearance, and the showcase-only feature-exposure path.

## Implementation approach

1. Find and record where the signal actually varies on the Standard mountain
   before changing any look. If `environment.a` is nearly constant over the
   skiable faces, that is the finding and the task becomes a world-data question
   rather than a shader one; report it rather than inventing variation from noise.
2. Strengthen the existing terms first, since they are already wired: crystal
   density, sheen and roughness. Establish how much of the wanted difference
   comes for free from stronger versions of what is there.
3. Add albedo and micro-relief response only if needed, keeping the change
   anchored to the wind signal rather than to unanchored noise, so the same place
   on the mountain always looks the same.
4. Verify at skiing speed and distance, not only in close stills. A difference
   that is only visible standing still is not worth its cost.

## Acceptance and verification

- [ ] Matched stills and a moving sequence show recognisably different soft,
  packed and scoured surfaces on the Standard mountain, at both chase and
  first-person views.
- [ ] No false obstacle, false rock or false track reading at speed; check
  specifically against the readability hollows and the ski-track overlay.
- [x] Transitions between surface types are gradual, world-locked and stable
  under production upscaling; confirm no crawling at grazing angles.
- [x] Terrain, local powder patch, powder caps and tracks stay consistent with
  each other where they meet, since they share the snow material family.
- [x] Bounded warmed before/after frame comparison, with the noise floor stated.
- [x] Update [Rendering](../../docs/RENDERING.md#snow-presentation) and validate
  the backlog.

Human acceptance: the user's judgement of how much variety is right, and whether
it helps or hurts reading the slope, is a completion gate.

## Open questions

None.

## Completion record

Existing Standard mask verified (.191–.820); crystal density, sheen and roughness responses strengthened without new data or shader samples.

Implemented and measured in the shared snow milestone. Evidence and limitations:
`artifacts/snow_appearance_20260918/REVIEW.md`. 242 focused headless checks and
25 native radiance checks pass. At matching 4K High Auto .75, the local mixed
fixture measured 192.05 FPS; mean frame +.033ms versus the control average,
within the observed .150ms control spread. This is not whole-mountain acceptance.

The record remains in progress for the user look gate. In particular, isolated
lee contrast improves in first person but is nearly unchanged in chase Auto;
soft-snow sheen is intentionally reduced, and the amount of visual variety needs
user judgement. Initial summit-framed riding stills are superseded by the
corrected supplement; motion pairs match physical ticks but have camera
interpolation differences. No human/controller acceptance is claimed.

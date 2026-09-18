---
id: "AA-20260918-011202-shade-snow-beyond-the-shadow-map"
title: "Give the mountain cast shadows beyond the directional shadow distance"
status: ready
priority: P2
depends_on: []
created: "2026-09-18T01:12:02Z"
updated: "2026-09-18T01:12:02Z"
source_thread: null
---

# Give the mountain cast shadows beyond the directional shadow distance

## Outcome

Ridges, bowls and rollovers between roughly 200 m and the distant backdrop should
carry the sun's cast shadows. Today they do not, so the middle distance of every
frame is uniformly lit snow with no large-scale light and shade, which both flattens
the mountain and removes a natural cue for reading terrain ahead.

## Current state and evidence

Read-only inspection and bounded rendered macOS probes on 2026-09-18 at `main` `7c2d049`. Probe captures used `scripts/mac_frame_probe.sh` with the deterministic `--probe-hold`/`--probe-at-tick` options; the Standard fixture (seed 849205174) was rebaked because the local cache was `mountain_cache_v15` against current `mountain_cache_v17`. macOS frame times are not the performance target in [Rendering](../../docs/RENDERING.md#performance-policy); they indicate direction only.

- [`alpine_world.gd`](../../scripts/world/alpine_world.gd) sets
  `directional_shadow_max_distance` from `profile.shadow_distance_m`, which
  ranges 100 m to 320 m across the ten presets and is 220 m at recommended High
  ([`graphics_presets.gd`](../../scripts/presentation/graphics_presets.gd)).
  Beyond that distance nothing in the playable mountain casts a shadow.
- The distant backdrop has a separate owner,
  [`wilderness_horizon.gd`](../../scripts/world/wilderness_horizon.gd), whose
  precomputed obstruction atlas omits every occluder inside 3,900 m and defaults
  Off at all ten presets
  ([Rendering](../../docs/RENDERING.md#distant-mountain-shadows)).
- That leaves an unshaded band from about 220 m to 3,900 m covering most of the
  visible mountain. It is clearly visible in `artifacts/mac_probe/det_off.png`,
  where the near slope carries the rider's shadow but the mid-distance ridges do not.
- A precedent for the cheap approach already exists:
  [`snow_readability.gd`](../../scripts/presentation/snow_readability.gd) builds
  one mipmapped R8 world texture per world during scenery preparation, with no
  terrain analysis while skiing, and terrain, tracks, powder and tree skirts
  share its world-texel mapping.
- Hypothesis, not established: a per-world sun-direction horizon or height-field
  shadow texture, sampled by the existing snow materials, buys the band far more
  cheaply than extending the shadow cascades. It must be compared against simply
  raising `shadow_distance_m`, which is the obvious alternative.

## Agreed decisions and scope

- Direct sunlight attenuation only. Ambient, fog, cloud transmission and the
  existing object shadows keep their owners, exactly as the distant-shadow
  companion already constrains them.
- Must follow the live sun through the daylight cycle. A fixed-sun bake that
  breaks when time advances is not acceptable; if a bake is used, state how it
  is indexed by sun direction and what its angular resolution costs.
- Must not contradict the real shadow map. The handover at `shadow_distance_m`
  has to be continuous in both directions as the preset changes it.
- Presentation only: no terrain, support-surface, collision or generation change,
  and no per-frame terrain analysis while skiing.
- Out of scope: the distant backdrop beyond 3,900 m, which
  [`wilderness_horizon.gd`](../../scripts/world/wilderness_horizon.gd) owns, and
  any change to gameplay shadow distance defaults.

## Implementation approach

1. Capture the defect first: matched stills of a mid-distance ridge at low and
   high sun, at presets 4, 7 and 10, so the unshaded band is documented before
   any change.
2. Compare two candidates and reject visually before timing. First, simply raising
   `shadow_distance_m` and its cascade budget, which establishes both the target
   appearance and the cost to beat. Second, a prepared per-world shadow lookup
   sampled in the shared snow materials, following the readability map's
   ownership, preparation point and world-texel mapping.
3. Whichever candidate proceeds, make the handover explicit: crossfade the new
   term to zero where the real shadow map takes over, and verify no double
   darkening and no visible seam at any preset.
4. Gate it behind a Lighting and shadows control with a conservative default, in
   the same way distant mountain shadows and snow deposits are opt-in, unless the
   measured cost is small enough to justify enabling it at recommended High.

## Acceptance and verification

- [ ] Matched stills at low, mid and high sun show mid-distance ridges and bowls
  carrying coherent cast shadows that agree with the sun direction and with the
  near shadow map.
- [ ] The handover at `shadow_distance_m` is seamless at presets 4, 7 and 10, in
  both directions, with no double darkening.
- [ ] Shadows track the daylight cycle; capture at least three times of day and
  confirm night and moon behaviour is unchanged.
- [ ] Ambient, fog, cloud transmission, readability hollows and object shadows
  are visually unchanged.
- [ ] Bounded warmed before/after frame, GPU, memory and scenery-preparation
  comparison. Preparation cost belongs in the loading budget, not the frame
  budget; report both separately.
- [ ] Run the scenery loading and graphics override suites, and update
  [Rendering](../../docs/RENDERING.md#terrain-forests-and-lighting) plus
  [Validation](../../docs/VALIDATION.md).

Human acceptance: whether the added shade helps or hinders reading terrain at
speed needs the user's playtest; it is a follow-up, not a completion gate.

## Open questions

None.

## Completion record

Pending implementation.

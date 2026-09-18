---
id: "AA-20260918-092102-give-the-night-sky-stars"
title: "Give the night sky stars"
status: ready
priority: P3
depends_on: []
created: "2026-09-18T09:21:02Z"
updated: "2026-09-18T09:21:02Z"
source_thread: null
---

# Give the night sky stars

## Outcome

A clear night on a 4,000 m mountain should have a sky full of stars. Today it is
a plain colour gradient with a moon disc, so night skiing loses the one thing
that would make it memorable, and the sky reads as an empty backdrop rather than
altitude and darkness.

## Current state and evidence

Rendered macOS probe captures on 2026-09-18 at `main` `a94b93b`, using `scripts/mac_frame_probe.sh --probe-hold=90 --probe-immortal --probe-at-tick=3000` with `--time-of-day` and `--weather`, so every condition is the same ground at the same solver tick. Retained under `artifacts/mac_probe/look_*.png`. macOS frame times are not the performance target in [Rendering](../../docs/RENDERING.md#performance-policy).

- [`weather_sky.gdshader`](../../assets/weather_sky.gdshader) is 48 lines. Its
  only night content is at lines 43 to 45: a moon alignment term, a
  `smoothstep(0.99980,0.99993,...)` disc plus a `pow(moon_alignment,300.0)` glow,
  added as `vec3(0.65,0.77,0.96)*moon*moon_glow_strength`. There is no star
  field, constellation, milky way or any other night detail anywhere in the file.
- [`daylight_cycle.gd`](../../scripts/presentation/daylight_cycle.gd) already
  drives a full night state: `sky_top` toward `061020`, `sky_horizon` toward
  `243b56`, `ambient_energy` down to 0.22, and
  [`alpine_world.gd`](../../scripts/world/alpine_world.gd) already drives
  `moon_glow_strength` from `smoothstep(0.01,0.20,-state.sun_direction.y)`. A
  star term has a ready-made gate in exactly the same value.
- Night lighting itself is in reasonable shape: `artifacts/mac_probe/look_night.png`
  shows credible moonlit blue snow with the rider casting a moon shadow, so this
  is a missing sky feature rather than a broken night.
- The daylight cycle wraps in 3,600 active skiing seconds
  ([Rendering](../../docs/RENDERING.md#weather)), so a player reaches night
  regularly in ordinary free skiing; this is not an exotic state.
- The sky material already owns a cheap radiance branch for ambient and
  reflection, and [Rendering](../../docs/RENDERING.md#weather) warns that camera
  movement must not dirty that radiance map. A star field must not either.

## Agreed decisions and scope

- Stars belong to the sky shader. No new mesh, texture, particle system or pass,
  and no change to the radiance or ambient contract.
- Must fade correctly through the existing daylight and cloud state: invisible by
  day, appearing through dusk, hidden under heavy cloud coverage and during
  storms, following the values the daylight cycle already computes.
- Must be world-stable, not screen-space. Stars stay fixed relative to the world
  as the camera turns; they must not swim, crawl or alias under production
  upscaling at racing speed.
- Restrained. A believable alpine sky, not a dense decorative starscape; the moon
  keeps its current disc and glow.
- Presentation only, with no gameplay, weather-state or lighting change.
- Out of scope: aurora, shooting stars, a rotating celestial sphere tied to real
  time, and any change to moon phase or brightness.

## Implementation approach

1. Capture the reference night first, including a view that actually contains
   sky; the ordinary chase camera pitches down, so a deliberate look-up or a
   summit view is needed to judge this at all.
2. Add a procedural star field driven by `EYEDIR` in the existing shader, gated
   by the same `moon_glow_strength`-style daylight value and attenuated by
   `cloud_coverage`, so it costs a branch that day frames skip.
3. Prioritise stability over density. Fewer, well-filtered stars that stay put
   under motion and upscaling beat a bright field that shimmers.
4. Check the radiance branch explicitly: coverage and colour changes refresh it,
   and camera movement must not.

## Acceptance and verification

- [ ] Night captures with sky in frame show a believable star field; day captures
  are unchanged.
- [ ] Stars fade correctly through dusk and dawn and are suppressed by heavy
  cloud coverage and during storms.
- [ ] No swimming, crawling or aliasing while the camera turns at speed, checked
  with production upscaling active, not only in stills.
- [ ] Ambient, reflection and the radiance refresh contract are unchanged; camera
  movement does not dirty the radiance map.
- [ ] Bounded warmed before/after frame comparison at night and by day, confirming
  the day path is unaffected.
- [ ] Update [Rendering](../../docs/RENDERING.md#weather) and validate the backlog.

Human acceptance: star density and brightness are an art call and need the user's
visual review as a follow-up, not a completion gate.

## Open questions

None.

## Completion record

Pending implementation.

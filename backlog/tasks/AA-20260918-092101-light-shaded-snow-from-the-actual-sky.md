---
id: "AA-20260918-092101-light-shaded-snow-from-the-actual-sky"
title: "Let shaded snow take its colour from the sky it actually faces"
status: ready
priority: P1
depends_on: []
created: "2026-09-18T09:21:01Z"
updated: "2026-09-18T09:21:01Z"
source_thread: null
---

# Let shaded snow take its colour from the sky it actually faces

## Outcome

Snow that is not in direct sun should be lit by the sky above it, so a slope
picks up the warm horizon at dawn and dusk, the deep blue overhead at noon and
the cold violet of night. Today all shaded snow receives one flat ambient colour
regardless of which way it faces, which is why dusk looks broken: the distant
peaks catch a beautiful pink alpenglow while the slope under the rider's skis
stays a dead neutral grey.

## Current state and evidence

Rendered macOS probe captures on 2026-09-18 at `main` `a94b93b`, using `scripts/mac_frame_probe.sh --probe-hold=90 --probe-immortal --probe-at-tick=3000` with `--time-of-day` and `--weather`, so every condition is the same ground at the same solver tick. Retained under `artifacts/mac_probe/look_*.png`. macOS frame times are not the performance target in [Rendering](../../docs/RENDERING.md#performance-policy).

- Sampled from `artifacts/mac_probe/look_dusk.png`: the distant lit peak is
  177,145,155 and the mid-distance lit snow is 176,135,147, both clearly warm,
  while the foreground snow the rider is skiing on is 119,122,141 and the right
  flank is 113,120,141. Red sits about 20 below blue there, so the near slope is
  a desaturated cool grey with no relationship to the sky above it.
- [`alpine_world.gd`](../../scripts/world/alpine_world.gd) sets
  `ambient_light_source = AMBIENT_SOURCE_SKY` with
  `ambient_light_sky_contribution = 0.42`, and the weather state supplies
  `ambient_light_color` and `ambient_light_energy` each time it changes. Fifty
  eight percent of ambient is therefore one flat colour, and the sky's own
  contribution arrives as a single irradiance with no directionality.
- [`daylight_cycle.gd`](../../scripts/presentation/daylight_cycle.gd) already
  computes a rich sky for dusk: `dusk_horizon` `e79c78`, a warm orange, against
  `dusk_top` `66516f`. None of that reaches the snow, because
  `state.ambient_color` is a single lerp toward `91afd7`.
- The inputs for a directional approximation already exist and are already
  published per frame. `weather_state.gd` carries `sky_top`, `sky_horizon`,
  `cloud_color` and `fog_color`, and `alpine_world.gd` already submits them to
  the sky material, so a hemisphere term needs no new plumbing.
- The snow surface already has the world normal in hand:
  `alpine_surface_fragment.gdshaderinc` computes `vec3 n=normalize(world_n)` and
  uses `n.y` for rock and deposit masks.
- Night shows the same flatness with a different tint: foreground snow is
  85,107,140 and the distant peak 73,96,129 in `look_night.png`.
- Dawn is the control that isolates the defect. In
  `artifacts/mac_probe/look_dawn.png`, captured at `d753926`, directly lit snow
  samples 196,152,149 and 174,141,147, warm and convincing, while shaded snow in
  the same frame samples 126,130,147 in the mid distance and 133,142,155 on the
  far massif. Lit snow already works; only the shaded path is flat. The dusk
  frame is the same pattern with the foreground on the shaded side of the line,
  which is why it reads as broken there.
- Distinct from
  [affordable contact shading](AA-20260918-011205-seat-scenery-with-affordable-contact-shading.md),
  which is about local occlusion where objects meet snow, and from
  [snow highlight headroom](AA-20260918-011201-restore-snow-highlight-headroom.md),
  which is about tone mapping. This one is the colour of ambient light itself.

## Agreed decisions and scope

- Approximate, not physical. A hemisphere or similar cheap directional term using
  the sky colours already published is the target; SDFGI, SSIL and any new pass
  or probe system are explicitly not.
- Must follow weather and the daylight cycle through the existing state, so dawn,
  dusk, night, overcast and storm all change together with the sky itself.
- Snow readability at speed outranks colour richness. Terrain hollows and the
  wind-drift relief keep their owners and must remain legible.
- Shaded snow must stay believably snow. Richer and better related to the sky,
  not tinted orange or purple to the point of looking like a filter.
- Presentation only: no gameplay, generation or physical lighting change, and no
  new saved setting in this task.
- Out of scope: the distant backdrop's own atmosphere owner beyond 1 km, the sun
  lens flare, and bounce light from lit terrain onto shaded terrain, which is a
  larger problem and should be recorded separately if it proves necessary.

## Implementation approach

1. Capture the matched reference set first: dawn, dusk, noon, night, overcast and
   storm at the same tick, with sampled snow colours recorded, so the change is
   judged against numbers and not impressions.
2. Feed the already-published `sky_top` and `sky_horizon` into a cheap
   normal-driven ambient term in the shared snow surface material, so an upward
   face sees the zenith and a face tilted toward the horizon sees the horizon.
   Terrain, the powder patch and the apron share the include, so they stay
   consistent by construction.
3. Compose with the existing environment ambient rather than replacing it; decide
   and record whether `ambient_light_sky_contribution` should change once the
   material carries its own directional term, so the two do not double up.
4. Check rock, trees and equipment, which do not share the snow include. If snow
   alone gains the treatment, verify the mountain still reads as one lighting
   environment rather than two.

## Acceptance and verification

- [ ] Matched dawn, dusk, noon, night, overcast and storm captures show shaded
  snow taking colour from the sky, with sampled before and after values recorded
  for each.
- [ ] The dusk disconnect is resolved: the foreground relates to the lit peaks
  instead of reading as neutral grey beside them.
- [ ] Snow still reads as snow in every condition; no colour cast that looks like
  a filter.
- [ ] Readability hollows, wind-drift relief, crystals and sheen remain legible
  and are captured alongside.
- [ ] Rock, forest, equipment and the rider do not visually detach from the snow.
- [ ] Bounded warmed before/after frame comparison; arithmetic only is expected
  but confirmed with the noise floor stated.
- [ ] Update [Rendering](../../docs/RENDERING.md#snow-presentation) and validate
  the backlog.

Human acceptance: the resulting colour of shaded snow is an art call and is a
completion gate.

## Open questions

None.

## Completion record

Pending implementation.

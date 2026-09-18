---
id: "AA-20260918-092100-make-falling-snow-visible-in-weather"
title: "Make snowfall and snowstorm look like falling snow rather than fog"
status: ready
priority: P1
depends_on: []
created: "2026-09-18T09:21:00Z"
updated: "2026-09-18T09:21:00Z"
source_thread: null
---

# Make snowfall and snowstorm look like falling snow rather than fog

## Outcome

Skiing through Snowfall or Snowstorm should look like skiing through falling
snow. Today both read as fog: the distance whites out, but almost no flakes are
visible, and a full snowstorm is indistinguishable from light snowfall except
that the air is hazier. Two of the six weather presets do not deliver the thing
they are named after.

## Current state and evidence

Rendered macOS probe captures on 2026-09-18 at `main` `a94b93b`, using `scripts/mac_frame_probe.sh --probe-hold=90 --probe-immortal --probe-at-tick=3000` with `--time-of-day` and `--weather`, so every condition is the same ground at the same solver tick. Retained under `artifacts/mac_probe/look_*.png`. macOS frame times are not the performance target in [Rendering](../../docs/RENDERING.md#performance-policy).

- `artifacts/mac_probe/look_snowfall.png` and `look_storm.png` show a handful of
  faint specks across a 3600x2260 frame. The mountain reads as an overcast
  whiteout in both; nothing in either image communicates precipitation.
- [`weather_effects.gd`](../../scripts/presentation/weather_effects.gd) sets
  `HIGH_VOLUME_COUNTS = [600,900]` for the snow and rain volumes, inside a
  `visibility_aabb` of `AABB(Vector3(-16,-11,-23),Vector3(32,22,46))`. That is
  32,384 cubic metres, so 600 flakes is one per 54 cubic metres, about one flake
  per 3.8 m cube. At any realistic viewing distance that is invisible.
- Storm intensity does not add flakes. At line 121 `strength` is `state.snow` or
  `state.rain`, and at line 133 it drives only
  `material.set_shader_parameter("opacity",strength*...)`. `particle.amount`
  comes from quality and `weather_budget` alone at line 96, so a snowstorm and a
  light snowfall emit the same 600 particles and differ only in transparency.
- Thunderstorm is the same. `artifacts/mac_probe/look_thunder.png`, captured at
  `d753926`, is visually indistinguishable from Snowstorm despite running the
  900-particle rain volume: a grey-blue whiteout with no visible precipitation.
  All three precipitation presets currently read the same.
- First person makes it starker. `artifacts/mac_probe/look_fp_snow.png` looks
  directly into falling snow at 90 km/h and shows roughly a dozen faint specks in
  the whole frame. That is the view where snowfall should be most obvious.
- [Rendering](../../docs/RENDERING.md#weather) records the existing constraints:
  translation-only local volumes with wrapping and retained particle state,
  bounded ground samples instead of per-particle CPU collision, budgets capped at
  1,700 High and 850 Low, and quality zero disabling precipitation entirely.
- The whiteout itself comes from the weather fog density in
  [`weather_preset.gd`](../../scripts/presentation/weather_preset.gd), which is
  working. The gap is the precipitation, not the atmosphere.
- Hypothesis, not established: a much denser near-camera band, rather than a
  uniform fill of the whole 32x22x46 m box, buys visible snowfall within the
  existing budget, because most of that volume is too far away to resolve a flake.

## Agreed decisions and scope

- Snowfall and snowstorm must be visually distinct from each other and from
  Cloudy, and a storm must clearly intensify. Opacity alone is not sufficient.
- Readability at racing speed outranks density. Falling snow must not hide the
  terrain the rider is about to cross; whiteout is atmospheric, not a wall of
  particles in front of the camera.
- Respect the existing budgets and controls: the 1,700 High and 850 Low caps,
  `weather_quality` including zero, `weather_budget` and Reduced Motion. State
  plainly if a larger budget is needed rather than quietly exceeding it.
- Keep the existing translation-only volume, wrapping, retained particle state
  and reset rules on teleport, retry, camera transition and quality change.
- Presentation only. No accumulation, no wet-grip model, no physical wind force
  and no precipitation collision; those would need physical contract changes.
- Out of scope: the rider-local spindrift layer, ski spray, fog density tuning
  and the separate ridge-crest spindrift record.

## Implementation approach

1. Reproduce the four reference conditions first with the deterministic probe:
  Cloudy, Snowfall, Snowstorm and Clear at the same tick, so the differences
  between them are documented before anything changes.
2. Attack distribution before count. Concentrate flakes where they can actually
  be resolved, and check whether the 32x22x46 m box is spending most of its
  budget on particles too far from the camera to register.
3. Make intensity drive density, not only opacity. `state.snow`, `state.gust` and
  the storm peak should visibly change how much snow is in the air, within the
  stated caps.
4. Check it in motion at speed, not in stills. Flake streaking relative to a
  90-140 km/h camera is most of what sells falling snow, and the draw shader
  already carries `flow` and `stretch` parameters for it.

## Acceptance and verification

- [ ] Matched captures and a moving sequence show clearly visible falling snow in
  Snowfall, and a Snowstorm that is unmistakably heavier, both distinct from
  Cloudy.
- [ ] The line ahead stays readable at 90 and at 140 km/h, in chase and
  first-person, with the rider able to see terrain in time to react.
- [ ] Particle counts stay within the 1,700 High and 850 Low caps; report the
  actual counts per condition.
- [ ] `weather_quality` zero, Low preset, `weather_budget` and Reduced Motion all
  behave correctly and remain fully removable.
- [ ] Teleport, retry, crash, pause, camera transition and quality change reset
  particle state cleanly, matching the existing rules.
- [ ] Bounded warmed before/after frame comparison in Snowstorm, the worst case,
  with the noise floor stated.
- [ ] Run the weather suites and update
  [Rendering](../../docs/RENDERING.md#weather).

Human acceptance: how heavy a storm should feel, and how much visibility a
player should lose, is the user's call and is a completion gate.

## Open questions

None.

## Completion record

Pending implementation.

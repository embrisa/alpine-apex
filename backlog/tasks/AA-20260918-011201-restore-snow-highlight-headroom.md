---
id: "AA-20260918-011201-restore-snow-highlight-headroom"
title: "Give sunlit snow tonal headroom so its existing detail survives tone mapping"
status: in_progress
priority: P1
depends_on: []
created: "2026-09-18T01:12:01Z"
updated: "2026-09-18T14:15:00Z"
source_thread: null
---

# Give sunlit snow tonal headroom so its existing detail survives tone mapping

## Outcome

Sunlit snow should hold visible form and surface detail instead of flattening
into near-white. The mountain already computes scanned normal detail, crystal
facets, broad sheen, wind ripples and readability hollows, but on open sunlit
faces most of that lands where the filmic curve is nearly flat and is compressed
away. This recovers detail that is already being paid for; it does not add new
detail.

## Current state and evidence

Read-only inspection and bounded rendered macOS probes on 2026-09-18 at `main` `7c2d049`. Probe captures used `scripts/mac_frame_probe.sh` with the deterministic `--probe-hold`/`--probe-at-tick` options; the Standard fixture (seed 849205174) was rebaked because the local cache was `mountain_cache_v15` against current `mountain_cache_v17`. macOS frame times are not the performance target in [Rendering](../../docs/RENDERING.md#performance-policy); they indicate direction only.

- Measured mean display luminance over the foreground snowfield of
  `artifacts/snow_wind_drift/frame_before.png` is 0.840; an earlier open-face
  capture measured 0.876. In that earlier frame sunlit against shadowed snow was
  224,219,211 versus 180,179,179, a ratio of only 1.24.
- [`alpine_atmosphere.gd`](../../scripts/presentation/alpine_atmosphere.gd) raises
  `tonemap_exposure` to 1.15 and `tonemap_white` to 2.8 on clear golden days,
  commented as rolling off highlights to preserve scanned snow and track lips.
  [`alpine_world.gd`](../../scripts/world/alpine_world.gd) selects
  `TONE_MAPPER_FILMIC`; the Clear preset uses `sun_energy` 1.9 in
  [`weather_preset.gd`](../../scripts/presentation/weather_preset.gd).
- Direct evidence of the compression, collected 2026-09-18: an isolated plane
  carrying the production `alpine_surface` material at a scene mean of 0.716
  showed a strong normal-relief response, while the identical shader change in
  game at a scene mean of 0.840 moved local contrast by roughly 4%. The
  difference was exposure, not the shader.
- Deeply shadowed snow is already correctly blue (95,111,130 sampled in
  `artifacts/mac_probe/vs_base_1.png`), so shadow colour is not the problem.
- [Rendering](../../docs/RENDERING.md#snow-presentation) records that current
  hollow shading reaches about 14% linear-light reduction. How much of that
  survives tone mapping on a sunlit face has not been measured.

## Agreed decisions and scope

- Direction settled with the user on 2026-09-18: prioritise snow that reads,
  accepting a slightly lower key to get it. Where dazzling glare and visible
  surface form conflict, form wins.
- The mountain must still read as high-altitude snow. A slightly lower key is
  accepted; a generally grey, dull or hazy mountain is not.
- One fixed look for this task. Do not add a saved exposure preference; revisit
  only if the agreed look proves divisive in playtest.
- Presentation only: environment tone mapping, exposure and the daylight and
  weather ramp that drives them. No albedo rewrite and no gameplay change.
- Snow readability at speed outranks photographic contrast. The readability
  hollows keep their current owner, strength, daylight gate and distance fade.
- Applies across the daylight cycle and the weather presets, not only clear noon.
  Night, dusk and overcast must be checked, not assumed.
- Recovering compressed detail changes how every existing snow term reads,
  including the wind-drift relief evaluated on 2026-09-18. Expect to re-tune
  those strengths afterwards rather than treating them as fixed.
- Out of scope: glow and bloom redesign, the sun lens flare, per-preset exposure
  sliders and any new post-processing pass.

## Implementation approach

1. Characterise before changing anything. Capture a fixed matched set across
   clear noon, low sun, overcast and night and record snowfield mean luminance
   and local contrast for each, so the change is judged against numbers. The
   deterministic probe options in `tests/mac_frame_probe.gd` make this repeatable.
2. Establish where the curve flattens for the actual snow radiance range, then
   evaluate the smallest levers first: the golden-day `tonemap_exposure` and
   `tonemap_white` ramp, and whether `sun_energy` together with ambient is
   pushing snow past the shoulder.
3. Prefer a change that lowers the shoulder for snow-range values while keeping
   the brightest specular highlights and the sun disc intact. Present at least
   one alternative to a plain exposure reduction, which on its own will read as a
   duller mountain.
4. Demonstrate the effect on what already exists: capture crystals, sheen,
   scanned normals and readability hollows before and after in isolation, since
   the value of this task is that those become visible.

## Acceptance and verification

- [ ] Matched stills across clear noon, low sun, overcast and night show more
  legible snow form with no loss of altitude brightness and no crushed shadows.
- [x] Recorded snowfield mean luminance and local contrast before and after, at
  the same solver tick and camera, for every lighting condition above.
- [ ] Crystals, sheen, scanned normal detail and readability hollows are
  demonstrably more visible; each captured in isolation.
- [x] Skier, equipment, rock, forest and interface readability are unharmed;
  check the HUD over bright snow explicitly.
- [x] Frame cost is expected to be negligible; confirm it rather than assume it.
- [x] Update [Rendering](../../docs/RENDERING.md#graphics-and-display), validate
  the backlog and push owned changes.

Human acceptance: this changes the look of every frame. The user's approval of
the resulting exposure is a completion gate.

## Open questions

None.
## Completion record

Paired Filmic daylight exposure/white ramp implemented; night tone preserved.

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


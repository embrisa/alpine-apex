---
id: "AA-20260918-092843-slow-visible-cloud-motion"
title: "Slow the visible motion of clouds and weather"
status: in_progress
priority: P2
depends_on: []
created: "2026-09-18T09:28:43Z"
updated: "2026-09-18T13:42:23.237536Z"
source_thread: null
---

# Slow the visible motion of clouds and weather

## Outcome

Make clouds and other broad weather movement feel slow, atmospheric and
intentional during ordinary riding. The player should notice that the weather
is moving over time, but should not be able to watch the cloud field visibly
slide or update across large distances in real time during a short ride. The
mountain should feel like it has a large, calm sky rather than a fast-moving
background layer.

This is a direction-setting presentation task for GPT-6 Astra. The goal is the
perceived motion and scale, not a prescribed cycle duration or one numeric
multiplier. Astra may choose the best combination of motion scale, world-space
mapping, camera parallax, update behavior or weather timing, and may correct a
nearby contract if that is clearly needed for a better result.

## Current state and evidence

Weather is presentation-owned by
[`weather_controller.gd`](../../scripts/presentation/weather_controller.gd),
[`weather_state.gd`](../../scripts/presentation/weather_state.gd),
[`cloud_lighting.gd`](../../scripts/presentation/cloud_lighting.gd) and the
cloud/sky shaders. The maintained contract is described in
[`docs/RENDERING.md`](../../docs/RENDERING.md#weather).

- Weather integrates cloud displacement from the active preset's wind over
  active time. Current preset wind values are roughly 6â€“8 m/s for ordinary
  cloudy/snow/rain conditions and 17â€“18 m/s for storm conditions.
- Race weather advances from race elapsed time and derives cloud displacement
  from the same wind, while free-ski weather also integrates cloud movement.
  Front transition durations are separate weather-state behavior, generally
  hundreds of active seconds for holds and shorter blends.
- The shared cloud field maps displacement into a broad world-space noise
  pattern and the sky also applies camera parallax. Therefore making front
  transitions longer alone may not address a cloud layer that is visibly
  moving too quickly.
- `tests/weather_motion_review.gd` already provides chronological weather
  captures across presets, time bands and both riding views. Use current
  source/runtime identity and fresh moving evidence; older weather captures are
  not proof of the current perceived speed.

## Direction and scope

- Make normal cloud motion substantially slower and less conspicuous over the
  time scale of a short descent, while retaining gentle long-term movement that
  makes the sky feel alive.
- Check ordinary cloudy, snowfall and rain conditions as well as stormy
  conditions. Storms may feel more active, but should not become a distracting
  constantly sliding backdrop.
- Consider the sky silhouette, cloud lighting on terrain/trees, camera parallax,
  high wisps and any other weather layer that contributes to the impression of
  fast motion. Keep the visual result coherent across chase and first-person
  views.
- Preserve weather choice, race weather identity, day/night behavior,
  precipitation meaning and presentation lifecycle unless a nearby change is
  genuinely required. Do not freeze weather or remove its long-term evolution
  just to hide the symptom.
- This task owns perceived weather/cloud motion, not unrelated weather audio,
  seasonal tree assets or physical wind forces.

## Useful investigation leads

These are starting points rather than a required recipe. Capture short
chronological moving views at the current production camera and compare cloud
silhouette displacement over time and distance. Separate cloud-field motion
from camera movement, precipitation drift, lighting changes and front
transitions. Decide whether the cleanest correction belongs in the wind-to-cloud
mapping, shader scale/parallax, a presentation clock, or another nearby owner.

## What success looks like

- [ ] In ordinary riding, clouds remain visually calm over a short gameplay
  interval; the player can notice slow evolution over longer observation but
  does not see the sky sweep across the mountain in real time.
- [ ] The result is coherent in both riding views and across ordinary weather,
  snowfall/rain and storms, with no obvious popping, freezing, swimming noise,
  camera-follow error or disconnected cloud lighting.
- [x] Weather fronts, day/night progression, precipitation, lifecycle pauses
  and race weather identity still behave correctly, or any intentional adjacent
  change is documented.
- [x] Current weather/lifecycle checks pass and fresh chronological rendered
  evidence demonstrates the revised motion at the relevant production views.
  Keep rendered, automated and performance evidence distinct.
- [x] The worker records what was changed, why cycle duration alone was or was
  not sufficient, and any remaining tuning or comfort follow-up.

Human acceptance: the user should watch and ride through ordinary cloud,
snowfall and at least one more active weather condition and confirm that the
weather feels alive but no longer visibly races across the scene. This is a
completion gate for perceived motion; chronological captures do not replace
the user's visual judgment.

## Open questions

None

## Completion record

Implementation delivered in the milestone containing
[`d3b202fea1354b0f83b02fea1310cda6`](../../changes/d3b202fea1354b0f83b02fea1310cda6.json).
Published cloud displacement now maps integrated wind by 0.08. Sky silhouettes,
wisps and terrain/tree cloud lighting share it. Six seconds of Cloudy moves
(3.36,0.96)m instead of (42,12); storm moves (8.16,-3.36)m instead of (102,-42).
Raw integration, front durations, day progression, precipitation/foliage wind,
camera parallax, lifecycle and race identity are retained. Longer front holds
would not address continuous wind-driven displacement, so they were not changed.

Weather 44/lifecycle 32/presentation 48/runtime 192 pass. Fresh paired six-second
1080p Native look-up clips show both views across Cloudy/Snowfall/Rain/Storm;
the reference producer explicitly isolates the old displacement mapping. Initial
ordinary-view clips contained too little cloud to judge alone and are supplemented
by these pairs. No popping/freezing or disconnected motion was observed in the
reviewed sequence; comfort remains a human gate.

Grouped 4K High Auto .75 weather costs and all limitations are retained in
`artifacts/weather_presentation_20260918/REVIEW.md`; these measure the small
production-component fixture, not full-mountain FPS. Rendering/Validation describe
the shared mapping and repeatable producers.

Remaining completion gate: user's ordinary-cloud, snowfall and active-weather
ride/watch review for a living but calm sky. The first two checkboxes stay open
for perceived-motion acceptance.

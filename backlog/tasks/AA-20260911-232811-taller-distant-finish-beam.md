---
id: "AA-20260911-232811-taller-distant-finish-beam"
title: "Raise the finish beam and improve long-distance visibility"
status: ready
priority: P2
depends_on: []
created: "2026-09-11T23:28:11Z"
updated: "2026-09-11T23:28:11Z"
source_thread: "01a092cb-8276-7610-94d6-c817b99b24ed"
---

# Raise the finish beam and improve long-distance visibility

## Outcome

The user requests: "The beam at the finish line has to go higher up in the sky
and be visible from afar." Make the finish a conspicuous skyward landmark from
the race start and distant skiable approaches, including when a ridge hides the
gate but leaves the upper shaft exposed.

## Current state and evidence

Source inspection on 2026-09-11 UTC (2026-09-12 local):

- [race_beams.gd](../../scripts/presentation/race_beams.gd) uses one shared
  cylinder for start and finish: 800 m above the anchor, 6 m radius, 8 m buried,
  24 radial segments and 31 rings. Finish brightness is 1.2 versus start 1.0.
- [race_beam.gdshader](../../assets/graphics/race_beam.gdshader) hardcodes the
  local-height offset to 396 m and the top fade to 600-800 m. Raising geometry
  alone would leave the shader's visible height incorrect.
- [race_workshop.gd](../../scripts/racing/race_workshop.gd) and
  [alpine_world.gd](../../scripts/world/alpine_world.gd) build the same component.
  [Racing](../../docs/RACING.md#gates-timing-and-splits) owns the marker lifecycle and
  presentation-only contract: depth-tested, translucent, weather fog, no shadow/GI.
- [race_beams_playtest.gd](../../tests/race_beams_playtest.gd) already captures
  500 m/2 km views, ridge occlusion, close passage, survey, quality and weather
  variants, and paired beam-on/off timing. Its distant cameras aim explicitly
  upward, so those images alone cannot prove visibility during ordinary riding.
- No focused beam-height task was found among active/archived tasks or ideas.
  The [race-loop audit](AA-20260911-153905-race-loop-acceptance-audit.md) covers
  broader acceptance and is related, not a prerequisite. Coordinate any shared
  harness/guide edits with its worker. No new rendered reproduction or timing
  was performed during this authoring turn; the user's report is the symptom.

## Agreed decisions and scope

- Increase the finish beam's visible height substantially and tune distant
  readability. Exact height, width and opacity are implementation tuning choices
  judged in rendered views; a roughly 2 km height is a starting experiment, not
  an approved final measurement.
- Retain the current central amber translucent finish style, ground anchor and
  near-camera fade. Keep the start appearance stable when separating shared
  geometry/material parameters. No unrelated marker redesign or floating labels.
- Preserve natural terrain occlusion and weather integration. An exposed upper
  shaft should remain useful at distance; full terrain blockage or severe storm
  obscuration does not require an always-visible overlay or global fog changes.
- This is presentation work. Preserve gates/collision, crossing/timing, solver,
  input, shared terrain authority, race identities, records and replay behavior.

## Implementation approach

1. Inspect current source and camera clipping/culling before changing the beam.
   Capture the current finish from the default suggested race's start and fixed
   distant approach positions using ordinary riding camera settings.
2. Give finish geometry and shader fade a coherent height definition, including
   buried base, mesh placement and true culling bounds. Avoid mutating a shared
   mesh in a way that changes start markers or previously created finish markers.
   Retain adequate vertical segmentation for fog along the taller shaft.
3. Tune height first, then bounded width/core contrast if needed for stable
   distant visibility. Avoid subpixel flicker, excessive near-gate opacity,
   hard-cut tops and unnecessary transparent overdraw. Check actual chase and
   survey camera clipping; keep any camera change narrowly justified.
4. Extend the existing rendered harness for matched before/after far views,
   including the actual race-start distance and a farther valid approach when
   available. Record camera positions, distance, field of view, visible beam
   segment, weather, quality, source/terrain identities and display settings.
   Update the marker contract in the owning Racing guide; detailed evidence
   belongs under a dedicated artifacts directory.

## Acceptance and verification

- [ ] The finish's visible shaft extends substantially above the previous 800 m
  ceiling. Record the chosen height and fade interval and show matched captures.
- [ ] At 500 m, 2 km and the default suggested race's actual start distance, the
  exposed beam is readily identifiable under clear daylight with normal riding
  camera settings, without a special upward camera aim. Include a farther valid
  skiable approach if available and record distances/occlusion honestly.
- [ ] A ridge can hide the base while the taller exposed shaft remains visible;
  terrain still occludes hidden parts. Inspect clear day/dusk/night and ordinary
  snowfall across Low/Balanced/High, plus 1080p and 4K distant readability.
- [ ] Close passage, snow seating, transparency, top fade, paused/reduced-motion
  behavior and start/finish distinction remain sound. Check authoring/library,
  active race, retry, race switch and free-ski cleanup, including component use
  by the laboratory world.
- [ ] Run native rendered inspection via the existing guard, for example
  `./scripts/run_guarded.ps1 -FilePath ./godotw.ps1 -Arguments @('--script','tests/race_beams_playtest.gd') -Label taller-finish-beam`.
  Adapt the harness to current fixture/profile isolation rules in
  [Validation](../../docs/VALIDATION.md) before running; wait for the shared lock.
  Inspect images and engine errors, not only exit status. Protect personal bests.
- [ ] Measure matched before/after rendered frame/GPU time at far and near views
  without screenshot readback in timing intervals; record settings and variance.
  Investigate a reproducible regression before completing. Generated FPS and
  structural checks are not evidence of beam readability.
- [ ] Run the existing `tests/race_suite.gd` through the guard in its required
  mode if changing marker lifecycle/integration. Any physics/input/session edits
  additionally require guarded headless physics/runtime suites under AGENTS.
- [ ] Update the owning guide and completion record, then commit and push owned
  changes with evidence paths and exact verification results.

Human acceptance: the user's judgment of long-distance usefulness in ordinary
skiing remains a separately pending visual/playtest follow-up, not a completion
gate. Worker completion requires the rendered and performance evidence above.

## Open questions

None.

## Completion record

Pending implementation. Record final parameters, rendered/automated/performance
checks actually performed, remaining human acceptance, documentation and commit/
push references. If blocked, record the exact limitation and remaining work.
Link any separately proposed follow-up ideas, or note that none were proposed.

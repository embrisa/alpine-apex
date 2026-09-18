---
id: "AA-20260918-011209-keep-ski-tracks-visible-at-distance"
title: "Keep ski tracks visible when looking back up the slope"
status: ready
priority: P3
depends_on: []
created: "2026-09-18T01:12:09Z"
updated: "2026-09-18T01:12:09Z"
source_thread: null
---

# Keep ski tracks visible when looking back up the slope

## Outcome

A rider looking back up the mountain, or watching a ghost's line ahead, should see
the tracks that were actually cut. Today every track ribbon fades out between
220 m and 380 m and is then discarded outright, so a long descent leaves a slope
that looks untouched from any distance, and the sense of having carved a line is
lost as soon as it matters most.

## Current state and evidence

Read-only inspection and bounded rendered macOS probes on 2026-09-18 at `main` `7c2d049`. Probe captures used `scripts/mac_frame_probe.sh` with the deterministic `--probe-hold`/`--probe-at-tick` options; the Standard fixture (seed 849205174) was rebaked because the local cache was `mountain_cache_v15` against current `mountain_cache_v17`. macOS frame times are not the performance target in [Rendering](../../docs/RENDERING.md#performance-policy); they indicate direction only.

- [`ski_track.gdshader`](../../assets/graphics/ski_track.gdshader) computes
  `track_distance` per vertex, sets `ALPHA` with a
  `1.0-smoothstep(220.0,380.0,track_distance)` factor, and discards entirely at
  `track_distance>=380.0` with the comment that beyond the 380 m fade the ribbon
  is fully transparent so its crystal work can be skipped.
- That discard was introduced as a performance measure; it is referenced in
  [reduce environment and screen passes](../completed/AA-20260916-084510-trim-environment-and-screen-passes.md)
  as the ski-track discard beyond 380 m, delivered in Dev 75. It is deliberate,
  so this task must find appearance without giving that saving back.
- Track capacity is large: `snow_track_capacity` reaches 4,096 at preset 7 and
  6,144 at preset 10 in
  [`graphics_presets.gd`](../../scripts/presentation/graphics_presets.gd), and
  [Rendering](../../docs/RENDERING.md#snow-presentation) records a maximum stroke
  storage of 9,366 strokes including up to ten ghost rings. The history exists; it
  simply is not drawn far away.
- Ghost tracks share the same consumer, `ghost_track_stack.gd`, so any change
  affects the player's and ten ghosts' ribbons together and must be budgeted as such.

## Agreed decisions and scope

- Do not simply raise the discard distance. The saving it delivered must be
  preserved; the task is to find a cheaper far representation, or to establish
  that none is worth it and close with that finding.
- Far tracks may be a simplified representation. Full ribbon geometry, raised
  banks, crystal sampling and the loaded-ridge overlay treatment are near-field
  features and are not required at distance.
- Appearance must remain honest: a far track must lie where the rider actually
  skied and must not survive a reset, retry, teleport or world replacement.
- No physical meaning. Tracks never become terrain, support or a race effect,
  exactly as today.
- Out of scope: track capacity, the local powder patch, the stroke buffer layout
  and the raised-bank shape work recorded in
  [the loaded-ridge correction](../completed/AA-20260912-132147-review-loaded-track-ridge-shape.md).

## Implementation approach

1. Quantify the problem before changing anything: capture a long descent, then
   look back from a stopped position at several distances and record where the
   line becomes invisible. Confirm the same for a ghost line viewed ahead.
2. Establish the cost of the current discard by measuring a build with the discard
   distance raised. That is the number any candidate must beat, and it also shows
   whether the appearance is worth pursuing at all.
3. If pursuing it, prefer a far representation that costs less per pixel than the
   near ribbon: a thin darkened line without crystal sampling, or a coarse
   world-space track mask sampled by the snow material, following the ownership
   pattern the readability map already uses.
4. Keep the near ribbon byte-identical and make the handover at the existing fade
   band continuous, so nothing changes within 220 m.

## Acceptance and verification

- [ ] Looking back from 400 m, 800 m and further shows the rider's line where it
  was actually skied, with the near 220 m visually unchanged.
- [ ] Ghost lines behave the same, with up to ten ghosts active, and the roster
  teardown removes them cleanly.
- [ ] Reset, retry, teleport, crash recovery and world replacement clear far
  tracks exactly as they clear near ones.
- [ ] Bounded warmed before/after frame and GPU comparison, reported against both
  today's build and the raised-discard build, so the saving is explicit.
- [ ] Run the snow track and ghost track suites in
  [Validation](../../docs/VALIDATION.md#snow-contact-and-local-boundary-producers).
- [ ] Update [Rendering](../../docs/RENDERING.md#snow-presentation) and validate
  the backlog.

Human acceptance: whether far tracks add to the run is the user's call, as a
follow-up rather than a completion gate.

## Open questions

None.

## Completion record

Pending implementation.

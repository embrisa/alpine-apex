---
id: "AA-20260916-084502-reduce-recording-tick-cost"
title: "Stop re-solving the skier pose and rebuilding replay snapshots on every recording tick"
status: ready
priority: P1
depends_on: []
created: "2026-09-16T08:45:02Z"
updated: "2026-09-16T08:45:02Z"
source_thread: null
---

# Stop re-solving the skier pose and rebuilding replay snapshots on every recording tick

## Outcome

Lower the fixed-tick CPU cost of timed runs (races, records, ghost recording)
so timed descents run at the same frame rate as free skiing, while producing
byte-identical replay and ghost pose data.

## Current state and evidence

Source inspected at Dev 43 / `a9c2acb` (2026-09-16).

- [`main.gd:1156-1164`](../../scripts/main.gd) `_capture_ghost_pose` runs the
  full `skier.pose(sim, fraction)` solve inside `_physics_process` whenever
  `session.recording.wants_presentation_sample()` (every fourth tick,
  `SAMPLE_EVERY = 4` in [`run_replay.gd:10`](../../scripts/racing/run_replay.gd),
  so 30 Hz). `_process` (`main.gd:708`) then solves the pose again for the
  rendered frame. With `pose` measured at 1.46-1.82 ms per solve, timed runs
  pay roughly 0.35-0.45 ms per tick on average on top of free skiing, and a
  full extra solve on the ticks where it lands.
- [`ghost_pose.gd:11-33`](../../scripts/presentation/ghost_pose.gd) `capture`
  calls `skeleton.find_bone(String)` for every bone, allocates a fresh
  `PackedFloat32Array` per transform, creates two `Response.new()` objects and
  re-runs `response.sample` plus `resolve_track_contact`, which probes up to
  two nine-point footprints in
  [`snow_response.gd:147-198`](../../scripts/presentation/snow_response.gd)
  (each point: `TerrainMaterial.at`, `surface.sample`, `snow_depth_at`).
  `Pose.validate` then walks 224 floats.
- [`run_replay.gd:76-109`](../../scripts/racing/run_replay.gd) `record` builds
  a full `snapshot` every tick (about 90 values via `append_array` of temporary
  arrays, three `get_rotation_quaternion`, 15 String-keyed `facing.joints.get`
  reads and reflection `"pole_push_phase" in sim` plus `sim.get(...)` three
  times) although only every fourth snapshot is appended; the previous tick's
  snapshot is needed only for finish interpolation. Line 82 also allocates a
  temporary `PackedFloat32Array` for the inputs each tick.
- No `ghost_capture` timings are present in the committed receipts because the
  benchmarks run untimed or with fixed input; add the scope reading to the
  evidence. The `ghost_capture` scope already exists in `main.gd`.
- Compatibility: replay 7, archive 4 and race 6 identities and the exact clock
  in [Racing](../../docs/RACING.md) must be preserved; recorded pose samples
  are validated byte-for-byte by ghost tests.

## Agreed decisions and scope

Own `scripts/main.gd` `_capture_ghost_pose`, `scripts/presentation/ghost_pose.gd`
capture side, `scripts/racing/run_replay.gd` `record`/`snapshot`, and the
capture entry in `scripts/core/run_session.gd`. Playback (`Pose.apply`,
`personal_best_ghost.gd`, `ghost_field.gd`) belongs to
[the ten-ghost task](AA-20260912-132147-reduce-ten-ghost-presentation-cost.md);
cold archive loading belongs to
[the cold archive task](AA-20260912-132147-reduce-cold-ghost-archive-load.md).

Recorded bytes must stay identical: same sample times, same pose values, same
finish interpolation. The pose captured at the fixed tick is defined by the
production writer after the fixed animation step, so it may not be replaced by
the render-interpolated pose. Allowed strategies: make the captured solve share
work with the render solve when the requested fraction equals the render
fraction, reuse the solver's completed per-ski contact state instead of
re-probing terrain for the cosmetic track flag when the result is provably the
same, cache bone indices and `Response` instances, and build snapshots into a
preallocated `PackedFloat32Array` without reflection. If a strategy cannot
prove identical bytes, record it as rejected.

## Implementation approach

1. Add `ghost_capture` and a `replay_snapshot` scope reading to a timed 15-second
   ordinary trace with `-ProfileFrameCosts`; record baseline µs per tick.
2. Cache `find_bone` indices and parent chains once per visual; keep two
   persistent `Response` instances; remove per-transform temporary arrays.
3. Decide per finding whether `resolve_track_contact` inside capture can read
   the solver's completed contact state; verify identical `track` flags over
   the existing replay fixtures before switching.
4. Rework `snapshot` to write by index into a fixed-width buffer, read
   `pole_push_phase` directly, and evaluate whether the previous-tick snapshot
   can be produced lazily for the finish tick without changing output (the
   finish fraction is known in `run_session.gd:93-100` before `record`).
5. Investigate sharing the render and capture pose solves only where the
   fraction and inputs are identical; otherwise leave the second solve and rely
   on [the bone-indexed pose task](AA-20260916-084501-index-skier-pose-by-bone.md)
   for its cost.

## Acceptance and verification

- [ ] Replay bytes, sample times, pose payloads and finish times are identical
  for the existing fixtures and a fresh 1,800-tick timed trace.
- [ ] `tests/physics_suite.gd`, `tests/runtime_suite.gd`, `tests/race_suite.gd`,
  `tests/ghost_archive_suite.gd`, `tests/ghost_retry_cache_suite.gd`,
  `tests/exact_clock_suite.gd`, `tests/crash_replay_suite.gd` and
  `tests/performance_recording_suite.gd` pass headless on the targeted map.
- [ ] One warmed timed candidate versus a matching timed control (the saved
  baselines are untimed, so one short fresh timed control is required here),
  reporting `ghost_capture`, `simulation` and frame statistics.
- [ ] Update [Racing](../../docs/RACING.md) only if the capture contract wording
  changes; commit/push owned paths with a development note and Dev ID.

Human acceptance: none; outputs are required to be identical.

## Open questions

None

## Completion record

Pending implementation. Record scope timings before/after, identity evidence,
tests run, rejected strategies and commit/push references.

---
id: "AA-20260916-084512-bound-physics-catch-up-steps"
title: "Bound physics catch-up after a long frame so hitches do not cascade"
status: ready
priority: P2
depends_on: []
created: "2026-09-16T08:45:12Z"
updated: "2026-09-16T08:45:12Z"
source_thread: null
---

# Bound physics catch-up after a long frame so hitches do not cascade

## Outcome

After a streaming, shader-compile or archive stall, the next frame should not
also run up to 24 full simulation ticks. Steady frame rate is unchanged; p99
and maximum frame times after a hitch fall, and the game cannot enter a
spiral where catch-up ticks make the following frame late as well.

## Current state and evidence

- [`project.godot`](../../project.godot) sets
  `physics/common/physics_ticks_per_second=120` and
  `physics/common/max_physics_steps_per_frame=24`. Godot's default is 8. At
  120 Hz, 24 steps allows 200 ms of catch-up in one rendered frame.
- Each catch-up tick in [`main.gd:555-660`](../../scripts/main.gd) runs the
  full solver (1.5 ms mean per the committed `simulation` scope), the fixed
  animation step (0.9-1.0 ms), audio observers, haptics, session/replay
  recording and every fourth tick the ghost capture. A 100 ms stall therefore
  costs about 12 ticks times 2.5-3 ms, roughly 30-36 ms of extra work on the
  next frame, which can itself trigger further catch-up.
- Recorded per-run maxima of 25-29 ms with p99 18.7-20.2 ms in
  [DENSE_FOREST_BASELINE.json](../../docs/DENSE_FOREST_BASELINE.json) and
  streaming events of 7-24 ms in the rendering baseline are the hitch sources
  this amplifies. [Audio](../../docs/AUDIO.md) already skips late events
  beyond a bounded catch-up window.
- The 120 Hz Node-independent solver contract in
  [Architecture](../../docs/ARCHITECTURE.md) is unaffected: ticks remain
  120 Hz and deterministic; only how many are executed in one late frame
  changes. Replay recording (`run_replay.gd`) is tick-based, so trailing ticks
  are not lost; the race clock is tick-driven and would slip against wall time
  only during the stall itself, which is what the player already perceives.
  Benchmarks replay fixed ticks and are unaffected.

## Agreed decisions and scope

Own the `max_physics_steps_per_frame` setting and the paragraph documenting it
in Architecture or Physics. Keep 120 Hz, the solver, replay 7 and race 6
identity unchanged. Choose a value between 6 and 8 (50-66 ms of catch-up)
after measuring; do not go below 6 without the user's decision because very
low values make long stalls visibly slow the world. Do not add interpolation
tricks or variable tick rates.

## Implementation approach

1. Reproduce a hitch (cold collision streaming via `--cold-collision` in the
   descent benchmark, or a forced 100 ms stall in a local probe) and record
   the following frames' costs at 24 versus 8 and 6 steps.
2. Set the chosen value in `project.godot`, document the catch-up bound and
   its rationale, and confirm exact replay endpoints and race clocks match for
   an ordinary trace.

## Acceptance and verification

- [ ] Post-hitch frame cost and p99/maximum frame times fall in the hitch
  reproduction; steady-state frame statistics unchanged within variation.
- [ ] `tests/physics_suite.gd`, `tests/runtime_suite.gd`,
  `tests/exact_clock_suite.gd`, `tests/race_suite.gd` and
  `tests/performance_trace_contract_suite.gd` pass; replay endpoints exact.
- [ ] Documentation updated in the owning guide; commit/push with a
  development note and Dev ID.

Human acceptance: a short playtest confirming that ordinary stalls no longer
feel like a double stutter is a follow-up, not a gate.

## Open questions

None

## Completion record

Pending implementation. Record measured post-hitch costs per setting, the
chosen value, tests and commit/push references.

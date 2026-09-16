---
id: "AA-20260916-084512-bound-physics-catch-up-steps"
title: "Bound physics catch-up after a long frame so hitches do not cascade"
status: done
priority: P2
depends_on: []
created: "2026-09-16T08:45:12Z"
updated: "2026-09-16T19:18:47Z"
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

### Delivery, 2026-09-16: measured; setting kept at 24 (Fable, macOS checkout)

Implemented manually; no scheduled claim. `tests/mac_frame_probe.gd` gained
`--probe-stall=MS`, `--probe-stall-every=S` and `--probe-steps=N`: it
busy-waits the main thread for MS every S seconds and records the frame time
and solver tick count of the 16 frames after each stall.

Apple M4 MacBook, Metal, Standard mountain free ski, five 100 ms stalls per
22 s run, frame ms / solver ticks for the stalled frame and the next three:

| Cap | Stalled frame | +1 | +2 | +3 | Run p99 | Ticks in 4 frames |
| --- | --- | --- | --- | --- | --- | --- |
| 24 (current) | 122-126 / 12-13 | 27-36 / 5-7 | 23-24 / 3 | 25-27 / 3 | 33.2 ms | 24.6 |
| 8 | 118-123 / 8 | 39-45 / 6-7 | 21-23 / 3-4 | 26-27 / 3 | 46.0 ms | 20.4 |
| 6 | 116-118 / 6 | 37-46 / 5-6 | 21-24 / 3-4 | 24-30 / 3-4 | 45.7 ms | 18.2 |

Godot does not save the capped work: the leftover accumulator is carried into
the next frame (and partly dropped, so the race clock slips four to six ticks
per stall at 6-8 steps), the stalled frame shortens by only 4-8 ms, the
following frame lengthens by 10-15 ms and the run p99 rises from 33 to 46 ms.
Four-frame recovery totals are 205 ms (24) versus 209 ms (8 and 6). The
premise that catch-up ticks cascade into further late frames did not hold:
with 24 steps the frame after recovery is already normal. Decision: keep
`max_physics_steps_per_frame=24`; no runtime, replay 7, race 6 or clock change.
[Architecture](../../docs/ARCHITECTURE.md) documents the bound and evidence.
Automated: none required (setting unchanged); the probe artifacts are
`artifacts/mac_probe/stall_{24,8,6}.json` (ignored). Human playtest of stall
feel remains a follow-up, not a gate.

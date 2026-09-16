---
id: "AA-20260916-084501-index-skier-pose-by-bone"
title: "Replace String-keyed skier pose data and per-frame allocations with bone-indexed buffers"
status: ready
priority: P1
depends_on: ["AA-20260913-141128-reduce-pelvis-fitting-cpu-cost"]
created: "2026-09-16T08:45:01Z"
updated: "2026-09-16T15:28:00Z"
source_thread: null
---

# Replace String-keyed skier pose data and per-frame allocations with bone-indexed buffers

## Outcome

Cut the render-frame `pose` scope and the fixed-tick `animation_tick` scope,
the second and third largest scripted CPU costs, while producing the same
skeleton poses, transitions and equipment attachment. The skier must look and
move exactly as today.

## Current state and evidence

- Recorded scopes: `pose` 1,461-1,821 µs mean per rendered frame (p95
  2,186-2,590 µs) and `animation_tick` 890-1,032 µs mean per 120 Hz tick in
  [the rendering baseline](../../docs/RENDERING_BASELINE_RESULTS.json) and
  [the bounded high-speed results](../../docs/CURRENT_V15_BOUNDED_HIGH_SPEED_PERFORMANCE_RESULTS.json).
  Sub-scopes: `pose_pelvis` 318-509, `pose_hierarchy` 182-190,
  `pose_procedural` 168-194, `pose_equipment` 91-95, `animation_posture`
  396-440, `animation_tracking` 270-347, `animation_source_blend` 79-176 µs.
  Together they are about 3 ms of a 13.9 ms dense-forest frame.
- Source inspected at Dev 43 / `a9c2acb` (2026-09-16):
  - [`skier_visual.gd:157-287`](../../scripts/presentation/skier_visual.gd)
    `pose` rebuilds two String-keyed Dictionaries of about 24 joints and
    rotations per frame, `duplicate()`s them, then runs a clearance retry loop
    of up to four complete compose passes (line 212), each calling
    `animation.compose`, `_procedural_limb_rotations`, `full_motion.compose`
    and `_solve_render_legs`. `_solve_render_legs` bisects ten steps per leg,
    each step calling `Anatomy.leg_twist` which concatenates Strings.
  - [`skier_anatomy.gd:29-42, 56-87, 105-109`](../../scripts/presentation/skier_anatomy.gd)
    `local_limit` allocates `["Spine02","Spine01","Spine"]` on every call and
    chains `begins_with`/`ends_with` and `Body.REST[prefix+"ForeArm"]` lookups;
    `hinge_axis`/`elbow_zero` recompute constants from `REST` each call. These
    run per bone per compose pass, per fitting iteration, per arm candidate
    and 24 times per tick in `skier_full_motion.step`, on the order of
    hundreds to two thousand calls per frame.
  - [`skier_full_motion.gd:150-341, 490-562, 575-807`](../../scripts/presentation/skier_full_motion.gd)
    per tick: `state.duplicate()`, a Dictionary per clip in `add`, a fresh
    `Array[Quaternion]` per `sample_raw`, `mirror_pose` doing
    `library.names.find(opposite)` for every bone (O(N²) String compares),
    about 14 `names.find` calls in `fit_tuck_flexion`/`fit_arm_carry`, and
    `Downhill.apply`/`Action.apply`/`PolePose.apply` each doing about 12 more.
    Per frame `compose` duplicates five Dictionaries, iterates `requested_*`
    loops and writes about 15 diagnostics keys.
  - [`pole_push_pose.gd:134-228`](../../scripts/presentation/pole_push_pose.gd)
    `fit_tips` allocates a 12-array result and `anchors.duplicate()` even on
    early return; `connected_arm` evaluates `arm_candidate` ten times per arm.
  - [`skier_pose_writer.gd:3-10`](../../scripts/presentation/skier_pose_writer.gd)
    issues `get_bone_rest`, `affine_inverse` and three separate
    `set_bone_pose_*` calls per bone (about 120 server calls); one
    `Skeleton3D.set_bone_pose(index, Transform3D)` per bone is equivalent.
  - [`skier_animation.gd:70-76`](../../scripts/presentation/skier_animation.gd)
    builds a 25-key Dictionary with `lerpf` per key every frame.
  - `skier_full_motion.gd:337` replaces `diagnostics` every tick while
    `compose` and `skier_visual.gd:238-240` add per-frame keys to the same
    Dictionary, so per-frame keys are wiped each tick (intermittent HUD data).
- Already delivered and not to be redone: immutable clip preparation and arm
  ancestry ([archived animation task](../archive/AA-20260912-105301-reduce-animation-cpu-cost.md)).
  Fitting math (`fit_hips`/`fit_pelvis` iteration structure) belongs to
  [the pelvis fitting task](AA-20260913-141128-reduce-pelvis-fitting-cpu-cost.md);
  this task waits for it to avoid editing the same functions concurrently.
  The [animation cost contract](../../docs/ANIMATION.md#runtime-preparation-and-cost)
  owns pose lifetime rules.

## Agreed decisions and scope

Own `scripts/presentation/skier_visual.gd`, `skier_animation.gd`,
`skier_full_motion.gd`, `skier_anatomy.gd`, `pole_push_pose.gd`,
`action_posture.gd`, `downhill_posture.gd`, `skier_pose_writer.gd` and the
joint/rotation container shape exposed by `scripts/core/rider_body.gd`
(presentation readers currently index by bone name). Preserve every visible
pose, transition, retry/clearance behaviour, equipment attachment and the
existing residual-carve fixes. Do not reduce iteration limits, retry count
semantics or animation cadence to gain FPS; if the retry loop is reduced, it
must be by computing only the changed delta with identical results.

Ghost playback pose application belongs to
[the ten-ghost task](AA-20260912-132147-reduce-ten-ghost-presentation-cost.md);
ghost capture belongs to
[the recording tick task](AA-20260916-084502-reduce-recording-tick-cost.md).
Recorded ghost pose bytes must remain identical.

## Implementation approach

1. Introduce a single bone index table (const ints and a name to index map)
   shared by `RiderBody`, `SkierAnatomy`, `SkierFullMotion` and the pose
   writer. Store joints in `PackedVector3Array` and rotations in
   `Array[Basis]` (or `PackedFloat32Array`) indexed by bone; keep a thin
   name-keyed accessor only for tests and diagnostics.
2. Precompute a per-bone limit descriptor table for `local_limit`
   (kind, bounds, axis, rest bend, zero basis) and per-prefix hinge/elbow
   constants at load. Cache the mirror index map and all `names.find` results.
3. Reuse preallocated quaternion and result buffers in `sample_raw`/blend and
   in `fit_tips`; skip result allocation when `carry_weight <= 0`.
4. Recompose only what the clearance retry changes, or bound the retry to a
   delta pass, only where results are provably identical.
5. Write bones with one `set_bone_pose` per bone; gate diagnostics writes
   behind `frame_costs.enabled` or the debug panel visibility.
6. Compare frozen pose outputs (all bones, both sides, tuck, carve both ways,
   push, flight, landing, grab, crash handoff) before/after under explicit
   tolerances; zero difference is expected for pure re-indexing.

## Acceptance and verification

- [ ] Frozen pose comparison shows identical bone transforms (or documented
  float rearrangement bounds) across the listed poses and both blend weights.
- [ ] `tests/animation_cpu_suite.gd`, `tests/skier_anatomy_suite.gd`,
  `tests/turn_anatomy_suite.gd`, `tests/ski_attachment_suite.gd`,
  `tests/skier_motion_suite.gd`, `tests/skier_animation_suite.gd`,
  `tests/pole_push_pose_suite.gd`, `tests/physics_suite.gd` and
  `tests/runtime_suite.gd` pass; recorded ghost pose bytes unchanged.
- [ ] Rendered inspection of matched native stills and motion through tuck,
  both carves, push, flight/landing and crash handoff, per
  [the animation skill](../../.agents/skills/alpine-animation/SKILL.md).
- [ ] One warmed 15-second capture-free candidate against
  [DENSE_FOREST_BASELINE.json](../../docs/DENSE_FOREST_BASELINE.json) plus a
  `-ProfileFrameCosts` run showing `pose` and `animation_tick` reductions;
  report per-run means, medians, p95/p99 and remaining target gap.
- [ ] Update [Animation](../../docs/ANIMATION.md) container/contract wording,
  commit/push owned paths with a development note and record the Dev ID.

Human acceptance: subjective animation quality remains a separate follow-up,
not a completion gate, because outputs are required to be identical.

## Open questions

None

## Completion record

Adjacent pose optimization delivered 2026-09-16: moved both final ten-iteration
knee searches into the existing native module. Same limits, cadence and final
outputs; portable reference remains. Paired isolated full pose **725.24 ->
615.36 us**, including legs **153.04 -> 44.13 us**. Same-process timed FPS
**94.23 -> 94.29** is unchanged; retained for verified CPU savings, explicitly
confirmed by the user. All 4,000 knee cases and 3,787 pose/equipment snapshots
matched; matched stills and 592 existing regression checks passed. All recorded
channels match the Dev54 timed reference. See
[Performance handoff](../../docs/PERFORMANCE_HANDOFF.md#native-final-knee-search-cpu-saving-no-measured-fps-gain)
for the earlier slower sample and frame-tail limitations. Development note:
`changes/d4c7dbad09084e2784abbe7fb3551ef2.json`.

The indexed-container, writer-call and allocation proposals remain unimplemented;
this task stays ready. Do not repeat the final-knee native port or mistake it
for completing the proposed container rewrite.

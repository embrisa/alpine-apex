---
id: "AA-20260911-183812-slope-limited-pole-pushing"
title: "Add slope-limited pole pushing and a new pushing animation"
status: ready
priority: P2
depends_on: []
created: "2026-09-11T18:38:12Z"
updated: "2026-09-11T18:38:12Z"
source_thread: null
---

# Add slope-limited pole pushing and a new pushing animation

## Outcome

Holding forward lets the skier repeatedly push with the poles to get moving and
cross slow terrain. Pushing can approach 40 km/h on flat ground, but uphill speed
must fall with steepness: steep climbs should be around 5-15 km/h, and extremely
steep slopes must eventually become impossible to climb using poles. Show a
convincing new pushing motion synchronized with the propulsion. Evaluate
Cascadeur for authoring this action without assuming broader tool adoption.

## Current state and evidence

Read-only investigation on 2026-09-11, refreshed at commit
`802408876e82550976ee0263301f5989b6dbb4bd`, found model 28 and no existing pole
propulsion path. Recheck current identities before implementation. No physics,
rendered or performance validation was run during task authoring.

- [input_router.gd](../../scripts/core/input_router.gd) maps W/Up and left-stick
  forward to `tuck`. [rider_input.gd](../../scripts/core/rider_input.gd) carries
  this normalized intent. [ski_simulation.gd](../../scripts/core/ski_simulation.gd)
  computes `effective_tuck` and changes drag; forward currently adds no propulsion.
- Grounded gravity, friction and support are owned by the Node-independent solver.
  [ski_tuning.gd](../../scripts/core/ski_tuning.gd) and
  [ski_default.tres](../../config/ski_default.tres) are the existing tuning path.
  The new propulsion is an intentional physics change, not a pose correction.
- [skier_animation.gd](../../scripts/presentation/skier_animation.gd) and
  [skier_full_motion.gd](../../scripts/presentation/skier_full_motion.gd) advance
  presentation from completed ticks. The latter samples the current motion
  library and applies `Downhill.apply` and `Action.apply`; there is no integrated
  pole-push action. The user explicitly requests a newly authored animation.
  [skier_visual.gd](../../scripts/presentation/skier_visual.gd) fits the result
  to support/equipment, using the sole final
  [skier_pose_writer.gd](../../scripts/presentation/skier_pose_writer.gd).
- The earlier [Cascadeur evaluation handoff](../../docs/tasks/CASCADEUR_WORKFLOW_AND_GAMEPLAY_EVALUATION.md)
  is historical context, not an unfinished prerequisite. The
  [review lessons](../../docs/presentation/ANIMATION_REVIEW_LESSONS.md) document how downstream
  posture fitting largely hid an imported R6 candidate. Verify this new action
  after the full gameplay pipeline, rather than judging export fidelity alone.
- Backlog/archive and `docs/tasks/` inspection found no duplicate pole-pushing
  task. [Carving lean work](AA-20260911-161450-proportional-carving-lean.md) touches
  neighboring presentation code; preserve or coordinate its edits and retest
  transitions. It is not a functional prerequisite.

## Agreed decisions and scope

- The user selected **hold forward to repeat pushes; transition to tuck at higher
  speed**. Releasing forward stops requesting propulsion. Use the existing
  keyboard and controller forward controls; no separate button or automatic
  pushing without input.
- The user clarified that holding forward uphill must not let the skier reach
  the flat-ground 40 km/h pushing speed. Use a smooth, developer-tunable uphill
  speed curve, progressively lower than flat, with steep portions in the
  15, 10 and 5 km/h range. This is game tuning, not a player settings screen.
- The user explicitly chose that **extremely steep slopes eventually become
  impossible to climb**. Fade assistance to zero at a documented uphill cutoff.
  Gravity and existing grip/braking determine stalling or sliding afterward.
- These limits bound speed added or sustained by pole propulsion. Momentum
  carried into an uphill may initially exceed its pushing limit and decays
  naturally; do not clamp existing velocity or add an artificial uphill brake.
  Downhill gravity can still carry the skier beyond 40 km/h.
- Initial scope is forward skiing with a repeatable double-pole plant, push and
  recovery cycle, adapted to slope and speed. Exact slope breakpoints, cadence,
  force and blend thresholds are measured implementation tuning choices. Avoid
  separate skating, herringbone climbing, stamina or equipment-upgrade systems.
- Default eligibility is stable grounded snow support. Braking, crash and loss
  of support cancel propulsion; avoid active pushes during jump preparation,
  switch skiing or strong carving that needs the poles for balance. Preserve
  steering during ordinary low-speed pushes. Do not create airborne propulsion,
  rock-climbing assistance or a force from cosmetic pole intersections.
- Try Cascadeur on a task-owned editable source. Evaluate the complete action in
  gameplay, retain useful source/export files, and record authoring effort and
  shortcomings. No purchase or commitment to replacing the animation library is
  implied. If Cascadeur is unsuitable, record why and use the existing
  Blender/Godot authoring route to finish this action; do not turn tool repair
  into an unbounded prerequisite.

## Implementation approach

1. Read [architecture](../../docs/development/ARCHITECTURE.md),
   [competition boundaries](../../docs/gameplay/ONLINE_COMPETITION.md), and the
   [animation skill](../../.agents/skills/alpine-animation/SKILL.md). Capture
   matched no-push baselines on flat, uphill and downhill fixtures. Keep the
   solver at 120 Hz and terrain authority on the shared 4 m support surface.
2. Interpret existing forward intent as a context-sensitive push/tuck request.
   Keep force eligibility, cycle timing and push phase in the solver. A completed
   tick supplies phase/intensity to presentation; imported root motion,
   AnimationPlayer events and render rate must not drive displacement or forces.
   Introduce a small dedicated propulsion helper only if it clarifies ownership.
3. Compute signed uphill inclination from authoritative support and intended
   forward push direction, not camera direction or the mountain's steepest
   gradient alone. A cross-slope traverse should reflect the grade actually
   being climbed. Use grounded tangential speed to prevent high sideways speed
   or backward sliding from bypassing eligibility. Define stationary/rollback
   behavior explicitly; never use the cap as a target-velocity assignment.
4. Add bounded tangential push force during the power phase, with recovery
   between strokes. Tune force and resistance together so representative steep
   slopes actually permit the specified slow ascent: merely lowering a cap is
   insufficient if the skier cannot overcome gravity. Taper propulsion near
   the speed limit and steepness cutoff; avoid chatter and threshold boosts.
   No lift, normal-force boost, adhesion or permanent world-anchored pole joint.
5. Blend to ordinary skiing/tuck as propulsion fades. Preserve existing tuck
   opening for steering/braking and the airborne neutral-center input gate.
   Clear/freeze/reconstruct push state correctly on restart, pause/resume,
   departure, crash and replay. Trace
   [run_session.gd](../../scripts/core/run_session.gd) and
   [run_replay.gd](../../scripts/racing/run_replay.gd): retain enough recorded
   state to reproduce push presentation, update tuning fingerprints, and bump
   model/replay identities as required. Reject incompatible records without
   legacy migration work.
6. Author one editable double-pole cycle with visible reach, plant, loaded
   backward push, release and recovery. Let that action own the needed torso/arm
   channels so downstream tuck corrections do not erase it. Fit visible pole
   tips to the authoritative slope with bounded cosmetic adaptation; do not
   alter physical skis/contact to rescue an impossible pose. Keep fixed grips,
   connected arms, rigid poles/boots and the existing final skeleton writer.
   Inspect transitions, planted-tip sliding, clothing collisions and full shafts.
7. Document the final curve (degrees and km/h), force/cadence, action ownership,
   controls, Cascadeur decision and measured limitations in maintained subsystem
   documentation. Follow the [engine strategy](../../docs/development/ENGINE_STRATEGY.md)
   for bounded tick work; no unrelated performance rewrite is needed.

## Acceptance and verification

- [ ] Automated fixtures demonstrate repeated forward-held propulsion from rest,
  cessation on release/brake, smooth push-to-tuck transition and no pushing at or
  above the applicable limit. Flat pushing approaches 40 km/h without exceeding
  it through propulsion; downhill gravity remains unrestricted.
- [ ] Measured steady-state ascent is progressively slower uphill, includes
  representative 5-15 km/h steep climbs, and cannot be sustained above the chosen
  cutoff. Record chosen slope angles, observed speeds and tolerances, including
  samples around breakpoints. Check traverses, rollback, rough support, crest
  transitions and high-momentum entry without abrupt velocity clamping.
- [ ] No propulsion while unsupported/crashed or in excluded actions/materials;
  no changed airborne trajectory. Tick repeatability, restart, pause/resume and
  replay preserve the action. Run guarded `./godotw --headless --script
  tests/physics_suite.gd` and `tests/runtime_suite.gd`, plus focused propulsion,
  input, replay and affected animation/equipment regression checks. Use the
  validation guard serially and wait for existing owners of the lock.
- [ ] Render and inspect complete chronological plant/push/recovery cycles and
  transitions on flat, gentle uphill, steep uphill, cutoff and downhill terrain,
  including left/right steering, braking and departure. Use the maintained
  [pose-review workflow](../../docs/presentation/ANIMATION_AGENT_WORKFLOW.md), fresh frozen
  evidence, gameplay and side/front views. Demonstrate force/phase alignment,
  source survival through final fitting, stable grips/boots and credible pole
  contact without new conspicuous clothing intersections.
- [ ] Report Cascadeur source/edit/export results separately from final gameplay
  motion quality. A rejected Cascadeur route is valid; an unfinished or hidden
  animation does not complete the gameplay feature.
- [ ] Measure affected solver/animation cost and matched rendered gameplay on the
  target PC at 3840x2160 output, High, documenting render scale, rendered FPS,
  p95/p99, CPU/GPU timing and memory. Keep generated frames separate. For a full
  mountain check use cached seed 849205174 / v15 Standard; do not claim a
  headless pass or contended run establishes gameplay performance.
- [ ] Update controls/physics/animation documentation, preserve asset imports and
  UIDs, validate the backlog, and commit/push coherent source-plus-asset milestones
  to `main`. Respect the existing $5/month LFS limit. Keep generated evidence and
  caches out of commits according to repository policy.

Human acceptance: actual controller feel, uphill tuning and visual approval are
separate follow-ups, not implementation dispatch or worker completion gates.
Provide clear playable review instructions and mark these pending until the user
tries the result. Worker completion requires the planned automated and rendered
evidence and a working integrated animation; tests cannot substitute for either.

## Open questions

None.

## Completion record

Pending implementation. Record actual results, source/engine identities, selected
slope curve, animation source/tool decision, evidence locations, performance,
remaining human acceptance, documentation and commit/push references. Record a
real blocker and unfinished work if implementation cannot complete. No separate
follow-up ideas were proposed during authoring.

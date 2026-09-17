---
id: "AA-20260911-183812-slope-limited-pole-pushing"
title: "Add slope-limited pole pushing and a new pushing animation"
status: done
priority: P2
depends_on: []
created: "2026-09-11T18:38:12Z"
updated: "2026-09-17T22:05:00Z"
source_thread: null
---

# Add slope-limited pole pushing and a new pushing animation

## Completion - 17 September 2026

Implemented and visually approved. The final Dev103 motion is retained; this
closure changes only cost tooling and its evidence contract. Completed current
11-case chronology, clothing-audit review and native4K cost qualification are
reconciled in `artifacts/pole_feature_closure/CLOSURE.md`.

- Model35 propulsion:108 checks. Measured steady means at0/10/20/28/34 degrees:
  37.82/27.31/14.99/10.31/6.49km/h; zero powered ticks at42 degrees. The named
  lifecycle/exclusion/replay cases pass. Physics56/runtime192 receipts are reused
  for unchanged owners; current pose/contact and equipment regressions pass.
- All9900 native poses and eleven15-second videos completed. Max joint step
  13.164cm remains below14cm. Actual-clothing audit flags90 frames:88 ordinary
  tuck/preparation,2 brief release frames; none during powered or state-active
  pushing. The actual images were reviewed. Keep the approved motion under the
  user's accepted small visual differences; do not call the audit zero-contact.
- Local perf-mixed at4K High, Auto75%, FSR4.1.1, FG off: feature Off186.13FPS /
  5.373ms; On188.49FPS /5.305ms. On frame p95/p99 are7.240/8.452ms, GPU mean
  4.522ms. Direct pole actuator23.88us/tick, full animation449.29us/tick and
  final pose732.84us/presentation. All720 ticks, reference final position/velocity and native timing gates pass.
  Same inputs intentionally travel farther with propulsion, so these are local
  workload/cost observations, not an isolated FPS gain or mountain baseline.
- Editable Blender/JSON/TRES and export provenance shipped with Dev103.
  Controls, physics, animation and source ownership are documented. No source
  retuning, production settings or gameplay compatibility change in closure.

Controller feel and subjective uphill tuning remain human follow-ups. Hold
forward from rest; release/brake; repeat uphill and near the speed cap. Visual
approval is already supplied. Detailed evidence retains the rejected sparse
clearance comparisons; no clearance-only performance claim is made.

## Outcome

Holding forward lets the skier repeatedly push with the poles to get moving and
cross slow terrain. Pushing can approach 40 km/h on flat ground, but uphill speed
must fall with steepness: steep climbs should be around 5-15 km/h, and extremely
steep slopes must eventually become impossible to climb using poles. Show a
convincing new pushing motion synchronized with the propulsion, authored through
the existing Blender/Godot route.

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
- Author the action through the existing Blender/Godot route on a task-owned
  editable source. Retain useful source/export files and evaluate the complete
  action in gameplay. The user's 2026-09-12 tool-removal decision supersedes the
  earlier external-authoring trial requirement; do not reintroduce it as a
  prerequisite for this feature.

## Acceptance and verification

- [x] Automated fixtures demonstrate repeated forward-held propulsion from rest,
  cessation on release/brake, smooth push-to-tuck transition and no pushing at or
  above the applicable limit. Flat pushing approaches 40 km/h without exceeding
  it through propulsion; downhill gravity remains unrestricted.
- [x] Measured steady-state ascent is progressively slower uphill, includes
  representative 5-15 km/h steep climbs, and cannot be sustained above the chosen
  cutoff. Record chosen slope angles, observed speeds and tolerances, including
  samples around breakpoints. Check traverses, rollback, rough support, crest
  transitions and high-momentum entry without abrupt velocity clamping.
- [x] No propulsion while unsupported/crashed or in excluded actions/materials;
  no changed airborne trajectory. Tick repeatability, restart, pause/resume and
  replay preserve the action. Run guarded `./godotw --headless --script
  tests/physics_suite.gd` and `tests/runtime_suite.gd`, plus focused propulsion,
  input, replay and affected animation/equipment regression checks. Use the
  validation guard serially and wait for existing owners of the lock.
- [x] Render and inspect complete chronological plant/push/recovery cycles and
  transitions on flat, gentle uphill, steep uphill, cutoff and downhill terrain,
  including left/right steering, braking and departure. Use the maintained
  [pose-review workflow](../../docs/ANIMATION.md#production-pipeline), fresh frozen
  evidence, gameplay and side/front views. Demonstrate force/phase alignment,
  source survival through final fitting, stable grips/boots and credible pole
  contact without new conspicuous clothing intersections.
- [x] Retain editable source and export provenance, and report final gameplay
  motion quality. An unfinished animation or a source shape hidden by downstream
  fitting does not complete the gameplay feature.
- [x] Measure affected solver/animation cost and matched rendered gameplay on the
  target PC at 3840x2160 output, High, documenting render scale, rendered FPS,
  p95/p99, CPU/GPU timing and memory. Keep generated frames separate. For a full
  mountain check use a current compatible cached Standard fixture (generator18 at closure); do not claim a
  headless pass or contended run establishes gameplay performance.
- [x] Update controls/physics/animation documentation, preserve asset imports and
  UIDs, validate the backlog, and commit/push coherent source-plus-asset milestones
  to `main`. Respect the existing $5/month LFS limit. Keep generated evidence and
  caches out of commits according to repository policy.

Human acceptance: actual controller feel, uphill tuning and visual approval are
separate follow-ups, not implementation dispatch or worker completion gates.
Provide clear playable review instructions and mark these pending until the user
tries the result. Worker completion requires the planned automated and rendered
evidence and a working integrated animation; tests cannot substitute for either.

## Delivery

Final verification and push are recorded in `changes/057d6abfbc22445dac66c460e56115e6.json`.

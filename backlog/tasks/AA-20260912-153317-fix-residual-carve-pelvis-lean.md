---
id: "AA-20260912-153317-fix-residual-carve-pelvis-lean"
title: "Fix sideways pelvis and deep body lean after weak or released turns"
status: ready
priority: P2
depends_on: ["AA-20260912-105301-reduce-animation-cpu-cost"]
created: "2026-09-12T15:33:17Z"
updated: "2026-09-12T15:33:17Z"
source_thread: "01a0960f-732c-73f3-a61c-5eef64ebab21"
---

# Fix sideways pelvis and deep body lean after weak or released turns

## Outcome

The skier should make small, proportionate body movements for small path
corrections and return smoothly toward a neutral stance when a turn fades.
The user reports that the skier sometimes visually carves very hard and pushes
the pelvis far sideways while physically steering very little. Preserve deep,
readable carving during genuinely strong loaded turns in both directions.

Fix the demonstrated residual stance and investigate whether the same cause
also explains fresh slight-input cases. A nicer transition alone does not close
the task if the exaggerated held/released pose remains.

## Current state and evidence

Observed during [animation CPU optimization](AA-20260912-105301-reduce-animation-cpu-cost.md),
implemented at `50a5c83` with completion record `ef43412`. Authoring inspected
`14a4397` on 2026-09-12; its only later changes are three unrelated UID files.
Physics model 29, Godot 4.7.2 custom `ed1daf0bf`. No new engine run or fix was
performed during this authoring turn; the evidence below was already captured
in this conversation and has now been copied and hash-verified for retention.

The focused analytic probe covers 12 cases at 25/40 m/s initial speed, both
directions, 5/10% holds and 55% reversals. Slope is `height = -0.30*z`, zero
cross-gradient, no tuck. Warm up 240 unsteered ticks at 120 Hz, then measure
420 ticks: direction × 0.55 for ticks 0–89, opposite for 90–179, zero from 180.
Trace ticks are zero-based measured ticks; telemetry is retained every two ticks.

Representative retained row: 25 m/s, initial direction -1, tick 273 (0.783 s
after release), input 0, path lateral acceleration 0.187613 m/s², action weight
0.008525, torso lean 0.350845 degrees, physical bank 0.953400 radians,
supported-edge channel 1.0, final body lean 26.562452 degrees, lateral pelvis
offset 0.400458 m. Body/torso/pelvis are measured in the gravity/heading frame,
relative to the midpoint of the feet, not a camera-relative silhouette.

The largest absolute body lean after tick 240 with |path acceleration| < 0.5
m/s² in each reversal is:

| Initial speed / direction | Tick | Body degrees | Pelvis metres | Path acceleration m/s² | Bank radians | Action weight |
|---|---:|---:|---:|---:|---:|---:|
| 25 m/s / -1 | 267 | +27.260 | +0.393 | +0.189 | +1.052 | 0.015 |
| 25 m/s / +1 | 263 | -26.059 | -0.362 | -0.187 | -1.084 | 0.021 |
| 40 m/s / -1 | 251 | +28.601 | +0.413 | +0.194 | +1.068 | 0.049 |
| 40 m/s / +1 | 247 | -28.267 | -0.404 | -0.251 | -1.117 | 0.068 |

These cases contain 30/30/25/24 residual-support samples at 60 Hz. The probe's
60 passing checks **do not establish that this defect is fixed**: its existing
settling check permits large whole-body lean while supported edge stays high.
Mild 5/10% holds mostly remain proportional; preserve that improvement.

Relevant verified owners:

- [RiderBody](../../scripts/core/rider_body.gd), balance `step`: requested lateral
  force/turn anticipation, target bank, support-limited centre of pressure and
  torque integration. Trace why the bank persists after curvature fades.
- [SkiSimulation](../../scripts/core/ski_simulation.gd), steering transfer and
  per-ski motors: a ski's edge goal is constrained near negative body bank
  (`clampf(edge_angle, -bank-.10, -bank+.10)`), then rate-limited. Trace this
  coupling and actual load/slip before selecting a correction.
- [SkierFullMotion](../../scripts/presentation/skier_full_motion.gd), `step`,
  `supported_turn`, `compose`; [SkierVisual](../../scripts/presentation/skier_visual.gd),
  final leg solving; [SkierAnatomy](../../scripts/presentation/skier_anatomy.gd),
  `fit_pelvis`: rigid-cuff flex, hinge planes and leg reach can force a large
  lateral pelvis shift despite a nearly neutral requested upper-body pose.
- [Animation: Carving](../../docs/ANIMATION.md#carving) owns the existing
  residual-bank finding. The [retired proportional-lean task](../archive/AA-20260911-161450-proportional-carving-lean.md)
  contains earlier direction/strength work; this task targets the unresolved
  residual stance, without reopening or relabelling that historical task.

The measured correlation and current constraint chain support the diagnosis;
the exact balance/edge feedback mechanism still needs a causal probe. Do not
assume all slight-input reports have the same cause.

### Preserved evidence

Dedicated local package: `artifacts/pelvis_residual/20260912-baseline/`.
It preserves 654 original files / 97,213,663 bytes: complete diagnostic JSON and
script, both reversal sequences in chase/front/side (630 JPEGs), phase sheets,
native report/capture script, relevant source snapshots and optimization
provenance. Copies were verified byte-for-byte. `manifest.json` lists SHA256,
source path and size for every copied file; `summary.json` preserves the exact
selected rows. Core measurements above are committed in this task so they
remain available independently of the ignored artifact folder.

- Manifest SHA256: `c6d4851c49bbd3bb32de33f9c24e1490a8fb70e9d1dbc3ae4ee59d65ac041d6d`.
- Diagnostic JSON SHA256: `534565d1be7ea6e1864125862b5ef1c2a3291c4dac6e86d832c8ab29d1732c5a`.
- Probe script SHA256: `2ab2719e62967b111e6b6e3cca3580672030b665eebca2884ad75cb9a332b07e`.
- Engine worker SHA256: `a18ddc9f3ee8fa1915a47d54c3e0d05ec4b10f8ee9deb15d7206b4e23d29bcc9`.

The native images are separate 3.5-second current-v15 production cases at
1280×900 / 30 Hz. They show the visual failure through reversal but **are not
images of analytic tick 273**. Keep their timelines and provenance distinct.
Retain this package and original animation evidence until a reviewed replacement
baseline exists; do not run broad artifact cleanup over unresolved evidence.
If local outputs are missing, reproduce from the committed source identity and
fixture specification rather than inventing or relabelling evidence.

## Agreed decisions and scope

The user requested this backlog item and preservation of the evidence. They
explicitly selected **targeted edging/stance physics adjustment with physics
and handling checks** if needed. Diagnose and fix the first responsible stage;
the scope includes balance/edge release and presentation fitting as justified.

The user's prior animation authority continues: poses need not match exactly;
cheaper or visually better poses and transition clips are permitted. Blender
Animation MCP may be used when asset authoring helps. A transition clip is an
option, not a predetermined solution to a sustained physical constraint.

Keep the Node-independent 120 Hz solver and shared 4 m terrain authority. Use
explicit supported forces, pressure, motor and anatomical constraints. No
animation-driven movement, path attraction, teleporting the pelvis or skis,
arbitrary velocity/heading clamps, disconnected cuffs/grips or stretched limbs.
Do not weaken valid anatomy constraints merely to conceal an unsuitable stance.
Preserve manual steering responsiveness, strong carve capability, momentum,
reversal control, neutral glide, tuck, snow/rock distinctions and flight/landing.

Targeted physics changes may intentionally change trajectories; record those
changes and follow current model/recording identity rules, regenerating
incompatible fixtures rather than adding compatibility shims. Keep presentation
read-only and replay deterministic for the resulting model. Retain the validated
animation CPU improvements. No broad skiing-model rewrite or unrelated tuning.

Authoring does not implement or dispatch. Priority P2 follows the normal bug
default. The completed CPU task is the baseline dependency; other graphics work
is not an artificial prerequisite. Coordinate overlapping owners during execution.

## Implementation approach

1. Use the [animation skill](../../.agents/skills/alpine-animation/SKILL.md),
   [Physics](../../docs/PHYSICS.md), [Architecture](../../docs/ARCHITECTURE.md)
   and [Validation](../../docs/VALIDATION.md). Verify current source/engine and
   preserve new matched baselines before changing code.
2. Reproduce the compact 12-case probe, then trace requested/applied steering,
   slip, path acceleration, balance target/actual bank and rate, requested/actual
   centre of pressure, support force, load shares, per-ski edge target/actual,
   source/requested/final pelvis and limb constraint corrections. Identify where
   the residual persists; distinguish necessary weight transfer from a stuck or
   excessively slow feedback response.
3. Add a focused regression that fails for the retained excessive residual.
   Measure body and pelvis separately from the upright torso. Use the existing
   12-degree mild whole-body envelope as a starting reference; define justified
   pelvis-offset and settling-time bounds from the neutral control and reachable
   anatomy before tuning the candidate. Do not exempt the observed defect simply
   because edge remains saturated. Retain natural transient counterbalance.
4. Correct the narrowest demonstrated owner. If adjusting the balance/edge
   coupling, retain support and bounded torque/cuff response during transfer.
   If changing poses/transition clips, show that they improve the final connected
   stance and do not merely cancel a still-invalid upstream state.
5. Verify mirrored mild holds/taps, release/reversal and strong holds at low and
   high speed, flat/mirrored cross-slopes, tuck and uneven snow support. Include
   neutral/braking, rock, support loss, takeoff and landing regressions. Compare
   handling and path changes explicitly when physics is adjusted.

Preserved compact probe (from repository root; choose a fresh output and label
for each execution, never overwrite the package):

```powershell
./scripts/run_guarded.ps1 -FilePath ./godotw.ps1 -Arguments @('--headless','--script','artifacts/pelvis_residual/20260912-baseline/diagnostic/reproduce.gd','--','--output=artifacts/pelvis_residual/worker-before/diagnostic.json') -Label pelvis-residual-before -TimeoutSeconds 600
```

The probe intentionally retains the old permissive assertions for reproduction;
the worker must add the defect-detecting regression. Existing maintained
`tests/carve_proportional_suite.gd` and `tests/carve_direction_playtest.gd --
--proportional` cover broader controls and rendered fixtures. The preserved
native capture script records the original method and output paths; copy/adapt
it to fresh outputs and cached current mountain loading before running it.

## Acceptance and verification

- [ ] The retained low-curvature reversal failure is reproducible before the
  change and rejected by a focused regression. Both 25/40 m/s mirrored cases
  settle their pelvis/body within declared neutral-relative and temporal bounds
  without retaining the observed ~26–29 degrees / 0.36–0.41 m sideways stance.
  Report peak residual, duration, settling time and source/requested/final values.
- [ ] Slight held inputs and 50/150 ms taps remain subtle; real sustained loaded
  55/100% turns retain strong lean and control. Direction, reversal response and
  supported transition behavior remain correct across mirrored slopes and speeds.
- [ ] Inspect complete relevant entry/hold/reversal/release chronology and
  neighboring tuck/hop/landing phases in native chase and anatomical views,
  with world-up measurements and all equipment visible where relevant. Verify
  cuff/limb limits, connected skis/grips, clothing clearance and no new snaps.
  Matched controls/cameras are required; physics differences must be reported,
  not masked by demanding obsolete trajectory equality after an authorized fix.
- [ ] Run the focused residual regression and current carve response/entry/
  proportional, animation/motion/anatomy, attachment, pole, landing and ghost/
  replay checks relevant to changed owners. Run `tests/physics_suite.gd` and
  `tests/runtime_suite.gd` via `./godotw --headless --script ...` for physics,
  input or session edits. Reproduce pre-existing failures on the before source;
  do not relax assertions to hide new failures.
- [ ] Preserve deterministic physics/recording in the new model, presentation
  isolation, fixed clocks and test-store isolation. For physical changes, compare
  actual turn radius/yaw, speed loss, stopping/settling and contact/impact behavior
  on matched inputs; document intentional differences and remaining risks.
- [ ] Use the serial validation guard and short bounded probes; production
  performance checks use independently warmed, capture-free 15–30 second
  sections. Compare three before/after runs for animation/pose cost and rendered
  frame p95/p99 if the implementation changes those costs. Do not sacrifice the
  retained optimization or claim whole-route FPS from a local sample.
- [ ] Update the owning Animation/Physics guide with the resolved mechanism and
  remaining limitations. Preserve this evidence until a reviewed replacement is
  retained, link exact source/engine identities, and commit/push the validated
  fix with its tests/assets and completion record.

Human acceptance: the user's visual preference, controller comfort and skiing
feel remain separately pending follow-up, not a worker-completion gate. Required
automated, rendered and bounded handling/performance evidence above is a worker
gate; passing the current permissive probe alone cannot close this task.

## Open questions

None

## Completion record

Pending implementation. Record the demonstrated root cause, changed owners,
before/after evidence, any intentional physical/model changes, actual checks,
rendered and handling results, remaining human acceptance, guide updates and
commit/push references. If blocked, record the concrete cause and remaining
work. Link separate proposals in `backlog/ideas/`, or state that none were made;
they require user selection before authoring new tasks.

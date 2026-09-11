# Connected skier articulation

Latest follow-up: [R4 tuck alignment](DOWNHILL_TUCK_ALIGNMENT_R4.md), refining
[R3 hands and poles](DOWNHILL_POLE_CORRECTION_R3.md). Reusable validation lessons
are recorded in [Animation review lessons](ANIMATION_REVIEW_LESSONS.md).
The earlier [binding and cuff correction](BOOT_POSTURE_CORRECTION.md) remains the equipment baseline.

The user's gameplay review rejected the first full-curve integration as rubbery.
Its bone-length and cuff-position checks were insufficient: independent global
rotation blending, unconstrained axial twist, and forced grab reach could retain
correct lengths while producing implausible articulation. The old visual
acceptance in `STEEP_MOTION_GAMEPLAY.md` is superseded by this correction.

`skier_anatomy.gd` defines an authored skiing pose envelope in the calibrated
model axes. The 33 original retargeted clips and existing weighted mesh remain
unchanged. Local source curves still drive posture; limits apply before pose
tracking and during final hierarchical composition. These are game pose limits,
not a claim to reproduce every human joint's range.

- Elbows and knees use calibrated hinge planes. Final fitting reconstructs both
  connected segment frames, eliminating independent thigh/shin twist.
- Each spinal link permits up to 20 degrees forward bend, 8 degrees backward or
  lateral bend, and 10 degrees twist. Neck and head have separate axis limits.
- Clavicle motion, shoulder swing/twist, and wrist swing/twist are bounded.
  The ordinary wrist envelope is 28 degrees swing and 55 degrees axial rotation.
  Other source tuck/preparation contributions permit 80 degrees swing and
  90 degrees axial rotation. R3's downhill contribution instead uses ForeArm
  for axial rotation and an 80/30-degree wrist envelope; steering releases it.
  Presentation cuffs permit 24 degrees forward
  shin flexion, fitted by moving the shared pelvis while preserving both lengths.
- Shared pelvis fitting respects both rigid cuffs, minimum leg reach, and the
  knee planes. Native knee-plane expression can use only the remaining cuff and
  tibial rotation range (18 degrees), with no ski movement or limb stretching.
- Procedural/full-curve F8 transitions share the joint contract. The limit stage
  remains present at zero source weight, avoiding a discontinuous handover.
- Grab accommodation distributes limited hip/spine/clavicle motion. The old
  single-link correction of up to 80 degrees is removed. The glove grip point,
  rather than the wrist joint, approaches a fixed target ahead of the binding.
  Unreachable targets remain a reach; they never override joint stops. The
  contact diagnostic fades with actual glove-to-target distance.

The retained fixed fingers and physical air-ski ownership limit grab fidelity.
This correction deliberately replaces the previous forced 4 mm wrist-to-target
assertion with a reported glove reach gap plus independent anatomical limits.
It does not certify finger contact with the ski mesh. Boots and poles retain
their existing strict attachment checks.

Physics/model 19, replay 4, assistance, tuning, terrain and physical equipment
authority are unchanged. Source hashes are recorded in
`artifacts/skier_anatomy/physics_before.json` and verified after validation.

## Validation

Run Godot work through `scripts/run_guarded.ps1`. The regression batch is
`scripts/validate_skier_anatomy.ps1`; `tests/skier_anatomy_suite.gd` extends the
real 120 Hz simulation and final production skeleton writer tests. It inspects
final hinge axes, knee/elbow bend, tibial twist, wrist and spinal limits across
interpolation, rapid steering, tuck, jumps, grabs/re-entry, flips and F8 changes.

Native production v13 captures use `tests/steep_motion_gameplay.gd` with
`--evidence=skier_anatomy`. The isolated 4K High paired run uses
`scripts/measure_steep_motion.ps1 -Timing -Evidence skier_anatomy` under the guard.
Evidence includes physical trajectories, local pose traces, source hashes,
3840x2160 pixel verification, CPU/GPU times and p95/p99 frame times.

Automated limits, rendered review, performance results and the user's skiing
acceptance are distinct. Passing the first three does not substitute for the
user’s assessment of the corrected feel.


### Results, 2026-09-08

- **Automated:** all eight suites passed (1,287 checks); the anatomical suite
  inspected 18,240 final poses. Instrumentation includes the anatomy fitter:
  peak 45 pelvis-IK iterations per pose, within the existing 192-iteration cap.
- **Rendered:** 18 production v13 scenarios, 70 seconds in both chase and side
  views. The independent recorded-pose audit found no joint-limit violations.
  World identity and every recorded physical/orientation sample exactly match
  the rejected integration. Side and chronological chase frames were reviewed.
- **Observed bounds:** native shin twist at most 18.0 degrees, wrist swing 26.49
  degrees, wrist axial rotation 50.61 degrees. Knee and elbow off-axis rotation
  remained below the audit's 0.12-degree tolerance. No physics/tuning/replay
  changes were found across the 16 saved source hashes.
- **Performance:** actual 3840x2160, High, 75% FSR2 (2880x1620 internal), 120 FPS
  cap, D3D12 on RX 9070; WoW closed. The paired 29-second routes used frozen
  sources. Procedural comparison: 118.25 FPS, p95/p99 8.72/10.01 ms. Full curves:
  **118.48 FPS, p95/p99 8.85/11.34 ms**. Average CPU/GPU rendering was 1.00/6.31 ms;
  complete character pose averaged 0.827 ms (p99 1.467 ms), and the fixed-tick
  sampler averaged 0.229 ms (p99 0.494 ms). Peak job private allocation was
  8.05 GiB; engine video allocation was 5.11 GiB. The 80.33 ms maximum includes
  fixture cuts. This short route does not certify a full-mountain FPS floor.
- **Limitations:** tested glove-to-grab-target gaps remain below 4 cm; actual
  finger-to-ski mesh contact is not certified. User acceptance of the revised
  skiing feel is still separate.

Artifacts: `artifacts/skier_anatomy/delivery.json`, `native-anatomy-audit.json`,
`source-freeze-timing.json`, `corrected-gameplay.mp4`, chronological sequence
sheets, `regression/`, and the original rejected source copies in `baseline/`.

## Deep tuck correction

The user subsequently rejected the deep tuck: the hands and poles spread too
widely and the torso did not fold forward enough. The previous limit checks
did not test that silhouette. This correction retains those joint envelopes.

The rig's almost straight rest forearm has a small modelling offset. Taking its
cross product with the upper arm as the elbow hinge tilted that hinge by about
30 degrees, turning a folded forearm outwards. The hinge now uses anatomical
forward with a fixed rest calibration. Wrist pronation remains separate.

Before the existing 120 Hz pose tracker, `fit_tuck_flexion()` distributes the
source's excess lumbar forward bend into bounded hip and upper-spine flexion.
It also reduces outward upper-arm spread and gathers the gloves through bounded
humeral rotation. The full source curves still animate the pose; preparation
and flight fade this adjustment out. The final writer continues to enforce
bone lengths, rigid bindings and local joint limits.

Grab fitting accounts for the calibrated glove's orientation. Torso reach uses
the wrist target and applies its reach demand once; the glove aims at the grip
within the existing wrist stops. This avoids sacrificing existing grab reach
when correcting the elbow hinge.

`tests/deep_tuck_suite.gd` adds silhouette and control-transition assertions to
the anatomical suite. It covers complete source loops, partial/full tuck,
release/re-entry, full-stick reversals, switch and tuck-to-hop preparation, all
through the actual simulation and final skeleton writer. Run the guarded batch
with `scripts/validate_skier_anatomy.ps1 -Evidence deep_tuck -DeepTuck`.
Native production captures use `tests/steep_motion_gameplay.gd -- --tuck-review
--evidence=deep_tuck`; the separate Python audit reads their final joint frames.

At the matched three-second plane sample, chest forward pitch changed from
65.44 to 92.26 degrees, hand span from 71.70 to 35.73 cm, and elbow span from
57.38 to 42.54 cm. These are support-relative pose measurements; they are not
world-space tilt or a substitute for rendered review. The original retargeted
library, mesh, physics, assistance and replay remain unchanged.

### Tuck validation

- **Automated:** all eight suites passed, 1,306 checks. The expanded anatomical
  suite inspected 33,360 final poses. Settled straight-tuck chest pitch remained
  91.22–92.86 degrees; hand span 32.85–39.28 cm. Safety/Mute glove reach remained
  within 3.35 cm without relaxing joint stops. The pose budget still peaked at
  45 pelvis-IK iterations. Physics/model 19 and replay 4 remain unchanged.
- **Rendered gameplay:** six production v13 scenarios, 21 seconds recorded at
  30 FPS in side, front and chase views: deep tuck, release/return, tuck turns,
  switch tuck, Safety and Mute. Chronological side/front sequences were reviewed.
  The straight route includes a natural departure near its end; airborne arm
  opening is the flight transition, not a change in the held grounded tuck.
- **Recorded-pose audit:** 630 production poses, no joint-limit violations.
  Settled supported tuck had 91.78–92.79 degrees chest pitch, 33.17–39.16 cm
  glove span and 41.29–43.14 cm elbow span. Every matched recorded physical
  trajectory/orientation and world identity remained identical. All 16 saved
  physics/tuning/replay source hashes and the native capture source hashes match.
- **User skiing acceptance:** still separate from these automated and rendered
  checks; the previous user rejection motivated the added silhouette tests.

The final isolated 4K High timing pair used 75% FSR2, a 120 FPS cap, D3D12 on
RX 9070, 443 frozen source files and seven matched fixtures (29 seconds each).
Procedural comparison averaged 118.32 FPS, p95/p99 9.08/10.17 ms. Corrected full
curves averaged **117.85 FPS**, p95/p99 **9.25/11.37 ms**; CPU/GPU rendering
averaged 1.29/5.51 ms. The complete character pose averaged 0.927 ms (p99 1.644
ms), and the fixed-tick sampler averaged 0.276 ms (p99 0.631 ms). Engine video
allocation peaked at 5.11 GiB. The 101.74 ms maximum frame is retained in the
report; this short fixture run does not establish a full-mountain FPS floor.
No other Godot, Blender or WoW rendering workload was active during the pair.
The process peaked at 8.05 GiB private allocation.

Evidence: `artifacts/deep_tuck/deep-tuck-gameplay.mp4`, `before-after.jpg`,
`native-audit.json`, `silhouette.json`, `pose-comparison.json`, `physics-after.json`,
the regression logs and chronological `review/` sheets. The baseline probe uses
isolated copies of the rejected presentation scripts; no live source rollback
was used to obtain the comparison.

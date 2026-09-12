---
id: "AA-20260912-153317-fix-residual-carve-pelvis-lean"
title: "Fix sideways pelvis and deep body lean after weak or released turns"
status: done
priority: P2
depends_on: ["AA-20260912-105301-reduce-animation-cpu-cost"]
created: "2026-09-12T15:33:17Z"
updated: "2026-09-12T21:09:31Z"
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

- [x] The retained low-curvature reversal failure is reproducible before the
  change and rejected by a focused regression. Both 25/40 m/s mirrored cases
  settle their pelvis/body within declared neutral-relative and temporal bounds
  without retaining the observed ~26–29 degrees / 0.36–0.41 m sideways stance.
  Report peak residual, duration, settling time and source/requested/final values.
- [x] Slight held inputs and 50/150 ms taps remain subtle; real sustained loaded
  55/100% turns retain strong lean and control. Direction, reversal response and
  supported transition behavior remain correct across mirrored slopes and speeds.
- [x] Inspect complete relevant entry/hold/reversal/release chronology and
  neighboring tuck/hop/landing phases in native chase and anatomical views,
  with world-up measurements and all equipment visible where relevant. Verify
  cuff/limb limits, connected skis/grips, clothing clearance and no new snaps.
  Matched controls/cameras are required; physics differences must be reported,
  not masked by demanding obsolete trajectory equality after an authorized fix.
- [x] Run the focused residual regression and current carve response/entry/
  proportional, animation/motion/anatomy, attachment, pole, landing and ghost/
  replay checks relevant to changed owners. Run `tests/physics_suite.gd` and
  `tests/runtime_suite.gd` via `./godotw --headless --script ...` for physics,
  input or session edits. Reproduce pre-existing failures on the before source;
  do not relax assertions to hide new failures.
- [x] Preserve deterministic physics/recording in the new model, presentation
  isolation, fixed clocks and test-store isolation. For physical changes, compare
  actual turn radius/yaw, speed loss, stopping/settling and contact/impact behavior
  on matched inputs; document intentional differences and remaining risks.
- [x] Use the serial validation guard and short bounded probes; production
  performance checks use independently warmed, capture-free 15–30 second
  sections. Compare three before/after runs for animation/pose cost and rendered
  frame p95/p99 if the implementation changes those costs. Do not sacrifice the
  retained optimization or claim whole-route FPS from a local sample.
- [x] Update the owning Animation/Physics guide with the resolved mechanism and
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

Completed manually; no scheduled claim or downstream dispatch. Implementation,
regression/capture fixtures and owning guides committed and pushed to `main` as
**ee917a8**. Baseline production source is `0594a9b`; intervening `654c18c` only
adds another task's rock performance fixture/documentation. Physics model is now
30; replay format 7, input width 9 and race schema 6 remain unchanged. Existing
compatibility checks reject model 29 recordings. Engine identity matches the
preserved worker SHA256 above. No assets or production presentation code changed.

**Cause and correction:** the bank-following edge-goal restriction kept the boots
deeply edged after requested edge/path curvature faded. Rigid-cuff leg fitting
then displaced the pelvis even with nearly upright requested torso. The sole
runtime change releases that restriction at <=10% steering, smoothly restoring
it by 25%. Actual skis still use their loaded response, maximum-edge clamp and
3 rad/s motor limit. Balance integration, anatomical limits and presentation
ownership are intact. The aggregate bank can still transiently overshoot during
release; this fix addresses equipment unwind and the resulting connected stance.

At the original measured tick 273, source posture root X changes -0.021526 to
-0.021420 m, requested hips X -0.138504 to -0.006960 m and pelvis fitting correction
0.476377 to 0.115296 m. Final body lean changes 26.562 to 4.892 degrees and lateral
pelvis 0.400458 to 0.084491 m. Actual edges unwind from -0.899/-0.932 rad to near
zero. Physical bank is still 1.131 rad versus 0.953 before at that instant.

Matched peaks in the original tick >240 / |path acceleration| <0.5 window
(body and pelvis maxima are measured independently):

| Speed / initial direction | Body degrees before -> after | Pelvis m before -> after | Settling s before -> after |
|---|---:|---:|---:|
| 25 m/s / -1 | 27.260 -> 4.895 | 0.4005 -> 0.0862 | 1.117 -> 0.083 |
| 25 m/s / +1 | 26.059 -> 4.911 | 0.3807 -> 0.0802 | 1.067 -> 0.067 |
| 40 m/s / -1 | 28.601 -> 5.299 | 0.4137 -> 0.0870 | 0.983 -> 0.083 |
| 40 m/s / +1 | 28.267 -> 4.463 | 0.4182 -> 0.0781 | 0.950 -> 0.067 |

The maintained 50-case regression fails 18/276 checks on the original source and
passes all 276 after. The neutral-relative envelope is 12 degrees / 0.15 m after
0.5 s release and 0.25 s sustained low curvature, with no edge-saturation exemption.
Residual violation duration in that window falls from 0.333/0.300/0.233/0.217 s
to zero. Separate bounds cover held weak exits and 50/150 ms taps.

**Handling:** eight strong held-steer/reversal metrics at 60-200 km/h and tuck
0/1 match the original model exactly (response, radius, speed, arc). Strong loaded
controls retain 35-43 degree peak lean. Original 55% reversals differ after release
by <=0.015 m position / 0.025 m/s speed. Longer strong-hold releases differ by up
to 0.374 m / 0.0812 m/s, with unchanged heading, because edges alter exit support
and grip. Fresh 5/10% holds differ by <=0.0011 m position; weak exits end at
2.1-5.8 degrees. Sixteen matched four-second uneven snow cases cover mirrored
cross-slopes, two speeds/roughnesses, weak input and reversal with 64 passing
support/reach/contact checks. No crash or unsupported grip was introduced.

**Automated:** 2,388 passing assertions across 23 suites; 19 suites fully pass,
including physics (56), runtime (192), carve response/entry/proportional
(52/64/579), residual (276), animation CPU (72), anatomy/turn anatomy/attachments,
landing/flight, rock, ghost/crash replay, handling and tuck contact. Current snow
contracts add 26 passes, apart from the 64 uneven-snow checks above. Nine failures
in four suites reproduce exactly on original source: animation 3 (neck gaze,
tuck hands, impact back), motion 1 (tuck hand easing), pole pose 2 (28/34-degree
continuity), pole contact 3 (brake departure and steep10/steep5 continuity).
Assertions were not weakened. Historical model-27 snow fixtures were unavailable;
current bounded support checks do not relabel them as a new baseline.

**Rendered:** matched before/after native production captures each preserve
4,800 frozen poses over 14 scenarios, 3,148 rear/front/side anatomical images at
60 Hz and 2,400 chase images at 30 Hz. Author framewise review covers complete
changed entry/hold/reversal/release and tuck/hop/landing neighborhoods. Equipment
stays connected, strong carving stays deep, and residual sideways stance resolves
without new visible snaps. Inputs and camera configuration match; physical
changes are reported above. Restored bone error is <0.8 micrometres. Hop takeoff
and landing remain ticks 481/560. These are analytic planes, not full-route review.

**Clothing:** five-ray, 6 mm skinned shaft audit checks every one of the 2,060
geometry-changed frame pairs in both revisions; the other 2,740 are exactly equal
in all final bones, poles, skis and actor root. Intersecting frames fall 239 -> 171,
with no new intersecting frame or frame/side/material contact. Remaining 83/88
frames in the two tuck cases are baseline clipping. Absolute mesh audits still
fail there; the differential regression passes. This is not a game-wide mesh
all-clear. The existing tuck finding and nine assertions remain unresolved.

**Load/performance boundary:** all work during the raid was headless at Idle
priority on two logical CPUs. After the user closed WoW, native review ran serially
at BelowNormal priority with small offscreen views capped at 60 FPS. Production
animation algorithms/assets are byte-identical and their 72 CPU-optimization
contracts pass; the conditional three-run animation-cost benchmark was not
triggered by this edge-control change. No new production FPS or whole-route
performance claim. Human visual preference, physical-controller comfort and skiing
feel remain pending separately from this completed implementation.

**Evidence:** retain both `artifacts/pelvis_residual/20260912-baseline/` and
`artifacts/pelvis_residual/20260912-fix/` through review. The latter contains
`EVIDENCE.md`, exact SHA256 in `identity-final-source.json`, `final-comparison.json`,
`validation-summary.json`, `preexisting-comparison.json`, `uneven-comparison.json`,
`author-review.json`, `mesh-comparison.json`, full `final-before/` and `final-after/`
captures, and `before-after.png`. Guides updated: Animation, Physics, Architecture.
Detailed logs distinguish the final fix from rejected balance-braking probes.
Cleanup of superseded task outputs was deferred: another task owns the validation
lock (`dense-gpu-tree-skip-pilot`). `cleanup-receipt.json` records zero deletions;
`cleanup-owned.ps1` is limited to this task's obsolete copies. Active-review
evidence is retained intentionally.
No separate ideas or new backlog tasks were proposed.

---
id: "AA-20260911-161450-proportional-carving-lean"
title: "Fix excessive and wrong-direction carving lean"
status: done
priority: P2
depends_on: []
created: "2026-09-11T16:14:50Z"
updated: "2026-09-12T00:12:55Z"
source_thread: "01a0913c-4f24-7623-a631-64ae86ab068e"
---

# Fix excessive and wrong-direction carving lean

## Outcome

The user reports that "just a small steering input can cause the full animation
to play out" and make the skier lean heavily to one side while travelling almost
straight. They confirmed this happens with both slight held input and quick taps.
Small corrections should look subtle, deep lean should remain available for a
sustained loaded turn, and the pose should settle as the actual turn fades. The
user explicitly chose to keep strong carving for real turns.

The user subsequently reported the direction is also wrong: "if im steering to
the right the skier will lean to the left". Fix both excessive strength and
opposite visible lean in this task. From settled straight skiing, a right turn
must develop rightward whole-body lean, with the mirrored expectation for left.
Assess the final skier in the gameplay view, not merely the selected clip name.

## Current state and evidence

Read-only investigation on 2026-09-11 at commit
`9e745aab3d7a161a06887313362223e729c5b140`; live physics model is 28. Recheck source
and engine identity before implementation. No Godot reproduction or rendered
verification was performed while authoring this task; the symptom is user-reported.

Direction follow-up inspection at commit
`4e10f9fafab183cdca49ac179eda1cf1f0cfea5b` confirmed the separate direction/bank
channels below remain in the live source. Concurrent presentation/animation-tool
cleanup was in progress; only this task file was edited. The new direction report
has not yet been reproduced or diagnosed by an implementation worker.

- [skier_full_motion.gd](../../scripts/presentation/skier_full_motion.gd), `step`
  and `supported_turn`: grounded, load-weighted completed ski edge is normalized
  by 0.65 radians. Input above magnitude 0.001 selects direction, while the edge
  signal supplies magnitude. A duplicated state's `steer` and `carve` are replaced
  by these values. Turn clip weight uses `smoothstep(.02,.85,abs(turn))`.
  In particular, `state.steer` takes the input-selected sign while `state.carve`
  retains the supported-edge sign. `Action.apply` uses `state.carve` for hip/spine
  roll and `state.steer` for yaw. These signals can disagree during counterbank
  or reversal; trace whether that disagreement explains the reported left lean
  on right input, without assuming that changing a clip label fixes the body.
- Carve clips are sampled using the continuously advancing `clock` with looping
  enabled. Inspection does not establish an input-triggered one-shot animation;
  investigate why the final motion *looks* like a full committed sequence.
- [downhill_posture.gd](../../scripts/presentation/downhill_posture.gd), `straight`,
  fully releases the straight posture by `abs(state.steer) == .06`. In this caller
  that is the edge-derived animation channel, not raw stick displacement. With
  full support weighting it corresponds to about 0.039 radians of loaded edge.
  [action_posture.gd](../../scripts/presentation/action_posture.gd), `weights`,
  uses the complement of this straight weight, or physical bank, to enable its
  turn posture. Thus a small edge-derived signal can fully hand off posture even
  while turn clip weight is low. This is a concrete suspect, not a proven cause.
- Follow the result through `Action.apply`, the existing joint/root trackers,
  `skier_full_motion.compose`, and final support/leg fitting. Pelvis targets and
  support alignment also use posture weights; fixing clip weight alone may miss
  the visible whole-body lean. [skier_animation.gd](../../scripts/presentation/skier_animation.gd)
  supplies additional smoothed bank, load-bias and `turn_follow` channels.
- [carve_response_suite.gd](../../tests/carve_response_suite.gd) checks direction,
  flat-edge gating, continuity and physical equality, mainly with magnitude 0.55
  held input and 0.8 alternating taps. [carve_entry_suite.gd](../../tests/carve_entry_suite.gd)
  checks wrong-way silhouette motion with hard input or ramps to 0.55. Neither
  establishes an acceptable lean envelope for small sustained inputs and taps.
- [CARVE_DIRECTION_FIX.md](../../docs/ANIMATION.md#carving) documents the earlier
  cross-slope/body-frame correction and its evidence. Retain its valid direction
  and support-frame guarantees, but treat the latest report as an unresolved
  direction defect; the earlier checks do not prove this case is fixed.
  Its historical ten tuck-transition clothing-contact
  frames and pending human acceptance are limitations, not a current all-clear.

Backlog, archive and `docs/tasks/` searches found no duplicate fix.
[Input acceptance evidence](../archive/AA-20260911-153901-input-acceptance-evidence.md) is a
related audit that does not authorize retuning; this bounded animation fix can
proceed independently of retired authoring experiments.

## Agreed decisions and scope

- Cover held light steering, quick tap/release, both directions and transitions
  back to nearly straight skiing. Preserve expressive balance in strong turns.
- Correct wrong-way final body/torso lean as well as strength. Distinguish entry
  from settled straight skiing from a reversal that must unwind an existing
  loaded turn. Preserve continuous weight transfer and natural upper-body
  counterbalance; do not snap or force every joint to share the input sign.
- Change presentation response/blending in the existing production pipeline.
  Use completed physical response to distinguish real loading/turning from an
  exaggerated pose; neither raw input nor any nonzero edge is sufficient alone.
  Residual real turning may retain proportionate balance after input release.
- Preserve the 120 Hz solver, trajectories, COM, contacts, ski/boot transforms,
  replay/results, input mapping/deadzones, camera, and sole `skier_pose_writer.gd`.
  No global lean clamp, new animation system, mandatory asset reauthoring or
  physics retune. If physical behavior itself proves defective, record that
  separately instead of changing physics to make this pose look correct.
- Default priority is P2. Numerical blend/settling tolerances are implementation
  choices to establish from measured fixtures and rendered evidence. Human
  controller/visual acceptance is a separate follow-up, not a dispatch or worker
  completion gate; it must remain explicitly pending until the user playtests.

## Implementation approach

1. Follow the [animation skill](../../.agents/skills/alpine-animation/SKILL.md) and
   [review workflow](../../docs/ANIMATION.md#production-pipeline). Capture a current
   failing baseline. Trace post-mapping input, speed, actual trajectory turn rate,
   heading, body bank, grounded load/edges, original and overridden channels,
   source phase/weights, downhill/action weights, requested pose and final pose.
   Establish which stage first creates excessive lean, wrong-way lean or delayed
   continuation. Track clip side, signed bank/roll and final torso/whole-body lean
   separately, with explicit rider-relative and gravity/heading-frame conventions.
2. Use matched left/right fixtures with normalized post-mapping inputs 0, 0.05,
   0.10, 0.20, 0.55 and 1.0: light holds, 50-150 ms taps, release and reversal.
   Vary source phase and speed; include fall-line, cross-slope and mirrored
   cross-slope support, tuck, unequal loads, and return from a strong turn.
   Check idle stick noise through the existing controller mapping as a neighbor.
   Include an explicit settled-straight -> right-input -> release sequence and
   its left mirror, plus input opposing terrain counterbank or the previous turn.
   Do not filter out opposite-sign edge/input samples from the direction audit.
3. Correct the owning blend/posture stage so mild real corrections remain mild
   through source sampling, tracking and final fitting. Preserve smooth entry,
   release and reversals, strong-turn range, valid residual balance and the
   valid support-frame correction while repairing the newly reported direction
   failure wherever it originates. Do not enforce waiting for a clip to
   finish. Change only the smallest coherent cause demonstrated by the trace.
4. Extend focused regressions around the reproducer. Measure final torso and
   foot-to-chest lateral angles in the gravity/heading frame, plus lateral pelvis
   displacement, peak lean and settling time. Include trajectories so a small
   input that produces substantial real turning is not mislabeled a straight
   correction. Freeze before/after sources and compare identical physical runs.

## Acceptance and verification

The required implementation and review were performed. The clothing audit fails;
its measured regression is retained explicitly below and in the animation guide.
Human visual/controller acceptance remains pending, as agreed.

- [x] Starting from settled straight skiing, right input does not initiate a
  pronounced leftward whole-body/torso lean; left input satisfies the mirror.
  Verify final gravity/heading-relative silhouettes and production chase views
  through entry, hold and release, across light/strong input and source phases.
  Record opposite-lean magnitude/duration and bounded natural sway. A correct
  LEFT/RIGHT clip label alone cannot pass this check. Counterbank/reversal cases
  must transition smoothly without a newly triggered wrong-way lurch; distinguish
  unwinding real residual bank from a presentation direction defect.
- [x] Mild holds and taps that produce only mild path correction have visibly
  smaller final lean than sustained strong loaded turns. A light correction
  cannot merely activate the full deep-carve posture. Document quantitative
  envelopes against the neutral and strong-turn references at matched phases.
- [x] When input and measured turning/loading settle, the pose returns smoothly
  toward straight skiing without a later deep lurch or completing a committed
  clip cycle. Record peak timing and time to settle; preserve proportionate
  residual balance while a real turn persists. No snaps in entry or reversal.
- [x] New focused magnitude/direction/release checks, `tests/carve_response_suite.gd`,
  `tests/carve_entry_suite.gd`, and the animation regression group (anatomy,
  compact posture, ski attachment, skier motion) pass. Paired runs retain exact
  recorded physics/ski state and COM. If input/session/physics changes become
  separately authorized, also run `tests/physics_suite.gd` and
  `tests/runtime_suite.gd` as required by project guidance.
- [x] Inspect complete chronological before/after renders, including the
  gravity-aligned `--world-up` view and production chase camera. Cover light
  hold/tap/release, strong carve, cross-slope, reversal and tuck neighbors;
  inspect connected arms, hands, rigid poles and final skinned clothing. Run
  the relevant full-sequence clothing audit, distinguish existing contacts
  from new regressions, and do not equate attachment passes with clearance.
- [x] Run Godot/render workloads serially through `scripts/run_guarded.ps1` or
  the maintained pose-review stage runner. Respect `artifacts/validation.lock`.
  Keep fixtures unranked and use unique evidence folders. For a production
  mountain check use cached seed 849205174/v15 Standard and restart the game.
- [x] Report existing animation step/fit timing before and after under matched
  conditions. Avoid a new per-frame cost regression; capture timings alone do
  not establish 4K performance or 90-120 rendered FPS acceptance. Keep automated,
  rendered, performance and real-controller acceptance separate.
- [x] Update maintained animation documentation with the diagnosed cause,
  response contract, reproducer, actual evidence and remaining limitations.
  Commit and push the scoped implementation, tests/assets if needed, docs and
  completion record on `main`, preserving concurrent work.

## Open questions

None.

## Completion record

Implemented and pushed on `main` in **9adf15a** (`Make carving posture proportional
to completed turning`). The scoped carving response work is complete; this is
not an all-clear for neighboring clothing quality or human acceptance.

The early `.06` straight-posture release handed even a 5% hold to full Action
posture. Partial blends also retained contrary source roll and edge-signed torso
balance on cross-slopes. The production sampler now uses completed path curvature
bounded by loaded edge magnitude, one shared posture/source strength, tracked
stance inclination and proportional hip/spine roll. Strong loaded turns retain
expression. Existing joint trackers, final cuff fitting and the sole writer stay
in place; no solver/input/COM/replay/terrain/camera/asset changes were made.

At 25 m/s, 5% holds now peak at 1.7% Action activation, 10% holds at 12.8%, and
100 ms 10% taps at 2.2%, compared with 100%/100%/84%. Light holds remain around
3.3/7 degrees of whole-body lean; strong 55-100% turns retain about 38-42 degrees.
Mild held-turn pose settling is approximately .15-.22 s after release. The
100 ms tap peaks at .617 s (release .600 s). Full timing, pelvis and direction
traces are retained in `carving.json`, without dropping counterbank samples.

Validation:

- 114-case proportional suite: **575/575** checks, multiple speeds/phases, both
  signs, zero/.05/.10/.20/.55/1.0, 50/150 ms taps, holds, release, cross-slopes,
  reversals and tuck. Every twin physical/replay snapshot and COM is equal.
- Carve response 52, entry 64, anatomy 84, compact 36, attachment 20, motion 19 and
  controller mapping 51 checks pass. Compact expectations now distinguish a light
  correction from a full posture handoff. Python review tools 13 and backlog 17
  checks pass. No live input/session/physics source was changed by this task.
- Frozen baseline `e20d75b` and final sources: 159 files each under
  `artifacts/pose_review/revisions/20260912-proportional-{before,final}/`.
  All **3,150 paired frames** have identical recorded physics, COM and skis.
  Both complete native world-up triptych sequences were reviewed chronologically,
  with full-resolution event views. All **1,155 chase pairs** were reviewed;
  recorded cameras/input/physical state match exactly.
- Engine Godot 4.7.2 custom `ed1daf0bf`, model 28, D3D12 Forward+, RX 9070.
  Executable hashes and aggregate proof: `artifacts/carve_proportional/engine.json`
  and `delivery-evidence.json`. The matched CPU proxy for two simulation-rate
  animation steps plus one fit is 2.394 -> 2.445 ms (about +.051 ms); this is not a 4K
  performance or rendered-FPS acceptance. Later matrix wall time is not used as
  an isolated performance result.
- All engine workloads used the existing guard, separate evidence folders and
  unranked analytic fixtures. Production-camera review did not load a mountain
  or write personal bests. Shared checkout work from other tasks was preserved.

Remaining findings:

- **Clothing clearance failed:** full 3,150-frame actual skinned-mesh shaft audit
  finds 33 affected frames before and 130 after (114 light-tuck right, 16
  strong-tuck left). There are 117 newly affected frame/scenario pairs, 13 retained
  and 20 removed; the other 13 scenarios/2,730 frames remain clear. This is a real
  neighboring regression as the corrected body stays tucked, not just the old
  ten-contact limitation. Mechanical attachment/anatomy passes do not clear it.
  Pole/arm-target trials were rejected because they retained intersections or
  introduced large wrist snaps. Their evidence is preserved; none ships.
- A strong reversal can leave physical skis/cuffs heavily banked after path
  curvature fades. The pose cannot stand fully upright without violating the
  unchanged cuff/leg fit. In the fixture the body peak reduces 44.23 -> 27.01 degrees,
  while the torso settles. This is a separate physical-response finding; no
  physical retune or hidden sample exclusion was used.
- Human visual/controller acceptance remains pending. No overall animation
  grade, all-clothing clearance, 4K FPS or controller-feel acceptance is claimed.

Detailed command recipes, trial provenance and independent validation receipts
are indexed in `artifacts/carve_proportional/REVIEW.md`; the matched viewer is
`artifacts/pose_review/comparisons/20260912-proportional-reviewed/index.html`.
The authoritative response contract and limitations are in
[Animation](../../docs/ANIMATION.md#carving). This completion/archive record is
committed separately after the pushed implementation milestone.

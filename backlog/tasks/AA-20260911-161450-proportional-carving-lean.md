---
id: "AA-20260911-161450-proportional-carving-lean"
title: "Make carving lean proportional during light steering and taps"
status: ready
priority: P2
depends_on: []
created: "2026-09-11T16:14:50Z"
updated: "2026-09-11T16:14:50Z"
source_thread: "01a0913c-4f24-7623-a631-64ae86ab068e"
---

# Make carving lean proportional during light steering and taps

## Outcome

The user reports that "just a small steering input can cause the full animation
to play out" and make the skier lean heavily to one side while travelling almost
straight. They confirmed this happens with both slight held input and quick taps.
Small corrections should look subtle, deep lean should remain available for a
sustained loaded turn, and the pose should settle as the actual turn fades. The
user explicitly chose to keep strong carving for real turns.

## Current state and evidence

Read-only investigation on 2026-09-11 at commit
`9e745aab3d7a161a06887313362223e729c5b140`; live physics model is 28. Recheck source
and engine identity before implementation. No Godot reproduction or rendered
verification was performed while authoring this task; the symptom is user-reported.

- [skier_full_motion.gd](../../scripts/presentation/skier_full_motion.gd), `step`
  and `supported_turn`: grounded, load-weighted completed ski edge is normalized
  by 0.65 radians. Input above magnitude 0.001 selects direction, while the edge
  signal supplies magnitude. A duplicated state's `steer` and `carve` are replaced
  by these values. Turn clip weight uses `smoothstep(.02,.85,abs(turn))`.
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
- [CARVE_DIRECTION_FIX.md](../../docs/CARVE_DIRECTION_FIX.md) documents the earlier
  cross-slope/body-frame correction and its evidence. Preserve its direction and
  support-frame behavior. Its historical ten tuck-transition clothing-contact
  frames and pending human acceptance are limitations, not a current all-clear.

Backlog, archive and `docs/tasks/` searches found no duplicate fix.
[Input acceptance evidence](AA-20260911-153901-input-acceptance-evidence.md) is a
related audit that does not authorize retuning; this bounded animation fix can
proceed independently. Older Cascadeur handoffs concern authoring experiments,
not this response defect.

## Agreed decisions and scope

- Cover held light steering, quick tap/release, both directions and transitions
  back to nearly straight skiing. Preserve expressive balance in strong turns.
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
   [review workflow](../../docs/ANIMATION_AGENT_WORKFLOW.md). Capture a current
   failing baseline. Trace post-mapping input, speed, actual trajectory turn rate,
   heading, body bank, grounded load/edges, original and overridden channels,
   source phase/weights, downhill/action weights, requested pose and final pose.
   Establish which stage first creates excessive lean or delayed continuation.
2. Use matched left/right fixtures with normalized post-mapping inputs 0, 0.05,
   0.10, 0.20, 0.55 and 1.0: light holds, 50-150 ms taps, release and reversal.
   Vary source phase and speed; include fall-line, cross-slope and mirrored
   cross-slope support, tuck, unequal loads, and return from a strong turn.
   Check idle stick noise through the existing controller mapping as a neighbor.
3. Correct the owning blend/posture stage so mild real corrections remain mild
   through source sampling, tracking and final fitting. Preserve smooth entry,
   release and reversals, strong-turn range, valid residual balance and the
   earlier apparent-direction correction. Do not enforce waiting for a clip to
   finish. Change only the smallest coherent cause demonstrated by the trace.
4. Extend focused regressions around the reproducer. Measure final torso and
   foot-to-chest lateral angles in the gravity/heading frame, plus lateral pelvis
   displacement, peak lean and settling time. Include trajectories so a small
   input that produces substantial real turning is not mislabeled a straight
   correction. Freeze before/after sources and compare identical physical runs.

## Acceptance and verification

All checks below are planned and pending implementation.

- [ ] Mild holds and taps that produce only mild path correction have visibly
  smaller final lean than sustained strong loaded turns. A light correction
  cannot merely activate the full deep-carve posture. Document quantitative
  envelopes against the neutral and strong-turn references at matched phases.
- [ ] When input and measured turning/loading settle, the pose returns smoothly
  toward straight skiing without a later deep lurch or completing a committed
  clip cycle. Record peak timing and time to settle; preserve proportionate
  residual balance while a real turn persists. No snaps in entry or reversal.
- [ ] New focused magnitude/release checks, `tests/carve_response_suite.gd`,
  `tests/carve_entry_suite.gd`, and the animation regression group (anatomy,
  compact posture, ski attachment, skier motion) pass. Paired runs retain exact
  recorded physics/ski state and COM. If input/session/physics changes become
  separately authorized, also run `tests/physics_suite.gd` and
  `tests/runtime_suite.gd` as required by project guidance.
- [ ] Inspect complete chronological before/after renders, including the
  gravity-aligned `--world-up` view and production chase camera. Cover light
  hold/tap/release, strong carve, cross-slope, reversal and tuck neighbors;
  inspect connected arms, hands, rigid poles and final skinned clothing. Run
  the relevant full-sequence clothing audit, distinguish existing contacts
  from new regressions, and do not equate attachment passes with clearance.
- [ ] Run Godot/render workloads serially through `scripts/run_guarded.ps1` or
  the maintained pose-review stage runner. Respect `artifacts/validation.lock`.
  Keep fixtures unranked and use unique evidence folders. For a production
  mountain check use cached seed 849205174/v15 Standard and restart the game.
- [ ] Report existing animation step/fit timing before and after under matched
  conditions. Avoid a new per-frame cost regression; capture timings alone do
  not establish 4K performance or 90-120 rendered FPS acceptance. Keep automated,
  rendered, performance and real-controller acceptance separate.
- [ ] Update maintained animation documentation with the diagnosed cause,
  response contract, reproducer, actual evidence and remaining limitations.
  Commit and push the scoped implementation, tests/assets if needed, docs and
  completion record on `main`, preserving concurrent work.

## Open questions

None.

## Completion record

Pending implementation. Record the diagnosed cause, changed behavior, source and
engine identity, commands/results, frozen comparison paths, measured response,
remaining human acceptance and commit/push references. Record a blocker and
unfinished work if reproduction or required verification cannot be completed.
Any separate proposals belong in `backlog/ideas/` for user selection; none were
created during authoring.

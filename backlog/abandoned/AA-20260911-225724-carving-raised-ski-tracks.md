---
id: "AA-20260911-225724-carving-raised-ski-tracks"
title: "Keep snow tracks under the cosmetically raised ski during carving"
status: retired
priority: P2
depends_on: []
created: "2026-09-11T22:57:24Z"
updated: "2026-09-17T00:13:30Z"
source_thread: "01a092ae-e40a-7510-aaba-b8043f8a1dd6"
---

# Keep snow tracks under the cosmetically raised ski during carving

## Archive disposition - 17 September 2026

Archived at the user's explicit request. This task is retired; reopening requires
new user direction. Existing implementation evidence, rejected experiments and
unresolved acceptance below are retained as history. Archiving does not mark
unmet checks as passed.

## Outcome

The user reports that one boot rises slightly for the carving animation and
the corresponding snow track appears to stop. They want the raised ski to keep
producing a continuous track during that animation. Preserve the intended pose
and draw the track on the snow beneath that ski throughout grounded carving,
including entry, sustained turns and reversal.

## Current state and evidence

Source inspection on 2026-09-11 UTC; the reported visual gap has not yet been
reproduced by this author. Animation lift as the cause remains a hypothesis.

- [SnowResponse](../../scripts/presentation/snow_response.gd), `sample`, requires
  rider grounded, not crashed, ski grounded and `ski.load_n > 1.0` for support;
  `snow_contact` additionally excludes rock. Low load or a contact transition
  can therefore stop tracks, independently of rendered boot height.
- [SpeedEffects](../../scripts/presentation/speed_effects.gd), `update_effects`,
  samples completed ski state, then substitutes final rendered ski position and
  forward direction, with the switch-stance index mapping. That substitution
  does not directly change support eligibility.
- [SnowTracks](../../scripts/presentation/snow_tracks.gd), `_independent_contacts`,
  hides the live ribbon and clears that ski's history anchor when `snow_contact`
  is false. `_stamp` already projects ribbon geometry onto the authoritative
  terrain and rejects rock along the swept segment. A vertical animation offset
  alone is therefore not sufficient evidence for the cause.
- [PowderSurface](../../scripts/presentation/powder_surface.gd) consumes the same
  endpoints and snow-contact-dependent depth for High's live footprints.
- [Snow contact visual suite](../../tests/snow_contact_visual_suite.gd) covers
  live footprints, unsupported skis, rock, reset and rendered-pose/switch
  mapping, but does not establish the reported live carving outcome.
- Read the owning [snow rendering contract](../../docs/RENDERING.md#snow-presentation),
  [authority boundaries](../../docs/ARCHITECTURE.md#authority-and-timing) and
  [validation guide](../../docs/VALIDATION.md).

Related work: [carving lean](AA-20260911-161450-proportional-carving-lean.md)
changes the pose, while [animated ghosts and tracks](../blocked/AA-20260911-220556-animated-ghost-snow-tracks.md)
may change the shared track interface. Neither is a prerequisite. Coordinate
shared files and consume whichever interface has landed; do not rewrite these
tasks or expand this fix into their implementation. Concurrent capture edits
were present during authoring and were left untouched.

## Agreed decisions and scope

- A cosmetic ski/boot lift during otherwise grounded carving must not interrupt
  that ski's snow trail. Keep the visual lift; do not flatten the animation to
  make tracks work. Both skis must retain visible, independently aligned marks.
- This is a snow-track presentation fix. Preserve the Node-independent 120 Hz
  solver, contact/load/force state, trajectory, input, replay and race identity.
  Never write fabricated contact or load back into simulation.
- Keep genuine airborne gaps, terrain departure, crashes, exposed rock and
  inactive/reset/teleport lifecycle suppression. Do not turn rider grounded
  into unconditional permission for both skis to stamp anywhere below them.
- If reproducing the grounded carving gap reveals a lightly unloaded inside
  ski, a bounded cosmetic track continuation is in scope. It must distinguish
  near-surface carving from a real unsupported ski over a drop. Its eligibility
  and modest track appearance must remain separate from physical support and
  must not enable spray, sparks or forces through a shared flag accidentally.
- Preserve current track budgets, quality settings, visible tip alignment and
  snow-depth/material bounds. No general snow, animation or physics retuning.

## Implementation approach

1. Reproduce using ordinary steering on continuous snow with final equipment
   animation enabled: sustained left/right carving and reversals. Capture the
   two trails chronologically and log per-ski grounded/load/material, rendered
   lift relative to authoritative surface, response eligibility/depth and live
   and retained track state. Identify whether the gap comes from eligibility,
   appearance/depth, geometry or the live/history handoff before selecting a fix.
2. Correct the demonstrated failure in the presentation path. Use final rendered
   ski lateral position and orientation for alignment and shared terrain for
   the footprint height. If a carving-specific continuation is necessary,
   define an explicit bounded eligibility rule from completed rider state and
   near-surface footprint evidence, with a documented cutoff for true terrain
   separation. Do not globally relax `SnowResponse.supported` or its load gate.
3. Keep live ribbons, retained history and High's corresponding GPU track
   footprints consistent. Preserve index mapping through switch/reversal and
   break history across actual air, rock, crash, reset and teleports. Avoid
   connecting across a previously unsupported interval on re-entry.
4. Extend focused regression coverage and update the owning snow presentation
   contract with any intentional cosmetic eligibility exception. Put captures,
   telemetry and timings in a dedicated ignored artifacts directory.

## Acceptance and verification

- [x] Reproduce and document the actual cause, separating measured evidence from
  the user's original animation-lift hypothesis.
- [x] Rendered chronological before/after evidence shows two continuous tracks
  on continuous snow during left/right carving, entry, hold, release and
  reversals while the cosmetic ski lift remains. Marks stay on the surface
  beneath the corresponding rendered ski and extend into retained history.
- [x] A focused regression changes only the cosmetic ski elevation while
  preserving completed simulation state and proves track continuity. Exercise
  the real reproduced failure as well; do not rely solely on synthetic flags.
- [x] Verify actual jumps, one-ski terrain departure, exposed/mixed rock, crashes,
  resets and teleports still suppress invalid marks and prevent bridging gaps.
  Include low-load inner-ski carving if it is the demonstrated cause.
- [ ] Run `./scripts/validate_snow_contact.ps1 -Stage checks`, then
  `./scripts/validate_snow_contact.ps1 -Stage visual`; this wrapper owns the
  guard, so do not nest it. Add the targeted carving capture using
  `./scripts/run_guarded.ps1 -FilePath ./godotw.ps1 -Arguments
  @('--script','tests/carving_raised_ski_tracks_capture.gd') -Label carving-raised-ski-tracks`.
  Create this focused fixture as part of implementation and record the actual
  command in completion evidence if an existing fixture is extended instead.
- [ ] Inspect rendered output on Low/Balanced ribbons and High GPU footprints;
  native GPU execution is required for changed shader/compute paths. Run
  `./scripts/validate_snow_contact.ps1 -Stage timing` if the hot path changes,
  comparing matched conditions and reporting cost separately from visual QA.
- [x] Verify unchanged completed physics/replay state for identical inputs.
  Physics/input/session changes are outside scope; if needed, reassess that
  boundary and run the required physics/runtime suites under the guard.
- [ ] Use isolated fixtures/profiles; tests never write personal bests. Maintain
  the owning guide, validate the backlog, and commit/push only owned changes.

Human acceptance: the user's in-game/controller review of continuous tracks
and the preserved carving appearance remains a separate follow-up, not a worker
completion gate. Worker rendered inspection is required; automated results do
not establish human acceptance. All checks above are planned, not performed.

## Open questions

None.

## Completion record

Implemented and parent-accepted for the measured continuity defect. Physical
load gating plus restrictive cosmetic burial/release/root-clearance tests caused
the reproduced gaps; animation lift alone was not the demonstrated cause.
Track-only eligibility now keeps independent shallow marks under certified
grounded snow skis through unloading, entry, hold, release and reversal. The
grounded footprint envelope is 24 cm after the stricter physical-center check;
unsupported near-surface carving retains conservative opposite-ski/separation
requirements. Nine-point material/support checks and a cut capped at 12 mm/local
loose depth preserve rock/void exclusions. Physical support, forces and particles
are not fabricated. Live ribbons and High GPU footprints share accepted geometry;
horizontal XZ distance controls retained spacing. Air, rejection and lifecycle
discontinuities break history. Rendering owns the detailed bounds.

The accepted [continuity v3 review](../../artifacts/orchestration_20260912/carving/V3_NATIVE_REVIEW.md)
audited **2,400 rows / 4,800 ski records**, eight complete five-second captures
and every 600-tick physical trace. It found **278 restored Balanced samples**;
right/reversal have two live marks on all 244 grounded frames each, with zero
continuity errors. Low/High reversal and the deliberate jump pass; actual air
and observed rock gaps have no bridge. All 900 paired Balanced physical hashes,
physical response channels and final ski transforms match. Sampled chronology
and 14 original images establish visible continuation with the pose preserved.
Left-turn motion occurs within reversal; a separate sustained-left/switch v3
recapture is not claimed. Native High checks prove live-packet parity and the
cosmetic-elevation-only regression. Parent snow-contact checks passed129,
rock32, powder-upload13 and carving-GPU7; synthetic checks cover drops, rock,
crash, reset and teleport separately from native riding.

The current causal captures supersede the original tree-crashing fixture, not
every historical wrapper stage. `-Stage checks` ran; no `-Stage visual` or clean
carving `-Stage timing` pass is claimed. The capture-only mean effects increments
(+0.204/+0.268/+0.058 ms for right/reversal/jump) are not free, repeated timing or
whole-frame FPS. FPS caps/misses are advisory under the user's concurrent-run
waiver. Full trace identity is not a separate replay-file round trip.

**R1 loaded-track shape remains limited:** Standard frames217–225, especially223,
show scalloped/triangular banks. Loaded response/bank formulas predate the task,
but XYZ→XZ spacing can change join prominence on steep terrain. Both boundary
variants share carving; they cannot establish that the defect is unaffected.
The spacing/live-history contribution remains unisolated. Preserve the
[world-shape review](../../artifacts/orchestration_20260912/carving/world_shape/REVIEW.md),
accepted continuity and rejected evidence separately. No speculative retune or
new backlog idea is proposed. Validation and the [final checklist map](../../artifacts/orchestration_20260912/forest/final_four_records/CHECKLIST_MAP.md)
record producer/evidence limits.

- [ ] Human in-game/controller continuity and carving-appearance review: pending separate follow-up.
- [ ] Parent delivery: **PARENT TO FILL** commit(s), successful push, final status and artifact-lifecycle disposition. Status remains `in_progress` until parent delivery.

## Checkpoint disposition — 2026-09-12T13:21:47Z

Implementation is included in the user-requested integration checkpoint. Full original acceptance is not claimed. The manual workers were stopped at the user's request; no active claim remains. Further work is delegated to [AA-20260912-132147-review-loaded-track-ridge-shape](../completed/AA-20260912-132147-review-loaded-track-ridge-shape.md), [AA-20260912-132147-close-eight-feature-integration-records](AA-20260912-132147-close-eight-feature-integration-records.md). Do not redispatch this whole original task or repeat its completed matrices. The linked closure task owns final criteria reconciliation. Human acceptance and documented FPS/appearance limits remain explicit. Delivery is the Git commit containing this disposition; subsequent closure must record its own exact commit/push reference.

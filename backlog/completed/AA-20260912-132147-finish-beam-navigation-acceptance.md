---
id: "AA-20260912-132147-finish-beam-navigation-acceptance"
title: "Finish shared beam and navigation acceptance"
status: done
priority: P2
depends_on: []
created: "2026-09-12T13:21:47Z"
updated: "2026-09-13T20:38:41Z"
source_thread: null
---

# Finish shared beam and navigation acceptance

## Outcome

Complete the missing amber 500 m view and verify a useful sequence of session navigation markers without repeating accepted distant-view matrices.

## Current state and evidence

Navigation v4 passes167 checks and eight reviewed hidden/shown images at 500 m and2 km/ridge. Selection takes1.459 s and finds a finish-valid500 m anchor. Amber2 km/ridge and twelve weather images are accepted separately. The new amber 500 m route stops before captures on “Same identified native engine as navigation v4”. Earlier87 navigation UI/lifecycle checks do not close corrected five-point chronology, cost and Reduced Motion coverage.

Originating tasks: [AA-20260911-232811-taller-distant-finish-beam](../blocked/AA-20260911-232811-taller-distant-finish-beam.md), [AA-20260911-232936-session-navigation-beams](../blocked/AA-20260911-232936-session-navigation-beams.md). Evidence: `artifacts/orchestration_20260912/navigation/landmark-preflight-parent-v4/`, `finish/nav500/`, `amber_and_air/finish_500m.log`, and `navigation/landmark_v4/`. Measurements are from2026-09-12; private proposals and frozen captures are local, ignored evidence, not shipped dependencies. Recheck live source before applying a candidate.

## Agreed decisions and scope

The user explicitly requested this remaining work be saved for later, after stopping excessive agent/test usage. Authoring does not dispatch. Start with one worker and the smallest sufficient check; batch compatible checks, use the existing validation guard, and stop expanding coverage once the named criteria pass. Preserve120 Hz simulation,4 m terrain authority, personal records/preferences and current replay identities.

Primary owners: `tests/race_beams_playtest.gd`, `session_navigation_playtest.gd`, `session_navigation_landmark_probe.gd`, `session_navigation_landmark_preflight.gd`; `scripts/presentation/race_beams.gd`, `session_navigation_beams.gd` and session navigation UI.

### Active pass boundary - 2026-09-13

The user authorized a manual Shared functional/rendered pass and explicitly
excluded comparative frame time, 4K FPS, p95/p99 and GPU benchmarking. The 0/5/32
cases therefore exercise counts, lifecycle and native visibility only. Original
cost criteria remain precisely recorded as deferred; they are not reported as
passed. The blocked parent tasks are not redispatched. This follow-up may close
its user-adjusted functional scope while their cost gates remain blocked.

Live verification found a real fixture error: the historical navigation anchor
passes point_error but fails complete finish gate clearance. Retain it as a
negative fixture. The accepted bounded correction moves only the test finish
anchor 4 m; observer/heading stay exact, actual horizontal range is 499.493561 m,
and full race/gate/terrain/tree/camera predicates remain mandatory.

## Implementation approach

Inspect the exact engine identity values/formats in both reports; correct only an actual fixture mismatch and keep genuine engine/source drift checks. Reuse the supported500 m anchor(1334.710693,3218.149902,-676.801086), observer(1030.330078,3546.277832,-280.124390), heading2.487094262 and normal Connected60 km/h camera. Run the existing `--views-only --distant-only --navigation-500m` route for exactly four amber hidden/shown1080p/4K images. Then add/use a selective navigation route for the missing longitudinal five-marker15-second chronology, Reduced Motion and bounded0/5/32 cost. Inspect saved private investigation before implementing; do not assume an interrupted selective patch is complete.

## Acceptance and verification

- [x] Amber500 m captures pass real race endpoint/clearing, camera, identity and visible-pixel checks; preserve natural occlusion.
- [x] Five markers remain correctly ordered and persistent through the bounded route; Reduced Motion and0/5/32 scope are actually exercised.
- [x] Retain session-only lifetime,32-marker bound, unchanged timing/eligibility and terrain; document current evidence and close both originating tasks as criteria permit.
- [x] Record exact changed-source verification and commit/push the owned work with updated authoritative documentation.

Human acceptance: actual controller feel, listening and subjective visual approval remain separate follow-ups, not an unattended worker completion gate. Do not revive the cancelled broad player-acceptance task or claim the user tested these features.

## Open questions

None

## Completion record

Completed the user-adjusted functional/rendered scope on 2026-09-13. Production
physics, input, navigation, camera, terrain, beam style, replay/race and record
owners were not edited by this task. Neither blocked parent was redispatched.

- Fixed JSON numeric engine/camera receipt comparisons while retaining real
  build/hash/timestamp and captured source/runtime drift checks. Immutable v4
  evidence remains historical provenance, not current-source certification.
- The old navigation anchor passed point_error but failed full finish gate
  clearance. Candidate 3 of a bounded 33-candidate search qualifies at
  (1337.539063,3219.969727,-673.972656), 4 m from the old anchor. The observer,
  heading and normal Connected 60 km/h camera stay exact; horizontal range is
  499.493561 m. Four amber hidden/shown 1080p/4K images pass complete race/gate,
  camera, terrain/tree and native pixel checks. The narrow warm shaft remains
  visible against pale snow with natural lower occlusion. Prior 2 km/ridge/weather
  matrices were retained without repetition.
- Final guarded compact batch: 478 checks (finish 20, navigation 63, menu 24,
  interface 83, prompts 40, physics 56, runtime 192), stable source fingerprint.
  Engine normalization passed three positive/negative cases.
- Final native navigation: 207 checks, no failures, 17 stills plus nine chronology
  frames. Five stable ordered landmarks persist through 1,800 ticks / 15 seconds
  and 258.318 m of ordinary-input travel. Crest/near fade and collinear overlap
  are recorded; five separate silhouettes in every frame are not promised.
- Keyboard pan and simulated-controller reticle/focus/prompts, hide/show/limit,
  nonzero race clock/velocity/splits/eligibility/recorder/share retention, neutral
  resume, retry, summit return and free skiing pass. Compact tests also cover
  pointer placement/edit/delete/cancel, invalid terrain, held inputs/device change,
  marker 33, actual scene rebuild and physical-mountain reset. A new native app
  starts empty; 58 personal-file/inventory entries match. Only normal generation
  estimate telemetry changes, with its separate before/after receipt.
- Six capped 1080p 0/5/32 near/far images exercise count/render ownership.
  Normal/reduced/normal pairs verify all five shader clocks stop and resume while
  retaining steady shafts, IDs and positions. No timing producer is invoked.

Evidence is under `artifacts/beam_navigation_acceptance_20260913/`: `REVIEW.md`,
`regression-shared-final/`, `navigation-shared-final/`, `amber-shared-final/` and
`review-shared-final/`. All 30 final images were inspected. Native guards use
Shared, warm Standard terrain (6,144 m square, 4 m authority, 200,000 tree
obstacles), High Clear/Day, frame generation off and a 60 FPS cap. The compact
batch uses 256 x 512 m maps plus required full headless physics calibration.
Current read hashes include preserved concurrent grass/snow work. A non-runtime
grass build helper was excluded from the dependency set; its generated runtime
asset hashes stayed unchanged. Only owned task files are staged.

Both parent records remain blocked on original performance gates: matched,
screenshot-free old/new finish near/far frame/GPU cost and variance; same-scene
0/5/32 navigation near/far cost and variance with frame generation off. No
comparative frame-time, 4K FPS, p95/p99 or GPU benchmark ran. Physical-controller
feel, listening and subjective visual approval remain unperformed, separate human
acceptance. No new work was dispatched.

Delivery is the commit containing `changes/6764cc850279435984cbd8f4c0361ae9.json`;
`artifacts/beam_navigation_acceptance_20260913/delivery.json` records the full
pushed hash and Dev ID. Retain final/historical evidence for open parent reviews;
only task-owned empty/aborted output is eligible for immediate cleanup.

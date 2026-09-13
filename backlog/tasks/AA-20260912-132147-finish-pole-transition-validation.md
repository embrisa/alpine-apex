---
id: "AA-20260912-132147-finish-pole-transition-validation"
title: "Finish pole transitions and bounded animation validation"
status: "blocked"
priority: "P1"
depends_on: []
created: "2026-09-12T13:21:47Z"
updated: "2026-09-13T15:26:39Z"
source_thread: null
---

# Finish pole transitions and bounded animation validation

## Outcome

Remove the remaining visible arm jumps during pole recovery and landing while preserving planted contact and the new slope-limited propulsion.

## Current state and evidence

The 2026-09-13 model-32 D baseline reproduces 84/87 contact and 34/36 pose. A local uncommitted recovery candidate passes all original 87+36 checks, but expanded native coverage fails shaft/clothing clearance in 89/9,900 frames and the downhill speed-cap reproducer fails four contact/stroke limits. A simple force-boundary trial was rejected. Affected regressions are 344/345; the sole tuck hand-easing failure was previously reproduced on original source. The worker therefore records blocked, preserves the candidate without shipping it, and retains exact source/evidence for the remaining bounded correction. See the completion record and owning Validation guide.

Originating tasks: [AA-20260911-183812-slope-limited-pole-pushing](AA-20260911-183812-slope-limited-pole-pushing.md). Evidence: `artifacts/orchestration_20260912/poles/contact_d/validation/` and `artifacts/pose_review/revisions/20260912-poles-native-d-smoke/`. Measurements are from2026-09-12; private proposals and frozen captures are local, ignored evidence, not shipped dependencies. Recheck live source before applying a candidate.

## Agreed decisions and scope

The user explicitly requested this remaining work be saved for later, after stopping excessive agent/test usage. Authoring does not dispatch. Start with one worker and the smallest sufficient check; batch compatible checks, use the existing validation guard, and stop expanding coverage once the named criteria pass. Preserve120 Hz simulation,4 m terrain authority, personal records/preferences and current replay identities.

Primary owners: `scripts/presentation/pole_push_pose.gd`, `skier_full_motion.gd`, `skier_visual.gd`; `tests/pole_push_contact_suite.gd`, `pole_push_pose_suite.gd`, `pole_push_playtest.gd` and the maintained pose-review tools.

## Implementation approach

Start with the exact D receipts and optional E candidate in `artifacts/orchestration_20260912/poles/contact_e/`. Reproduce the three failing neighbors before changing fitting. Preserve the 14 cm bound, force-height/anchor limits, both loaded wrist strokes, outboard shaft clearance, fixed equipment sockets, editable Blender/export bytes and120 Hz actuator. E is a candidate, not an accepted fix. First run the existing contact/pose suites together. Only after they pass capture the missing bounded flat/gentle/steep/cutoff/downhill/steer/brake/departure chronology and inspect changed intervals plus actual clothing. Use15-second scenarios, not a full mountain.

## Acceptance and verification

- [x] Existing87 contact and36 pose checks pass without relaxed thresholds; inspect old and new worst neighbors.
- [ ] Final production chase/front/side cycles, takeoff/landing/cancellation and shaft/clothing inspection pass; run only affected animation/equipment regressions.
- [x] Record final source hashes, editable-source provenance, scoped CPU/native evidence and remaining human feel. Update Animation/Validation and the originating task.
- [ ] Record exact changed-source verification and commit/push the owned work with updated authoritative documentation.

Human acceptance: actual controller feel, listening and subjective visual approval remain separate follow-ups, not an unattended worker completion gate. Do not revive the cancelled broad player-acceptance task or claim the user tested these features.

## Open questions

None

## Completion record

Outcome: blocked; visual/contact acceptance is incomplete. No production fix is committed.

Current baseline: d9691c51630772c765aa1a180ff3e8e9e420cb05 (model32/replay7/archive4).
Current HEAD at recording: 794f1d5fae5b28494b4d8a390a006fc3e3885b1a; intervening
manager change is backlog coordination only. Native engine Godot4.7.2 custom
ed1daf0bf, D3D12 Forward+, RX9070; engine hashes in the evidence directory.

- Reproduced original contact84/87 and pose34/36. The local fifth-power elbow /
  10 percent unloaded reach candidate passes original87/87 and36/36 unchanged
  thresholds. Brake/landing15.1848->13.5386cm; steep10 14.1988->13.2045cm;
  steep5 14.1287->13.6364cm. Old/new worst neighboring poses were inspected.
- Eleven15-second native production chase/front/side captures contain9,900
  frames, including takeoff/landing and steering/braking/cancellation. Overall
  joint-step maximum13.7522cm; complete videos and selected consecutive pixels
  retained. Actual skinned-shaft audit FAILS89 frames: cutoff15-19 and downhill
  179-181,252-269,360-374,464-479,569-584,674-689. The other86 intersection frames
  have pole fitting inactive. No matched full D mesh baseline exists; no claim
  that all intersections were introduced or repaired by this candidate.
- Downhill extended fixture FAILS four unchanged gates: height23.8868cm>4,
  anchor residual76.9188cm>18, loaded tip step52.4633cm>10, minimum loaded wrist
  sweep3.6379cm<12. The cosmetic .001 request cutoff cancels with small positive
  completed thrust. A trial retaining contact until zero thrust fixed height
  but failed residual/step/stroke. That trial and temporary default-suite edit
  were rejected and restored; ignored patch/reproducer remain with evidence.
- Affected seven-suite regression344/345: anatomy84,compact36,attachment20,
  absorption155,airborne10,settle21 pass; motion18/19 fails120Hz tuck hand easing.
  That exact motion failure was previously reproduced on original source in
  AA-20260912-153317-fix-residual-carve-pelvis-lean; no new original-source rerun
  is claimed. Default output receipts were restored after preserving fresh ones.
- Editable blend/action/export/builder hashes match Blender5.2.1 LTS provenance.
  No assets, UIDs, solver/input/session,120Hz/4m authority or user records changed.
  CPU scopes0.517-0.610ms contact and1.426-1.539ms total final fit are overlapping
  single-pair diagnostics, not uncontended FPS/performance acceptance. Human
  controller feel, listening and subjective approval remain separate.

Owned WIP source: scripts/presentation/pole_push_pose.gd, SHA256
5e010fae19681e88336a2efef496ae47594a24bac4cafc96effbb8eb020c991d. The user
requested this exact incomplete candidate be preserved in an explicitly
unvalidated WIP snapshot, not treated as a shipped correction. It exactly
matches the frozen native capture. Full-motion and standard test bytes are HEAD.
The blocked record documents the known failures and remains the acceptance source;
the WIP commit neither resolves those failures nor changes the task's blocked status.

Maintained docs: Animation, Validation and the originating slope-limited-pole
pushing task. Evidence: artifacts/pole_transitions_20260913/review.md, comparison.json,
source_disposition.json, authoring_provenance.json, final/, force_boundary/,
regression/; artifacts/pose_review/revisions/20260913-poles-final/ (capture,
videos,review_sheets,pole-mesh-audit.json,frozen source). The directory name
"final" is not acceptance. Retain these unresolved-review outputs; cleanup is
deferred for active evidence. Prior unrelated/default evidence bytes restored.

Remaining bounded work: resolve downhill speed-cap plant/cancellation and shaft
clearance; distinguish ordinary inactive tuck intersections, then validate changed
neighbors with unchanged contact/stroke/clothing gates. Do not repeat completed
force/model matrices or full descents without new coverage need. Defined criteria
2 and4 remain open; original numerical/provenance criteria are evidenced only
for the local candidate. Ideas: none; existing task/tuck records own the findings.

Worker: `01a09825-711b-7873-8dec-afa573d29590`. Dispatch: `fcbd2859-15dc-45ad-81bf-6523ff89b9d2`.

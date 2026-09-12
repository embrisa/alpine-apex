---
id: "AA-20260912-132147-finish-pole-transition-validation"
title: "Finish pole transitions and bounded animation validation"
status: ready
priority: P1
depends_on: []
created: "2026-09-12T13:21:47Z"
updated: "2026-09-12T13:21:47Z"
source_thread: null
---

# Finish pole transitions and bounded animation validation

## Outcome

Remove the remaining visible arm jumps during pole recovery and landing while preserving planted contact and the new slope-limited propulsion.

## Current state and evidence

Current pole D fails three of 87 contact checks: brake departure0.149134 m, steep10 0.141987 m and steep5 0.141286 m exceed the existing0.14 m joint-step bound. The36-check pose suite also fails the 28/34-degree continuity checks. Other contact constraints pass. A full720-frame native shaft/clothing audit passes with zero intersections. The one-file private E candidate was never applied or engine validated.

Originating tasks: [AA-20260911-183812-slope-limited-pole-pushing](AA-20260911-183812-slope-limited-pole-pushing.md). Evidence: `artifacts/orchestration_20260912/poles/contact_d/validation/` and `artifacts/pose_review/revisions/20260912-poles-native-d-smoke/`. Measurements are from2026-09-12; private proposals and frozen captures are local, ignored evidence, not shipped dependencies. Recheck live source before applying a candidate.

## Agreed decisions and scope

The user explicitly requested this remaining work be saved for later, after stopping excessive agent/test usage. Authoring does not dispatch. Start with one worker and the smallest sufficient check; batch compatible checks, use the existing validation guard, and stop expanding coverage once the named criteria pass. Preserve120 Hz simulation,4 m terrain authority, personal records/preferences and current replay identities.

Primary owners: `scripts/presentation/pole_push_pose.gd`, `skier_full_motion.gd`, `skier_visual.gd`; `tests/pole_push_contact_suite.gd`, `pole_push_pose_suite.gd`, `pole_push_playtest.gd` and the maintained pose-review tools.

## Implementation approach

Start with the exact D receipts and optional E candidate in `artifacts/orchestration_20260912/poles/contact_e/`. Reproduce the three failing neighbors before changing fitting. Preserve the 14 cm bound, force-height/anchor limits, both loaded wrist strokes, outboard shaft clearance, fixed equipment sockets, editable Blender/export bytes and120 Hz actuator. E is a candidate, not an accepted fix. First run the existing contact/pose suites together. Only after they pass capture the missing bounded flat/gentle/steep/cutoff/downhill/steer/brake/departure chronology and inspect changed intervals plus actual clothing. Use15-second scenarios, not a full mountain.

## Acceptance and verification

- [ ] Existing87 contact and36 pose checks pass without relaxed thresholds; inspect old and new worst neighbors.
- [ ] Final production chase/front/side cycles, takeoff/landing/cancellation and shaft/clothing inspection pass; run only affected animation/equipment regressions.
- [ ] Record final source hashes, editable-source provenance, scoped CPU/native evidence and remaining human feel. Update Animation/Validation and the originating task.
- [ ] Record exact changed-source verification and commit/push the owned work with updated authoritative documentation.

Human acceptance: actual controller feel, listening and subjective visual approval remain separate follow-ups, not an unattended worker completion gate. Do not revive the cancelled broad player-acceptance task or claim the user tested these features.

## Open questions

None

## Completion record

Pending implementation. Record actual results, remaining limits, source/provenance and commit/push references. No worker is dispatched by this authoring change.

---
id: "AA-20260912-132147-finish-beam-navigation-acceptance"
title: "Finish shared beam and navigation acceptance"
status: ready
priority: P2
depends_on: []
created: "2026-09-12T13:21:47Z"
updated: "2026-09-12T13:21:47Z"
source_thread: null
---

# Finish shared beam and navigation acceptance

## Outcome

Complete the missing amber 500 m view and verify a useful sequence of session navigation markers without repeating accepted distant-view matrices.

## Current state and evidence

Navigation v4 passes167 checks and eight reviewed hidden/shown images at 500 m and2 km/ridge. Selection takes1.459 s and finds a finish-valid500 m anchor. Amber2 km/ridge and twelve weather images are accepted separately. The new amber 500 m route stops before captures on “Same identified native engine as navigation v4”. Earlier87 navigation UI/lifecycle checks do not close corrected five-point chronology, cost and Reduced Motion coverage.

Originating tasks: [AA-20260911-232811-taller-distant-finish-beam](AA-20260911-232811-taller-distant-finish-beam.md), [AA-20260911-232936-session-navigation-beams](AA-20260911-232936-session-navigation-beams.md). Evidence: `artifacts/orchestration_20260912/navigation/landmark-preflight-parent-v4/`, `finish/nav500/`, `amber_and_air/finish_500m.log`, and `navigation/landmark_v4/`. Measurements are from2026-09-12; private proposals and frozen captures are local, ignored evidence, not shipped dependencies. Recheck live source before applying a candidate.

## Agreed decisions and scope

The user explicitly requested this remaining work be saved for later, after stopping excessive agent/test usage. Authoring does not dispatch. Start with one worker and the smallest sufficient check; batch compatible checks, use the existing validation guard, and stop expanding coverage once the named criteria pass. Preserve120 Hz simulation,4 m terrain authority, personal records/preferences and current replay identities.

Primary owners: `tests/race_beams_playtest.gd`, `session_navigation_playtest.gd`, `session_navigation_landmark_probe.gd`, `session_navigation_landmark_preflight.gd`; `scripts/presentation/race_beams.gd`, `session_navigation_beams.gd` and session navigation UI.

## Implementation approach

Inspect the exact engine identity values/formats in both reports; correct only an actual fixture mismatch and keep genuine engine/source drift checks. Reuse the supported500 m anchor(1334.710693,3218.149902,-676.801086), observer(1030.330078,3546.277832,-280.124390), heading2.487094262 and normal Connected60 km/h camera. Run the existing `--views-only --distant-only --navigation-500m` route for exactly four amber hidden/shown1080p/4K images. Then add/use a selective navigation route for the missing longitudinal five-marker15-second chronology, Reduced Motion and bounded0/5/32 cost. Inspect saved private investigation before implementing; do not assume an interrupted selective patch is complete.

## Acceptance and verification

- [ ] Amber500 m captures pass real race endpoint/clearing, camera, identity and visible-pixel checks; preserve natural occlusion.
- [ ] Five markers remain correctly ordered and persistent through the bounded route; Reduced Motion and0/5/32 scope are actually exercised.
- [ ] Retain session-only lifetime,32-marker bound, unchanged timing/eligibility and terrain; document current evidence and close both originating tasks as criteria permit.
- [ ] Record exact changed-source verification and commit/push the owned work with updated authoritative documentation.

Human acceptance: actual controller feel, listening and subjective visual approval remain separate follow-ups, not an unattended worker completion gate. Do not revive the cancelled broad player-acceptance task or claim the user tested these features.

## Open questions

None

## Completion record

Pending implementation. Record actual results, remaining limits, source/provenance and commit/push references. No worker is dispatched by this authoring change.

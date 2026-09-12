---
id: "AA-20260912-132147-reduce-ten-ghost-presentation-cost"
title: "Reduce ten-ghost presentation and track submission cost"
status: ready
priority: P1
depends_on: ["AA-20260912-132147-finish-ghost-selector-and-render-fixtures"]
created: "2026-09-12T13:21:47Z"
updated: "2026-09-12T13:21:47Z"
source_thread: null
---

# Reduce ten-ghost presentation and track submission cost

## Outcome

Make ten selected animated ghosts cheaper while preserving their visible motion, equipment and independent snow trails.

## Current state and evidence

A single contended20-second lab comparison at 4K High/Auto75/FGoff measured frame means11.798/11.616/17.862/16.648 ms for0/1/10/10-without-tracks. Ten ghosts add4.221 ms presentation CPU and3.491 ms GPU mean versus zero; removing their tracks saves1.175 ms presentation CPU. These are scoped measurements, not a full-mountain baseline.

Originating tasks: [AA-20260911-220556-animated-ghost-snow-tracks](AA-20260911-220556-animated-ghost-snow-tracks.md). Evidence: `artifacts/ghost/profile-v1/profile_results.json` and `artifacts/orchestration_20260912/ghost/PROFILE_REVIEW.md`. Measurements are from2026-09-12; private proposals and frozen captures are local, ignored evidence, not shipped dependencies. Recheck live source before applying a candidate.

## Agreed decisions and scope

The user explicitly requested this remaining work be saved for later, after stopping excessive agent/test usage. Authoring does not dispatch. Start with one worker and the smallest sufficient check; batch compatible checks, use the existing validation guard, and stop expanding coverage once the named criteria pass. Preserve120 Hz simulation,4 m terrain authority, personal records/preferences and current replay identities.

Primary owners: `scripts/presentation/ghost_field.gd`, `personal_best_ghost.gd`, `ghost_track_stack.gd`, `ghost_pose.gd` and `assets/graphics/ghost_skier.gdshader`.

## Implementation approach

Profile allocation, repeated transform decoding/material updates and history submission on the existing matched scenario, then change the measured ghost-specific bottleneck. Coordinate with the already-ready general animation-CPU and dense-scene-GPU tasks(AA-20260912-105301/105302); do not duplicate their player pose/terrain work. Preserve complete poses, interpolation,15% opacity floor, all ten visible ghosts, actual depth, independent bounded320-stamp histories and player history. Do not obtain a gain by silently lowering ghost count, hiding distant ghosts, disabling tracks or changing global quality. The user waived FPS targets during the original run; record a measured improvement rather than inventing a90/120 FPS requirement.

## Acceptance and verification

- [ ] One justified matched0/1/10/10-no-tracks comparison shows the affected cost reduced without a new major memory/frame-tail regression; expand only for unexplained results.
- [ ] Existing pose/track/lifecycle checks and changed native cases retain motion, attachments, colour and ownership.
- [ ] Document CPU/GPU scopes and settings, coordinate shared-file ownership and update the ghost performance limitation.
- [ ] Record exact changed-source verification and commit/push the owned work with updated authoritative documentation.

Human acceptance: actual controller feel, listening and subjective visual approval remain separate follow-ups, not an unattended worker completion gate. Do not revive the cancelled broad player-acceptance task or claim the user tested these features.

## Open questions

None

## Completion record

Pending implementation. Record actual results, remaining limits, source/provenance and commit/push references. No worker is dispatched by this authoring change.

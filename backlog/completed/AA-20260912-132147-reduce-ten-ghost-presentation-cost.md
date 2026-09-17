---
id: "AA-20260912-132147-reduce-ten-ghost-presentation-cost"
title: "Reduce ten-ghost presentation and track submission cost"
status: done
priority: P1
depends_on: []
created: "2026-09-12T13:21:47Z"
updated: "2026-09-17T01:35:24Z"
source_thread: null
---

# Reduce ten-ghost presentation and track submission cost

## Historical disposition — 16 September 2026

Independent of the selector and pole tasks: benchmark the existing ten-ghost
roster. Dev61/63 already reduce routine recording to 20 Hz and reuse recent
displayed rigs; that is recording cost, not proof that drawing ten ghosts is cheap.
The user explicitly accepts coarser animations for other ghosts/people. A bounded
lower playback update cadence with interpolation is authorized if it reduces
measured work while keeping root timing, equipment attachment, recognizable
actions and independent trails. Preserve all selected ghosts and quality settings.
This supersedes older pixel-exact/cadence wording below. Reuse a suitable saved
reference and measure one candidate; use the old 0/1/10/no-tracks matrix only
if attribution actually requires it.

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

- [x] One justified matched0/1/10/10-no-tracks comparison shows the affected cost reduced without a new major memory/frame-tail regression; expand only for unexplained results.
- [x] Existing pose/track/lifecycle checks and changed native cases retain motion, attachments, colour and ownership.
- [x] Document CPU/GPU scopes and settings, coordinate shared-file ownership and update the ghost performance limitation.
- [x] Record exact changed-source verification and commit/push the owned work with updated authoritative documentation.

Human acceptance: actual controller feel, listening and subjective visual approval remain separate follow-ups, not an unattended worker completion gate. Do not revive the cancelled broad player-acceptance task or claim the user tested these features.

## Open questions

None

## Completion record

Completed on 17 September 2026. Delivery is the commit containing development
note `a32d682a14a94de496eb848baf6bfce9`.

Each ghost now retains only its two current decoded recording frames, reusing
local transforms and equipment sockets across render frames. The old second
frame is reused as the next first frame. Root, limbs, equipment and track response
keep their existing interpolation and cadence; no count, opacity or quality cut.

One current ten-ghost control and one visually accepted candidate were measured
under FpsCritical on the same 15-second laboratory route (first two seconds
excluded), 3840×2160 output / 2880×1620 internal, preset 7 High, Auto FSR 4.1.1,
uncapped, frame generation off. Both were focused, capture-free while timed and
retained all ten ghosts and 3,200 trail stamps. This focused comparison follows
the current one-candidate policy; the old full 0/1/10 matrix was unnecessary for
this measured repeated-pose-work hypothesis.

| Measure | Control | Candidate |
|---|---:|---:|
| Frame mean | 12.7013 ms | 11.1797 ms |
| Rendered FPS (1000 / mean frame ms) | 78.73 | 89.45 |
| Frame p95 / p99 | 15.598 / 18.478 ms | 13.990 / 15.640 ms |
| Whole presentation CPU mean | 5.8996 ms | 4.7318 ms |
| Separate ten-pose application probe | 2.4247 ms | 1.2549 ms |
| Observed renderer GPU mean | 7.4053 ms | 6.7406 ms |

Frame time fell 11.98%, FPS rose 13.61%, and the isolated pose probe fell 48.25%.
The change targets CPU work; the GPU observation does not prove a shader or
geometry saving. Static memory increased by 187,276 bytes (about 0.18 MiB), with
two cached frames per visual. These are lab results, not a replacement for the
dense-forest baseline or full-mountain acceptance.

Validation: 5,122 cached/uncached pose, attachment, contact and reverse/reset/
replacement checks; 224 capture-reuse checks; all six actual contact cases and
all 231 focused native checks pass. Inspected turn entry/hold/release, switch
landing, one-ski reentry, rock/snow reentry, jump/landing and palette images before
timing. Existing pole animation limitations are unchanged. Human appearance and
controller acceptance remain separate; no physics/race/replay changes.

Evidence and commands: `artifacts/ghost_playback_20260917/REVIEW.md`, `control/`,
`candidate/`, `visual/` and `regression-accepted/`. The maintained native producer
now accepts a single ghost count/short profile window and reports focus plus a
separate pose CPU probe. See Validation and Animation for the durable contracts.

New idea for the later ideas phase: [skip unchanged ghost material parameters](../ideas/IDEA-20260917-013000-skip-unchanged-ghost-material-updates.md).


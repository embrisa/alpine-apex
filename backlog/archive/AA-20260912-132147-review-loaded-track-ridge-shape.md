---
id: "AA-20260912-132147-review-loaded-track-ridge-shape"
title: "Resolve pronounced loaded snow-track ridge shapes"
status: "done"
priority: "P2"
depends_on: []
created: "2026-09-12T13:21:47Z"
updated: "2026-09-13T07:42:12.542171Z"
source_thread: null
---

# Resolve pronounced loaded snow-track ridge shapes

## Outcome

Keep loaded carving trails continuous while making the pronounced scalloped or triangular banks look like displaced snow.

## Current state and evidence

Standard carving frames217-233 and boundary before/after reviews retain conspicuous loaded banks. Loaded response/bank formulas predate the continuity feature, but the change fromXYZ toXZ retained-stamp distance may affect their prominence; causality is unisolated. The accepted v3 continuity fixes and12 mm cosmetic continuation are separate results. Crystal include changes also prevent attributing every before/after highlight difference to the boundary.

Originating tasks: [AA-20260911-225724-carving-raised-ski-tracks](../tasks/AA-20260911-225724-carving-raised-ski-tracks.md), [AA-20260912-005323-subtle-local-snow-boundary](../tasks/AA-20260912-005323-subtle-local-snow-boundary.md). Evidence: `artifacts/orchestration_20260912/carving/world_shape/REVIEW.md`, `artifacts/local_snow_boundary/matrix_v5/`, and the two independent boundary review reports. Measurements are from2026-09-12; private proposals and frozen captures are local, ignored evidence, not shipped dependencies. Recheck live source before applying a candidate.

## Agreed decisions and scope

The user explicitly requested this remaining work be saved for later, after stopping excessive agent/test usage. Authoring does not dispatch. Start with one worker and the smallest sufficient check; batch compatible checks, use the existing validation guard, and stop expanding coverage once the named criteria pass. Preserve120 Hz simulation,4 m terrain authority, personal records/preferences and current replay identities.

Primary owners: `scripts/presentation/snow_response.gd`, `snow_tracks.gd`, `powder_surface.gd` and their current snow shaders; `tests/carving_raised_ski_tracks_capture.gd`.

## Implementation approach

Use one bounded matched ordinary carving passage and fixed shader dependencies to separate stamp spacing, overlap/join geometry and loaded depth/bank shape. Inspect original-scale chronological pixels before selecting a minimal visual correction. Preserve4 m support, all physical forces/load, current live alignment and the bounded shallow cosmetic track contract; never give airborne/rock/void skis snow permission to conceal gaps. Keep the boundary cache, circular fade and atomically published support intact.

## Acceptance and verification

- [x] Before/after neighboring frames establish the cause and show improved ridge shape on both turn signs/reversal without new seams.
- [x] Loaded tracks, lightly raised grounded continuation and jump/rock/teleport breaks retain accepted behavior; run only affected CPU/GPU checks.
- [x] Record actual art/performance limits and provenance; do not claim either that the old feature caused every ridge or that agreement between boundary modes proves it harmless.
- [x] Record exact changed-source verification and commit/push the owned work with updated authoritative documentation.

Human acceptance: actual controller feel, listening and subjective visual approval remain separate follow-ups, not an unattended worker completion gate. Do not revive the cancelled broad player-acceptance task or claim the user tested these features.

## Open questions

None

## Completion record

Completed on 2026-09-13 by direct user instruction after the dirty-read conflict
was fixed in `3f5157a76a730597820cd9ca3c525aeec79dbbfb`. The original scheduled
dispatch was released after blocked record `0f2fbd801c01ab9139d28a06dc7bcdf38e4fb97e`;
this manual continuation took no replacement claim. The idle pole candidate and
intentional ghost-selector task edits remained byte-for-byte unchanged.

High's raised ribbon rectangles contributed duplicate stepped banks over the
filtered powder surface. With stamp spacing and every other runtime input fixed,
fading loaded overlay opacity from 12 to 35 mm inside the existing local relief
fade improved both turn signs and reversal. The 12 mm shallow ribbon, physics,
4 m support, snow permission, live/history placement, GPU stamping and boundary
publication remain unchanged. Owning guide: `docs/RENDERING.md`.

Paired 15-second aggregate native captures have identical complete runtime
telemetry across 900 frames. Original 1920x1080 neighboring frames were inspected
chronologically on left/right (158,160,162), reversal (188,190,192), plus left250.
The final 20-second aggregate left/right/reversal/jump capture passed with 1,200
frames, stable sources and unchanged physics. Jump frames88,90,96,98 show the
airborne break and landing restart. Native verification passed 129 contact,
22 boundary and 7 GPU checks. The original fixture's five false continuity
failures at reversal263-265 were independently traced to rendered ski tips on
rock; only its expected snow window changed. Runtime rejection was preserved.

Evidence: [resumed review](../../artifacts/loaded_track_ridge_20260913/RESUMED_REVIEW.md),
[exact comparison](../../artifacts/loaded_track_ridge_20260913/comparison.json),
[final capture results](../../artifacts/loaded_track_ridge_20260913/final/results.json).
The comparison verifies all final manifest hashes and only two changed source
paths among 673 snapshots: the shader and capture test. The test now records its
shader includes and preserved pole dependency. Initial blocking evidence remains
in [the historical investigation](../../artifacts/loaded_track_ridge_20260913/REVIEW.md).

Limits: small scallops and shallow/live segment shape remain; fixed current
spacing does not exonerate the historical XYZ-to-XZ spacing change. Native High
only was visually reviewed. Low/Balanced source behavior is unchanged. No
performance, full-descent, multi-weather, human/controller/listening acceptance
is claimed. No new ideas were proposed. Paired/final review evidence is retained;
redundant rejected-candidate JPGs are eligible for cleanup after push, with an
exact receipt in the evidence directory. The implementation delivery is the
commit containing this completion record.

Original worker: `01a0984c-222b-72f3-baea-738f4131865d`. Released dispatch:
`f4584f80-5f8c-425d-8de2-e1383da8cd5a`.

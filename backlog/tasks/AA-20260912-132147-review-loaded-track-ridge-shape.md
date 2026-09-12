---
id: "AA-20260912-132147-review-loaded-track-ridge-shape"
title: "Resolve pronounced loaded snow-track ridge shapes"
status: ready
priority: P2
depends_on: []
created: "2026-09-12T13:21:47Z"
updated: "2026-09-12T13:21:47Z"
source_thread: null
---

# Resolve pronounced loaded snow-track ridge shapes

## Outcome

Keep loaded carving trails continuous while making the pronounced scalloped or triangular banks look like displaced snow.

## Current state and evidence

Standard carving frames217-233 and boundary before/after reviews retain conspicuous loaded banks. Loaded response/bank formulas predate the continuity feature, but the change fromXYZ toXZ retained-stamp distance may affect their prominence; causality is unisolated. The accepted v3 continuity fixes and12 mm cosmetic continuation are separate results. Crystal include changes also prevent attributing every before/after highlight difference to the boundary.

Originating tasks: [AA-20260911-225724-carving-raised-ski-tracks](AA-20260911-225724-carving-raised-ski-tracks.md), [AA-20260912-005323-subtle-local-snow-boundary](AA-20260912-005323-subtle-local-snow-boundary.md). Evidence: `artifacts/orchestration_20260912/carving/world_shape/REVIEW.md`, `artifacts/local_snow_boundary/matrix_v5/`, and the two independent boundary review reports. Measurements are from2026-09-12; private proposals and frozen captures are local, ignored evidence, not shipped dependencies. Recheck live source before applying a candidate.

## Agreed decisions and scope

The user explicitly requested this remaining work be saved for later, after stopping excessive agent/test usage. Authoring does not dispatch. Start with one worker and the smallest sufficient check; batch compatible checks, use the existing validation guard, and stop expanding coverage once the named criteria pass. Preserve120 Hz simulation,4 m terrain authority, personal records/preferences and current replay identities.

Primary owners: `scripts/presentation/snow_response.gd`, `snow_tracks.gd`, `powder_surface.gd` and their current snow shaders; `tests/carving_raised_ski_tracks_capture.gd`.

## Implementation approach

Use one bounded matched ordinary carving passage and fixed shader dependencies to separate stamp spacing, overlap/join geometry and loaded depth/bank shape. Inspect original-scale chronological pixels before selecting a minimal visual correction. Preserve4 m support, all physical forces/load, current live alignment and the bounded shallow cosmetic track contract; never give airborne/rock/void skis snow permission to conceal gaps. Keep the boundary cache, circular fade and atomically published support intact.

## Acceptance and verification

- [ ] Before/after neighboring frames establish the cause and show improved ridge shape on both turn signs/reversal without new seams.
- [ ] Loaded tracks, lightly raised grounded continuation and jump/rock/teleport breaks retain accepted behavior; run only affected CPU/GPU checks.
- [ ] Record actual art/performance limits and provenance; do not claim either that the old feature caused every ridge or that agreement between boundary modes proves it harmless.
- [ ] Record exact changed-source verification and commit/push the owned work with updated authoritative documentation.

Human acceptance: actual controller feel, listening and subjective visual approval remain separate follow-ups, not an unattended worker completion gate. Do not revive the cancelled broad player-acceptance task or claim the user tested these features.

## Open questions

None

## Completion record

Pending implementation. Record actual results, remaining limits, source/provenance and commit/push references. No worker is dispatched by this authoring change.

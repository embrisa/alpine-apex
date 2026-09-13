---
id: "AA-20260912-132147-review-loaded-track-ridge-shape"
title: "Resolve pronounced loaded snow-track ridge shapes"
status: "blocked"
priority: "P2"
depends_on: []
created: "2026-09-12T13:21:47Z"
updated: "2026-09-13T01:12:30.938554Z"
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

Blocked on 2026-09-13 before fresh rendered isolation; no production correction applied.

Exact dispatch accepted as worker `01a0984c-222b-72f3-baea-738f4131865d`, token
`f4584f80-5f8c-425d-8de2-e1383da8cd5a`, original manager
`01a09848-a968-7251-bd4c-3876c739af35`. Source baseline was pushed main
`2f2d64c0e4b9c1c45d731ec7b9cf2575f4cb11d7`, simulation model 32.

**Blocker:** atomic expansion to reserve the production capture dependency closure
returned `skipped: Expanded scope overlaps unfinished paths: scripts/presentation/pole_push_pose.gd`.
The pole worker was freshly verified idle after its blocked delivery, but its
candidate remains deliberately uncommitted and peer-owned. The capture loads
main -> skier_visual -> skier_animation -> skier_full_motion -> pole_push_pose,
steps production animation, and consumes final rendered skis. Removing that
dependency from the declared read scope would not make the capture independent.
No skipped scope was bypassed, no peer file/reservation was changed, and no
engine workload or comparative timing was launched.

Independent investigation: current loaded response, SnowTracks, ribbon shader,
compute shader and shared powder include match the earlier source diagnosis;
PowderSurface itself has since changed. Retained ribbons have one width/depth
per 0.70 m rectangle and no longitudinal bank fade, and add their raised lip over
High's reconstructed powder height. Integer-max GPU impressions do not add
repeated shallow depths. This supports a ribbon-bank/join hypothesis; spacing,
overlap and GPU contributions remain unisolated. No speculative depth clamp or
eligibility change was applied.

Evidence: [investigation](../../artifacts/loaded_track_ridge_20260913/REVIEW.md),
[source/image manifest](../../artifacts/loaded_track_ridge_20260913/manifest.json),
and exact source snapshots under that artifact directory. Three historical
1920x1080 frames (217, 218, 223) were inspected in chronological order at original
scale. They show the old scalloped/triangular banks; they are not fresh model-32
before/after evidence and do not establish a correction. All implementation
acceptance boxes remain open.

Automated checks: source/hash/provenance inspection, task-record validation and
owned-document whitespace/link verification. No CPU/GPU engine suite rerun;
no implementation changed. Fresh bounded left/right/reversal rendering,
affected correctness checks and changed-source verification remain outstanding.
Measured performance and human/controller/listening acceptance were not run or
claimed. Owning guide updated: `docs/RENDERING.md` explains the distinct ribbon
bank and reconstructed powder mechanisms. No changes to solver, 4 m support,
continuity/exclusion gates, boundary publication, records or preferences.

Resume after an explicit resolution of the preserved pole candidate's ownership
and a stable capture baseline, then obtain a successful fresh scope expansion
before the matched 15-30 second causal capture. Resolve only this task; the
paused dense-scene GPU work stays paused. No new idea proposals: this assigned
task already covers the evidence-backed next steps.

Delivery is the documentation/blocked-record commit containing this entry;
no source implementation commit exists. Push and exact-token release are
required before ending. Retain the small unresolved evidence bundle; no
redundant task-owned captures or engine artifacts were generated, so no cleanup
is due. Peer pole source and the incomplete ghost-selector feedback remain
uncommitted and untouched.

Worker: `01a0984c-222b-72f3-baea-738f4131865d`. Dispatch: `f4584f80-5f8c-425d-8de2-e1383da8cd5a`.

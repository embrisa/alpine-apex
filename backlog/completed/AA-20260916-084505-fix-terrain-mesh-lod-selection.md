---
id: "AA-20260916-084505-fix-terrain-mesh-lod-selection"
title: "Evaluate terrain LOD savings on an open route"
status: done
priority: P2
depends_on: []
created: "2026-09-16T08:45:05Z"
updated: "2026-09-17T08:11:14Z"
source_thread: null
---

# Evaluate terrain LOD savings on an open route

## Outcome

Determine whether existing render-only terrain LODs help an open slope/ridge view
without visible cracks or objectionable transition changes.

## Current state and evidence

Dev52 already proved that terrain LOD selection works. `lod_bias=0.25` reduced
dense-route primitives by 1.74%, but 91.06 to 90.68 FPS and 9.943 to 9.923 ms GPU
did not justify retaining it; the runtime source was restored. Open-route timing
and unobscured ridge motion remain untested. Current preparation retained 478
chunks in that observation, not the original task's assumed 576.

## Agreed decisions and scope

Own terrain render LOD keys/bias and prepared scenery identity if needed. Keep
the physical 4 m terrain, collision, placement, powder and track authority.
Small visual differences are permitted for verified gains; cracks, disappearing
ridge silhouettes and support mismatches are not an acceptable implementation.

## Implementation approach

Select one open-route view where terrain geometry is material. Use the existing
LOD indices and one justified setting. Inspect an unobscured ridge and transitions
first, then one short warmed candidate against the matching saved reference.
Do not repeat the failed dense-only bias experiment or launch a key-value matrix.

## Acceptance and verification

- [x] Open-slope/ridge stills and bounded motion retain continuity and useful snow detail.
- [x] Actual frame/GPU cost and tails accompany any primitive reduction; negative
  results are a valid completed investigation, not a production change.
- [x] Run affected terrain/rendering checks and runtime; physics checks if its
  inputs change. Update Rendering and commit/push only a justified result.

Human continuous-motion acceptance remains separate.

## Open questions

None

## Completion record

Completed with a retained small open-route gain. Terrain instance bias 0.25
uses the existing simplified indices in direct/prepared publication; physical
terrain, collision, base mesh and shared chunk borders remain unchanged.

One warmed matched pair: 126.40294 -> 128.90999 FPS (+1.983%), frame
7.911209 -> 7.757350 ms, GPU 6.062035 -> 5.952341 ms. Frame p95/p99
9.898/12.225 -> 9.532/11.008 ms; GPU p99 6.691 -> 6.714 ms. Submitted primitives
2,826,158 -> 2,629,457 (-6.960%). Capture-free 4K High Auto75/FSR4.1.1, FGoff;
same 1,800 ordinary-input ticks, 301 timed poses and final state; focus0/failures[].
The 15 s open route reaches 32.28 km/h, with no nearby trees or obstacle contacts.
It is not the dense baseline or a sustained/high-speed performance claim.

Matched 4K upper-snow/ridge samples over a 120 m diagnostic dolly retain near
silhouettes and ground continuity. Minor shading changes are accepted. Continuous
human motion review stays separate. Actual direct/prepared integration probe
preserves base vertices/indices/collision; graphics29/runtime192 pass.

Report: `artifacts/terrain_open_20260917/REVIEW.md`; milestone note:
`changes/e768cd0048174250b9fa0459ec3f05ca.json`. The prior dense-route rejection
below remains a scope limit; no new dense improvement is asserted.

## Earlier investigation record

Partly investigated on Windows at Dev 52. Runtime terrain `lod_bias=0.25`
using the existing LOD indices reduced dense-route primitives by 1.74%, but
91.06 -> 90.68 FPS and GPU 9.943 -> 9.923 ms showed no useful gain. Restored
`alpine_world.gd`; no production terrain change retained. Native wireframe
confirmed LOD selection, and open-snow stills passed; two foliage-obscured views
do not establish ridge quality. Current mountain has 478 retained chunks.
The later open-route completion above resolves this remaining question; do not
repeat the dense-only experiment as if its earlier result had been a gain.
Compact local evidence: `artifacts/terrain_lod_20260916/REPORT.md` and
`artifacts/pc_environment/terrain-lod-20260916/production.json` row 2.

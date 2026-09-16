---
id: "AA-20260916-084505-fix-terrain-mesh-lod-selection"
title: "Evaluate terrain LOD savings on an open route"
status: ready
priority: P2
depends_on: []
created: "2026-09-16T08:45:05Z"
updated: "2026-09-16T21:59:44Z"
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

- [ ] Open-slope/ridge stills and bounded motion retain continuity and useful snow detail.
- [ ] Actual frame/GPU cost and tails accompany any primitive reduction; negative
  results are a valid completed investigation, not a production change.
- [ ] Run affected terrain/rendering checks and runtime; physics checks if its
  inputs change. Update Rendering and commit/push only a justified result.

Human continuous-motion acceptance remains separate.

## Open questions

None

## Completion record

Ready for the untested open-route question. The dense-route rejection is retained below.

## Earlier investigation record

Partly investigated on Windows at Dev 52. Runtime terrain `lod_bias=0.25`
using the existing LOD indices reduced dense-route primitives by 1.74%, but
91.06 -> 90.68 FPS and GPU 9.943 -> 9.923 ms showed no useful gain. Restored
`alpine_world.gd`; no production terrain change retained. Native wireframe
confirmed LOD selection, and open-snow stills passed; two foliage-obscured views
do not establish ridge quality. Current mountain has 478 retained chunks.
Do not repeat this same dense-route candidate. Open-route timing, ridge-motion
review and alternative keys remain untested; this task remains ready.
Compact local evidence: `artifacts/terrain_lod_20260916/REPORT.md` and
`artifacts/pc_environment/terrain-lod-20260916/production.json` row 2.

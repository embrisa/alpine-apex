---
id: "AA-20260916-084505-fix-terrain-mesh-lod-selection"
title: "Make terrain chunk mesh LODs actually select within the playable distance"
status: ready
priority: P1
depends_on: []
created: "2026-09-16T08:45:05Z"
updated: "2026-09-16T14:41:25Z"
source_thread: null
---

# Make terrain chunk mesh LODs actually select within the playable distance

## Outcome

Reduce depth pre-pass, opaque and shadow geometry cost on every route by
letting the already-generated terrain LOD index sets take effect at sensible
distances, with no visible change in silhouette or snow detail near the rider.

## Current state and evidence

- Source inspected at Dev 43 / `a9c2acb` (2026-09-16).
  [`alpine_world.gd:294`](../../scripts/world/alpine_world.gd) and
  [`terrain_preparation.gd:11`](../../scripts/world/terrain_preparation.gd)
  build every summit-mountain chunk with
  `lods = {0.7: step-4 indices, 3.0: step-8 indices}`. Godot's
  `ArrayMesh.add_surface_from_arrays` LOD keys are world-space edge lengths;
  the renderer selects a LOD when that edge projects below
  `mesh_lod_threshold` pixels (default 1 px). With a 2880 px internal width
  and a 55 degree vertical field of view, a 0.7 m edge stays above 1 px until
  roughly 1.1 km, and 3.0 m until roughly 4.8 km. At 4K output nearly the whole
  playable disk therefore renders at full 4 m tessellation: 576 chunks of 8,192
  triangles (about 4.7 M triangles) plus the per-vertex cloud noise in
  [`alpine_surface.gdshader`](../../assets/graphics/alpine_surface.gdshader).
  No `lod_bias` is set on terrain chunks (`alpine_world.gd:329-333, 495-497`).
- Recorded GPU attribution (docs/RENDERING_BASELINE.md summary and the native
  pass table in [the GPU task](AA-20260912-105302-reduce-dense-scene-gpu-cost.md))
  puts depth pre-pass at 1.5-4.7 ms and opaque 1.0-2.8 ms per frame; terrain
  is a large share of both on open routes (open snow GPU 7.1 ms at 105 FPS).
  Median submissions are about 13.7 M primitives per frame in dense forest.
- The derivation above is analytic. Confirm first with the
  `RENDER_TOTAL_PRIMITIVES_IN_FRAME` monitor (already sampled by
  `tests/performance_descent.gd`) while varying `Viewport.mesh_lod_threshold`
  or the keys, and with a wireframe or LOD-tinted debug capture.
- Related ownership: [the GPU task](AA-20260912-105302-reduce-dense-scene-gpu-cost.md)
  lists render-only terrain LOD among its candidate directions; this task is
  the narrow, independently measurable hypothesis for it and does not wait for
  the blocked baseline task because it reuses
  [DENSE_FOREST_BASELINE.json](../../docs/DENSE_FOREST_BASELINE.json) and the
  open-route receipt under the economical policy. Update the GPU task's record
  with the result. Physical terrain, the 4 m authority and collision are not
  touched; this is presentation geometry only.

## Agreed decisions and scope

Own the LOD key values and any `lod_bias`/threshold setting in
`scripts/world/alpine_world.gd`, `scripts/world/terrain_preparation.gd` and the
scenery cache version if prepared chunk arrays embed the keys (check
`scripts/world/scenery_cache.gd`; a cache key bump is acceptable, a physical
generator bump is not). Preserve powder patch, snow tracks and grass seating,
which read heights from the authority, not from the mesh. Do not change the
step-4/step-8 index generation itself unless a crack-free skirt is needed
between LOD levels; if cracks appear at boundaries, prefer Godot's per-surface
LOD with matching edge indices or a small skirt over disabling the change.

## Implementation approach

1. Measure primitives per frame and GPU ms on the open and forest traces at
   the current keys, then with keys around 0.12 and 0.35 (about 200 m and
   580 m at 4K High) or an equivalent `lod_bias`. Capture matched stills with a
   LOD debug tint to confirm where each level engages.
2. Inspect near-ridge silhouettes, snow crystal/relief transitions and shadow
   edges at the LOD1 boundary at 4K High; pick the nearest distance that shows
   no visible change in stills and motion.
3. Apply the keys (and cache bump if required), then run one warmed 15-second
   candidate per route against the saved baselines.

## Acceptance and verification

- [ ] Primitives per frame fall measurably on both routes with LOD1 engaging
  inside the playable distance; document the chosen keys and the derivation.
- [ ] No visible cracks, popping or snow detail loss in matched native stills
  and a short motion capture at 4K High at the LOD boundaries.
- [ ] `tests/generated_mountain_suite.gd`, `tests/scenery_loading_suite.gd`,
  `tests/render_efficiency_suite.gd`, `tests/snow_grounding_suite.gd`,
  `tests/physics_suite.gd` and `tests/runtime_suite.gd` pass; replay endpoints
  unchanged.
- [ ] One warmed capture-free candidate per route with GPU ms, frame means and
  p95/p99 versus the saved baselines; retain the result even if negative.
- [ ] Update [Rendering](../../docs/RENDERING.md#terrain-forests-and-lighting)
  with the LOD contract, commit/push with a development note and Dev ID.

Human acceptance: a quick look at ridge silhouettes during a descent is a
follow-up, not a gate, provided stills show no change.

## Open questions

None

## Completion record

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

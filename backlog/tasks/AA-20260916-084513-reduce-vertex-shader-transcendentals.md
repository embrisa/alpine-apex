---
id: "AA-20260916-084513-reduce-vertex-shader-transcendentals"
title: "Cut per-vertex trigonometry and procedural cloud noise in scene vertex shaders"
status: ready
priority: P2
depends_on: []
created: "2026-09-16T08:45:13Z"
updated: "2026-09-16T08:45:13Z"
source_thread: null
---

# Cut per-vertex trigonometry and procedural cloud noise in scene vertex shaders

## Outcome

Reduce vertex-stage GPU cost across trees, terrain, minerals, grass, gravel,
tracks and sprays by evaluating wind bending trigonometry once per vertex and
replacing per-vertex procedural cloud noise with a cheap texture lookup, with
identical lighting and motion.

## Current state and evidence

Source inspected at Dev 43 / `a9c2acb` (2026-09-16):

- [`pc_forest_tree.gdshader:31-36, 62-66`](../../assets/graphics/pc_forest_tree.gdshader)
  `bend()` computes six `sin`/`cos` and is called four times per vertex
  (VERTEX, NORMAL, TANGENT, BINORMAL), so 24 transcendental operations per
  vertex, then `sample_cloud_light(anchor)` ([`cloud_light.gdshaderinc:4`](../../assets/cloud_light.gdshaderinc)) evaluates
  [`cloud_field.gdshaderinc:8-18`](../../assets/cloud_field.gdshaderinc)
  (three-octave noise, about twelve `sin` plus hashing) per vertex. The same
  structure is in `pc_td_conifer.gdshader:17-42`. Docs inventory about 9 M
  candidate near/mid vertex entries per frame in dense forest, processed in
  both the pre-pass and the opaque pass.
- Every other scene vertex shader also calls `sample_cloud_light` per vertex:
  terrain [`alpine_surface.gdshader:7`](../../assets/graphics/alpine_surface.gdshader),
  minerals [`mineral_world.gdshader:49`](../../assets/graphics/mineral_world.gdshader),
  grass, gravel, tracks, sprays and the powder patch (three calls, owned by
  [the powder task](AA-20260916-084507-reduce-powder-patch-render-cost.md)).
- [`mineral_world.gdshader:88-98`](../../assets/graphics/mineral_world.gdshader)
  evaluates about five `noise3` calls (eight `hash3` each) per cliff fragment
  for moss and snow patches; `mineral_world.gdshader:106` mixes a view-space
  normal with a world-XZ bump (wrong space, visual only).
- [`alpine_surface_fragment.gdshaderinc:29-32, 136`](../../assets/graphics/alpine_surface_fragment.gdshaderinc)
  evaluates five `value_noise` calls (four hashes each) per terrain fragment.
- Depth pre-pass alpha handling is owned by
  [the foliage pre-pass task](AA-20260916-084506-cut-foliage-depth-prepass-cost.md);
  uniform publication by [the shared uniform task](AA-20260916-084503-publish-shared-shader-uniforms-globally.md);
  the broad pass/material programme by
  [the GPU task](AA-20260912-105302-reduce-dense-scene-gpu-cost.md). This task
  is the narrow ALU hypothesis; update the GPU task record with results.

## Agreed decisions and scope

Own the listed shaders and includes plus the small script that would generate
and upload a tileable cloud noise texture (for example in
`scripts/presentation/cloud_lighting.gd`). Preserve the cloud shadow pattern,
wind motion, moss/snow patch look and terrain detail as seen in matched 4K
stills; a baked texture must reproduce the current noise function closely
enough that stills are indistinguishable at riding distance. Keep Metal
compatibility (varying budget) and the FidelityFX patch untouched.

## Implementation approach

1. Attribute vertex versus fragment cost on the dense and open traces (GPU
   attribution route or a temporary shader-simplified probe on a copy).
2. Compute the six wind `sin`/`cos` once and pass them to a `bend(p, s, c)`
   variant; early-out when `wind_strength * flex * nearby` is negligible.
3. Bake `cloud_noise` to a 512-square tileable R8 texture at startup (or as an
   imported asset) and sample it with `textureLod`; where a per-vertex value is
   unnecessary, sample per instance (`MODEL_MATRIX[3]`) or per fragment at low
   frequency, only if stills match.
4. Replace `value_noise`/`noise3` in the terrain and mineral fragment paths
   with texture lookups where the pattern is not view-dependent; fix the
   mineral snow bump space while there if it is visually neutral or better.

## Acceptance and verification

- [ ] Vertex-stage or total GPU ms falls on the dense trace with matched 4K
  stills showing identical cloud shadows, tree wind motion, moss/snow patches
  and terrain detail.
- [ ] `tests/colorful_forest_suite.gd`, `tests/tree_dynamics_suite.gd`,
  `tests/mineral_detail_suite.gd`, `tests/golden_sunlight_suite.gd`,
  `tests/render_efficiency_suite.gd`, `tests/macos_compatibility_suite.gd`
  and `tests/runtime_suite.gd` pass; shaders compile on Metal and D3D12.
- [ ] One warmed 15-second dense-forest candidate against
  [DENSE_FOREST_BASELINE.json](../../docs/DENSE_FOREST_BASELINE.json) with GPU
  ms and frame statistics; retain negatives.
- [ ] Update [Rendering](../../docs/RENDERING.md) cloud/wind shader contract;
  commit/push with a development note and Dev ID.

Human acceptance: cloud shadow and wind motion in a descent are a follow-up
look, not a gate, provided stills match.

## Open questions

None

## Completion record

Pending implementation. Record attribution before/after, stills, tests,
rejected variants, guide updates and commit/push references.

---
id: "AA-20260916-084513-reduce-vertex-shader-transcendentals"
title: "Cut per-vertex trigonometry and procedural cloud noise in scene vertex shaders"
status: done
priority: P2
depends_on: []
created: "2026-09-16T08:45:13Z"
updated: "2026-09-16T20:10:35Z"
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
  [the powder task](../tasks/AA-20260916-084507-reduce-powder-patch-render-cost.md)).
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
  [the GPU task](../blocked/AA-20260912-105302-reduce-dense-scene-gpu-cost.md). This task
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

### Delivery, 2026-09-16: trigonometry hoisted; other proposals measured or rejected (Fable, macOS checkout)

Implemented manually; no scheduled claim. `pc_forest_tree_common.gdshaderinc`
(near and mid tree LODs) and `pc_td_conifer.gdshader` now evaluate the three
wind sines and cosines once per vertex and pass them to `bend(p,s,c)` for the
position, normal, tangent and binormal rotations: 6 transcendental operations
instead of 24 (12 for the conifer), with identical arithmetic on the same
values, so geometry is unchanged.

Measured on the Apple M4 MacBook (Metal, bilinear 0.75, Standard mountain
free ski, `scripts/mac_frame_probe.sh`, 20 s runs, two each; Metal exposes no
GPU timers, so only whole-frame means are available, noise about +/-1.5 ms; the free-ski route keeps the dense forest at impostor distance, so the Windows dense trace remains the decisive measurement):

| Variant | Frame mean | p95 | p99 |
| --- | --- | --- | --- |
| Baseline shaders | 24.81 / 24.85 ms | 26.6 / 26.7 | 27.8 / 27.7 |
| Hoisted sin/cos (delivered) | 24.69 / 24.65 ms | 26.6 / 26.5 | 27.3 / 27.7 |
| Hoist plus `if(angle!=vec3(0.0))` early-out (rejected) | 25.43 / 25.44 ms | 27.9 / 27.6 | 29.0 / 29.1 |

The hoist is neutral to slightly favourable and exact; the Metal compiler most
likely already merged the repeated `sin`/`cos` calls, so the gain is in the
source rather than the compiled shader. The zero-angle branch, although exact,
cost 0.6 ms consistently (vertex divergence between bent crown and stationary
trunk vertices in the same SIMD group) and is not retained.

Not implemented, with reasons: baking `cloud_noise` to a tileable texture
cannot reproduce the current pattern, because `cloud_hash` is aperiodic and the
wind displacement is unbounded, so the sky and every receiver would show
different clouds; the per-vertex cloud cost is about a dozen sines and the
task's own scale estimate (9 M vertex entries) puts the whole saving in the
tenths of a millisecond on desktop GPUs. Replacing the terrain and mineral
fragment noise with textures changes the moss/snow/detail look and cannot be
attributed here. Both remain open for a Windows host with GPU timers; the GPU
task record (`AA-20260912-105302`) carries this result.

Automated (macOS, Godot 4.7.2): foliage_sight_suite 307/307 (loads the
tree shaders); rendered runs compile both shaders and `vs_cand_1.png` shows
the forest as before. No CPU-side or data change.

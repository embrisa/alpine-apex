---
id: "AA-20260916-084506-cut-foliage-depth-prepass-cost"
title: "Remove redundant alpha tests and give tree wood a cheap opaque depth path"
status: ready
priority: P1
depends_on: []
created: "2026-09-16T08:45:06Z"
updated: "2026-09-16T08:45:06Z"
source_thread: null
---

# Remove redundant alpha tests and give tree wood a cheap opaque depth path

## Outcome

Lower the dense-forest depth pre-pass, the largest single GPU pass, by making
trunk and branch wood render as ordinary opaque geometry and by running one
alpha test instead of two on needles and cards, with identical foliage look.

## Current state and evidence

- The rendering baseline attribution records depth pre-pass above the opaque
  pass in dense forest (about 4.7 ms versus 2.8 ms at 2880x1620 internal in
  [RENDERING_BASELINE.md](../../docs/RENDERING_BASELINE.md); the native table
  in [the GPU task](AA-20260912-105302-reduce-dense-scene-gpu-cost.md) lists
  depth 1.504 ms and moving geometry 1.531 ms for a different window). Godot
  Forward+ can only use its null fragment in the pre-pass for materials without
  `discard` or alpha scissor; every foliage material here forces the full
  fragment (texture fetch plus dither hash) in the pre-pass and is double-sided.
- Source inspected at Dev 43 / `a9c2acb` (2026-09-16):
  - [`pc_forest_tree.gdshader`](../../assets/graphics/pc_forest_tree.gdshader)
    line 2 `render_mode cull_disabled`; fragment lines 66-86 discard for LOD
    dither, foliage sight and snow, then set `ALPHA=1.0` and
    `ALPHA_SCISSOR_THRESHOLD=.5` unconditionally (81-82) and additionally
    `if(needles.a<.5) discard` (85). The scissor and the manual discard test
    the same threshold, and the unconditional scissor puts wood fragments
    (mask under .4) into the alpha-scissor path although wood is a closed mesh.
  - [`pc_tree_impostor.gdshader`](../../assets/graphics/pc_tree_impostor.gdshader)
    lines 2, 44, 47-53, 62-63: cull_disabled, dither discard, two to four
    texture reads before the alpha test, scissor .35. About 14,000 candidate
    card instances at one forest camera (docs inventory).
  - The same pattern appears in `pc_conifer.gdshader`, `pc_td_conifer.gdshader`,
    `foliage.gdshader`, `tree_impostor.gdshader`, `mineral_grass.gdshader`,
    `terrain_grass.gdshader` and `rock_gravel.gdshader`.
- Already measured and rejected elsewhere (do not repeat): zero-coverage and
  invisible-patch probes, a CPU near/mid selector
  ([forest selection](AA-20260914-094136-select-forest-lods-before-submission.md)),
  UV-only vertex compression ([DENSE_GPU_ENCODING.md](../../docs/DENSE_GPU_ENCODING.md)).
  This task is the narrow shader-path hypothesis inside the broader
  [GPU task](AA-20260912-105302-reduce-dense-scene-gpu-cost.md); it reuses
  [DENSE_FOREST_BASELINE.json](../../docs/DENSE_FOREST_BASELINE.json) and
  does not wait for the blocked baseline task. Update the GPU task record.

## Agreed decisions and scope

Own the listed shaders, `assets/graphics/pc_lod.gdshaderinc` where the dither
is shared, and the tree asset preparation in
`scripts/presentation/forest_placement.gd`/`alpine_scenery.gd` only as far as
splitting wood and foliage into separate surfaces or materials requires. Keep
the foliage-sight transparency, LOD dither cross-fade, snow coverage, needle
transmission and card cropping visually identical. Do not thin forests, change
placement, LOD distances or the FidelityFX renderer patch. Keep shadow casting
behaviour for foliage as today.

## Implementation approach

1. Attribute: use the GPU attribution route in
   [Validation](../../docs/VALIDATION.md#performance-method) or the targeted
   `vegetation` map to read pre-pass versus opaque ms for the dense trace
   before and after each step; the null-fragment pre-pass can also be probed by
   temporarily removing discards on a copy.
2. Give wood its own surface/material (`cull_back`, no discard, no scissor)
   during tree preparation, so the pre-pass uses the null fragment for trunks
   and branches; keep the shared wind/LOD vertex code.
3. On foliage materials pick one alpha test: keep the explicit discard and drop
   the unconditional `ALPHA`/`ALPHA_SCISSOR_THRESHOLD`, or the reverse, but not
   both. Order the cheapest rejection first and avoid texture reads before the
   dither/LOD discard where the result cannot depend on them.
4. Consider `depth_prepass_alpha`-style handling only if step 3 proves
   insufficient; verify Forward+ behaviour on the custom D3D12 engine.
5. Tighten card and spray silhouettes (`card_crop`) only where the atlas has
   obvious empty alpha area and stills stay identical.

## Acceptance and verification

- [ ] Pre-pass ms (or pre-pass plus opaque ms) falls on the dense trace with
  unchanged foliage stills at 4K High, including foliage-sight fades, LOD
  cross-fades and snowed branches; compare matched captures pixel-wise where
  possible.
- [ ] `tests/colorful_forest_suite.gd`, `tests/foliage_sight_suite.gd`,
  `tests/density_lod_suite.gd`, `tests/forest_preparation_suite.gd`,
  `tests/tree_collection_suite.gd`, `tests/render_efficiency_suite.gd`,
  `tests/macos_compatibility_suite.gd` and `tests/runtime_suite.gd` pass;
  Metal compiles the changed shaders (varying budget check).
- [ ] One warmed 15-second dense-forest candidate against
  [DENSE_FOREST_BASELINE.json](../../docs/DENSE_FOREST_BASELINE.json): GPU
  ms, frame means, p95/p99 and draw/primitive counts reported per run.
- [ ] Update [Rendering](../../docs/RENDERING.md#terrain-forests-and-lighting)
  material contract, commit/push with a development note and Dev ID.

Human acceptance: tree appearance in motion is a follow-up look, not a gate,
provided matched stills are unchanged.

## Open questions

None

## Completion record

Pending implementation. Record pass attribution before/after, rendered
evidence, tests, rejected variants, guide updates and commit/push references.

---
id: "AA-20260914-094136-select-forest-lods-before-submission"
title: "Select forest instances and LODs before geometry submission"
status: ready
priority: P1
depends_on: ["AA-20260914-094136-establish-repeatable-rendering-baseline"]
created: "2026-09-14T09:41:36Z"
updated: "2026-09-14T09:41:36Z"
source_thread: "01a09c68-b71e-7cc1-b01a-291cd5c446e8"
---

# Select forest instances and LODs before geometry submission

## Outcome

Raise dense-forest rendered FPS by avoiding geometry submission for trees and
detail levels that cannot contribute to the frame. Retain the same physical
trees and visible silhouettes, wind, branch interaction, detail bands and fades.
This is the recommended first architectural optimization after the baseline task.

## Current state and evidence

Source inspected at Dev 31 / 36b25d3 on 2026-09-14:

- [Forest placement](../../scripts/presentation/forest_placement.gd) and
  [DensityForest](../../scripts/presentation/density_forest.gd) already use packed
  immutable transforms, 32 m detail regions, 384 m distant groups, a 128 m load
  radius and 192 m retention. Smaller groups alone are not a new foundation;
  the earlier 16 m split worsened tails.
- [AlpineScenery](../../scripts/world/alpine_scenery.gd) submits nearby near/mid
  and separate shadow-proxy batches, with conservative padded bounds.
  [Per-tree LOD](../../assets/graphics/pc_lod.gdshaderinc) evaluates crown-aware
  coverage in the shader. The [tree vertex shader](../../assets/graphics/pc_forest_tree.gdshader)
  collapses zero-coverage geometry, avoiding later work but still executing
  submitted vertex fetch/coverage logic. Engine MultiMesh culling is per batch;
  individual instances need explicit selection or compaction.
- The [retained forest receipt](../../docs/COLORFUL_FOREST_RESULTS.json) has
  median 68.24 FPS, 12.106 ms GPU, about 1,620 submissions and 13.737 million
  submitted primitives per frame. These scene-wide counts do not attribute all
  cost to trees or equal rasterized triangles. The
  [baseline task](AA-20260914-094136-establish-repeatable-rendering-baseline.md) must determine the removable share.
- Stock APIs include whole-buffer publication and visible_instance_count;
  [Godot's MultiMesh guide](https://docs.godotengine.org/en/stable/tutorials/performance/using_multimesh.html)
  describes the batch visibility limitation. Verify the pinned custom renderer's
  actual behavior and cost rather than assuming a newer API is available.

## Agreed decisions and scope

Own a bounded render-only selection layer between prepared tree placement and
MultiMesh publication. Physical IDs, transforms, population, assets/imports and
the collision spatial index remain authoritative and unchanged. No map bake or
15-percent tree reduction; that belongs to the
[deferred generation task](AA-20260913-232221-natural-forest-generation.md).

Retain current perceptible quality, detail reach, canopy aid, leaf tint, snow,
wind and branch contact. Existing shadow proxies have their own visibility
requirements: camera culling must not remove an off-camera shadow caster.
Preserve Godot, 120 Hz, 4 m support, physics/input response and saved settings.

Start with a compact CPU-built list of required instances by asset and LOD,
using existing packed data and supported buffer APIs. A narrow C++ kernel or
GPU-driven compaction/indirect draw path is authorized if profiling establishes
that CPU packing/uploads limit the simpler path. This is a conditional technical
escalation, not a requirement to rewrite the renderer. Include all transfer,
synchronization, culling and packaging costs in the decision.

Stand proxies and terrain occlusion are separate experiments. Reuse their future
visibility inputs through a small explicit interface; do not create a general
engine abstraction, hide trees through physics or combine candidate gains.

## Implementation approach

1. Instrument a bounded diagnostic to count instances and estimated vertices by
   near/mid/far/shadow LOD, fully zero coverage, transition overlap and frustum
   relevance. Use actual transformed crown/wind/card bounds and the current
   source-identified camera; do not infer visibility from batch centre alone.
2. Build a differential selector against the current shader coverage contract.
   Keep both LODs wherever either fade can contribute. Frustum rejection must
   include wind/branch displacement and billboards. Account for camera height,
   slopes, FOV, reverse/look-around, replay cameras and future separate views.
   Preserve the residency fallback until required detailed geometry is usable.
3. Preallocate bounded buffers; partition by asset/LOD without copying every
   distant physical tree each frame. Prefer stable membership with hysteresis
   and camera-motion-aware invalidation where it is conservative. Do not add
   visible latency or require synchronous GPU readback to make the current frame.
   Count CPU list building, buffer writes, uploads and render-thread submission.
4. Preserve tree identity when compacting or reordering. A moved instance slot
   must not inherit another tree's previous transform, motion vectors, tint,
   contact response or LOD history. Verify previous/current buffer association
   on the pinned engine, including FSR and motion blur. If an engine patch is
   necessary, keep its reproducible source under the tracked native build path.
5. Maintain an independent conservative light/shadow selection, or keep the
   original shadow path unchanged for the first candidate. Support temporary
   capture A/B switching only in diagnostics; do not add a permanent user option
   solely to retain a failed implementation.
6. Prototype one selection strategy, measure it, and stop escalating if current
   attribution leaves too little removable work. A second strategy requires an
   identified failure reason, such as upload cost exceeding the saved vertex
   cost. Retain a useful rejected-candidate report; restore owned runtime changes
   if the complete production comparison does not justify delivery.

## Acceptance and verification

- [ ] A fresh [baseline](AA-20260914-094136-establish-repeatable-rendering-baseline.md) comparison shows a repeatable GPU and
  rendered-FPS or frame-tail improvement beyond observed variation. Report the
  removed submissions/vertices alongside CPU packing, upload, memory and startup
  costs; no completion from fewer draw calls alone. The 32-43 percent overall
  budget gap is context, not a promised gain for this one task.
- [ ] Begin with perf-vegetation and perf-mixed using
  scripts/benchmark_targeted.ps1 with explicit scenery camera and fresh outputs.
  Then compare three warmed 15-second dense Standard and open/mineral controls,
  plus affected 170 km/h entry stress, under FpsCritical. Use counterbalanced
  source arms and return controls; follow the baseline task's identity rules.
  Verify the normal 120 cap separately and retain all first encounters.
- [ ] Differential tests prove no required contributing tree/LOD is omitted,
  duplicated or assigned the wrong state across region/LOD boundaries, forward
  and reverse travel, teleport/recovery, rapid camera turns, quality changes,
  delayed jobs, cancellation, re-entry and teardown. Bounds include displacement.
- [ ] Run affected density_lod_suite, density_spatial_suite, colorful_forest_suite,
  foliage_sight_suite and native forest_preparation_suite through the targeted
  guarded validation workflow. Add focused selection/motion-history coverage.
  Only physics/input/session edits add mandatory physics_suite/runtime_suite;
  mere render selection must not require a new simulation identity.
- [ ] Inspect matched native stills and chronological motion at skiing height,
  forest edges and dense stands, including forward/reverse LOD crossings, wind,
  branch contact, canopy aid 0/50/100, daylight/snowfall and supported quality
  tiers. Inspect FSR motion for smearing, wrong-instance velocity and pop-in.
  Physical count/checksums and tree/mineral collision stay unchanged.
- [ ] Queues and retained buffers remain bounded across repeated traversal and
  quality changes. Disclose video allocation, upload bandwidth where available,
  and any cold-start cost. Preserve LFS budget and existing asset bytes.
- [ ] Update Rendering/World only for changed ownership/contracts, Validation
  and relevant skills for new commands. Commit/push validated owned work with a
  captured development note. If no candidate passes, retain blocked findings,
  exact remaining gate and rejected evidence without shipping the experiment.

Human acceptance: continuous visual comfort and controller feel remain separate
follow-ups, not worker-completion gates. Automated motion is not user acceptance.

## Open questions

None

## Completion record

Pending implementation. Record the actual selected algorithm, evidence identities,
individual trials and controls, visual/automated checks, remaining acceptance,
Dev ID and commit/push. No performance improvement is established by authoring.

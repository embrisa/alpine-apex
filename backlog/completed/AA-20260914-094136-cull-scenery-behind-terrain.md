---
id: "AA-20260914-094136-cull-scenery-behind-terrain"
title: "Cull scenery conservatively behind terrain and solid rocks"
status: done
priority: P2
depends_on: []
created: "2026-09-14T09:41:36Z"
updated: "2026-09-17T08:22:00Z"
source_thread: "01a09c68-b71e-7cc1-b01a-291cd5c446e8"
---

# Cull scenery conservatively behind terrain and solid rocks

## Current disposition — 17 September 2026

Completed as a measured rejection under implementation step6. Both the ordinary
dense route and the final user-requested170km/h off/on comparison show no useful
mean frame/GPU gain. Keep production occlusion disabled. Current-bound stills and
sampled high-speed chronology passed their bounded visual checks. Current
economical policy supersedes repeated-control wording below; broad shipping
acceptance remains unclaimed for this rejected prototype.

## Outcome

Improve rendered FPS by rejecting scenery that is fully hidden behind solid
terrain ridges or large rocks before expensive rendering work. Keep every tree,
mineral, gap and skyline feature that can contribute to the actual view, with
stable results during fast travel, camera turns and recovery.

## Current state and evidence

Dev 31 / 36b25d3 source inspection found spatial/frustum/range culling and shader
LOD selection, but no production OccluderInstance3D setup or enabled explicit
viewport occlusion-culling path in scripts/project settings. Ordinary depth
testing already rejects hidden pixels; it does not establish that hidden mesh
submission/vertex work has been avoided. Verify the current custom renderer
before choosing an implementation; no hidden-work saving has been measured yet.

[Terrain preparation](../../scripts/world/terrain_preparation.gd) builds 64-cell
(256 m) chunks from the shared 4 m surface, including trimmed footprint chunks.
[AlpineWorld](../../scripts/world/alpine_world.gd) owns render meshes/materials;
[AlpineScenery](../../scripts/world/alpine_scenery.gd) and
[MineralScenery](../../scripts/presentation/mineral_scenery.gd) own conservative
batch bounds. Occluding only part of a large MultiMesh must not hide its visible
members. [Tree selection](../abandoned/AA-20260914-094136-select-forest-lods-before-submission.md) can later provide finer instance lists.

The [forest](../../docs/COLORFUL_FOREST_RESULTS.json) and
[gravel](../../docs/ROCK_GRAVEL_RESULTS.json) samples miss or do not conclusively
close the global frame budget; their counts do not prove an occlusion bottleneck.
Open ridge views may have little hidden work. Godot's
[occlusion guide](https://docs.godotengine.org/en/stable/tutorials/3d/occlusion_culling.html)
also describes CPU overhead and the need for suitable occluder geometry.

## Agreed decisions and scope

Own conservative visibility information and render-only rejection for existing
terrain/forest/mineral scenery. No physical regeneration, collision changes,
lower density/detail reach, clipping through visible silhouettes or new mountain
shadow feature. Keep 4K High/Auto 0.75, effects, Godot, 120 Hz and 4 m authority.

Use actual opaque rendered terrain/rock coverage as the occlusion authority.
Physics convex hulls can enclose visible cavities and overhangs; they are not
automatically valid occluders. Cutout leaves, grass and snowflakes are not solid
walls. Cloud/fog visibility is not proof of hard occlusion. Preserve off-camera
casters and any other view's contributions through an independent light/view path.

Start with existing Godot occlusion using a bounded conservative terrain/rock
proxy if attribution supports it. A native horizon/hierarchical depth test or
GPU-driven conservative culling path is authorized as the next prototype only
when engine culling granularity/overhead prevents the required gain. Avoid
synchronous depth readbacks and new broad renderer abstractions.

## Implementation approach

1. Qualify one ridge-hidden forest/mineral route and one exposed/open control.
   Record the potentially hidden batch/instance/vertex share versus actual pass
   cost with [baseline](../abandoned/AA-20260914-094136-establish-repeatable-rendering-baseline.md) tooling. Do not cherry-pick a fully hidden
   static scene as proof of ordinary skiing gain.
2. Derive conservative occluder geometry from current opaque meshes/support.
   Preserve footprint holes, terrain edges and sky gaps; coarse interpolation
   must not bridge a valley or protrude above the real silhouette. Detail/snow
   displacement and local powder replacement have separate visible ownership.
   When coverage is uncertain, keep the object visible. Resource generation is
   derived scenery work with explicit invalidation, not a physical map change.
3. Compare stock batch occlusion with finer selection only as needed. Measure
   culling CPU, candidate list construction, uploads, depth/proxy passes and
   memory together with the work avoided. Do not split every batch into many
   tiny nodes without measuring the submission tradeoff already seen in forests.
4. Keep temporal tests conservative: pad motion bounds, invalidate on camera
   teleport/rapid turn/FOV changes and reveal uncertain objects immediately.
   Previous-frame depth alone cannot hide newly revealed scenery safely. Define
   behavior for replay/free cameras, multiple views, screenshots, resize,
   minimized/resume, quality changes, interrupted preparation and teardown.
5. Keep visibility decisions outside solver/collision ownership. Shadow culling
   uses the light's required coverage, not the camera's hidden list. Maintain
   canopy aid, wind and branch-displacement bounds. Distinguish scenery culling
   from the separately requested ridge-shadow lighting feature.
6. Keep only a repeatable net frame benefit. If the tested routes expose too
   little occluded work or culling is slower, restore owned runtime changes and
   record the limiting geometry/granularity/CPU evidence for a later approach.

## Acceptance and verification

- [ ] A fresh repeatable baseline and three matched, independently warmed
  15-second comparisons show a net rendered-FPS or frame-tail improvement in
  the qualified hidden-scenery route, without reproducible exposed/open/near-tree
  regressions. Report native pass cost, culling CPU, submissions, actual covered
  route, memory/startup and all per-run values, with return-to-original controls.
- [ ] Local perf-mixed/perf-rocks/perf-vegetation checks use explicit maps;
  ridge behavior uses a targeted occlusion fixture or an explicitly guarded
  existing Standard route. FullMountain requires a reason; no implicit bake.
  Timing is FpsCritical, preparation Exclusive, other isolated checks Shared.
  Verify 4K actual provider/pixels, focus, source/cache/endpoint identity and
  a separate normal 120-cap run. Stress remains distinct from ordinary handling.
- [ ] Differential visibility tests against the unculled reference show no
  false-hidden objects for visible corners, skyline/gap views, ridge crests,
  partial batches, wind bounds, slopes, reversal, camera changes and teleport.
  Test cold/late data, cancellation, resize/resume and bounded repeated traversal.
- [ ] Separate native matched frames and chronological forward/look-back motion
  inspect near objects emerging around ridges and rocks, distant stands and
  shadows, snowy material transitions and rapid 170 km/h travel. Retain native
  and Auto reconstruction review; no disappearing geometry or reveal pops.
- [ ] Run affected density_lod_suite, density_spatial_suite, colorful_forest_suite,
  foliage_sight_suite, native forest_preparation_suite and performance_map_suite,
  plus focused conservative-occlusion tests. Physics/input/session edits trigger
  physics_suite/runtime_suite; physical placement/collision checksums remain exact.
- [ ] Derived data is versioned by actual source inputs and invalidated safely.
  Update Rendering/World ownership and Validation/skills if producers change.
  Commit/push measured validated owned work with a captured development note;
  retain rejected evidence and remove disposable task-only artifacts after push.

Human acceptance: continuous visual comfort and full-route skiing remain separate
follow-ups, not worker-completion gates. Native agent review is still required.

## Open questions

None

## Completion record

- Dev91 note `41eb45c5a3a94b979a92780e872d44fe`, completed rejected investigation.
- Current production at Dev90/a5db46e8; no runtime or settings changes.
- Seven current-bound native 4K pairs passed visible forest/ridge/shadow review.
  Candidate: 108.27254 FPS, 9.235952 ms/frame, 7.459669 ms GPU, frame p95/p99
  12.581/15.113 ms. Saved average: 108.9339 FPS; recent sample: 110.52445 FPS.
- One warmup plus one clean 15 s route, 1800 exact ticks/301 poses, zero focus
  loss or failures. Render CPU 1.960876 ms versus recent 1.775267 ms; no isolated
  culling CPU or universal regression claim. Recent source includes a small
  terrain-LOD difference; reference reuse supports rejection, not causal timing.
- Setup: 6.849 s, 1.124 MB packed proxy, native acceleration allocation excluded.
- Full details/commands/limits: `artifacts/occlusion_current_20260917/REVIEW.md`
  and [Performance handoff](../../docs/PERFORMANCE_HANDOFF.md#current-bound-terrain-occlusion--17-september-2026).
- Final user-requested170km/h pair: off110.15464 FPS/9.078147ms frame/6.662408msGPU;
  on109.30824 FPS/9.148441ms/6.666964ms. Draws-5.174%,primitives-5.139%,renderCPU
  +0.225077ms. Framep99 improves in one sample,p95 and slowest-one-percent worsen.
  No meaningful performance gain; do not integrate. Same process/source/settings,
  one warmup then off/on15s, exact1800ticks/301poses over707.840m,focus0,failures[].
- Ten matched4K chronological visual pairs reviewed before that timing; no obvious
  false-hidden geometry. Look-back mainly faces uphill snow, so canopy evidence
  is limited. This is benchmark-only speed control with nonblocking collisions,
  not normal handling or complete continuous-motion acceptance.
- Broad shipping, exposed performance and lifecycle checks
  were not run after the failed gain gate. No visual-quality or FPS downgrade
  ships. No gameplay compatibility or maintained-producer contract changes.

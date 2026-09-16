---
id: "AA-20260916-084509-reduce-grass-gravel-texture-streaming-hitches"
title: "Move grass and gravel cell construction and mineral texture loads off the frame"
status: ready
priority: P2
depends_on: []
created: "2026-09-16T08:45:09Z"
updated: "2026-09-16T08:45:09Z"
source_thread: null
---

# Move grass and gravel cell construction and mineral texture loads off the frame

## Outcome

Remove the remaining streaming frame spikes not owned by the forest and
collision burst task: grass and gravel cells built with per-instance server
calls on the main thread, and synchronous macro texture loads for cliffs.
Steady FPS is unchanged; p99 and maximum frame times improve.

## Current state and evidence

- `stream_grass` scope in [the rendering baseline](../../docs/RENDERING_BASELINE_RESULTS.json):
  mean 87-91 µs but p99 2,098-2,327 µs and maxima 3,210-3,490 µs per frame;
  first-encounter grass streaming events of about 13.9 ms are recorded in
  [RENDERING_BASELINE.md](../../docs/RENDERING_BASELINE.md).
- Source inspected at Dev 43 / `a9c2acb` (2026-09-16):
  - [`terrain_grass.gd:117-146`](../../scripts/presentation/terrain_grass.gd)
    `_create_cell` builds MultiMeshes with `set_instance_transform`,
    `set_instance_custom_data` and `pose * mesh.get_aabb()` per instance for up
    to 160 clusters times two LODs per cell, up to three cells per frame, on
    the main thread; `terrain_grass.gd:83-96` sorts up to 625 keys with a
    lambda and frees whole batches synchronously on cell change.
    [`rock_gravel.gd:72-122`](../../scripts/presentation/rock_gravel.gd) uses
    the same pattern plus 324 `set_pixel` calls and a texture update per cell.
    The forest path already packs `MultiMesh.buffer` on the worker
    (`prepare_tree_batch`), and `mineral_scenery.gd:186` assigns buffers.
  - [`mineral_scenery.gd:145-173`](../../scripts/presentation/mineral_scenery.gd)
    `_process` swaps macro cliff textures up to twice per frame via
    `_set_textures` (lines 90-98), which calls `load()` synchronously for
    albedo, normal and roughness; high-tier sources under
    `assets/graphics/geology_v11/textures` are multi-megabyte. First loads
    hitch; repeated loads hit the resource cache.
- Forest region publication, terrain trimesh cooking and tree/mineral
  collision refresh are owned by
  [the forest publication and collision task](AA-20260913-141128-reduce-forest-publication-and-collision-bursts.md);
  mineral convex warming was delivered by
  [the archived streaming task](../archive/AA-20260912-105300-reduce-streaming-frame-spikes.md).
  Grass performance policy is in
  [Validation](../../docs/VALIDATION.md#terrain-grass-performance) and the
  grass contract in [Rendering](../../docs/RENDERING.md#terrain-grass).

## Agreed decisions and scope

Own `scripts/presentation/terrain_grass.gd`, `rock_gravel.gd`,
`grass_placement.gd`/`gravel_placement.gd` as far as packing moves there, and
the texture loading in `mineral_scenery.gd`. Keep populations, placement,
LOD distances, custom data semantics, sway bounds and the streaming radius
identical; keep the `-Grass off|on` and `-Gravel` comparison contracts working.
Do not change forest or collision streaming.

## Implementation approach

1. Pack the 16-float transform plus custom data instance buffer and the
   merged AABB inside the existing worker task (`CellWork.run`), then assign
   `mm.buffer`, `custom_aabb` and `instance_count` once on the main thread.
   Bound cells per frame by a microsecond budget rather than a fixed three.
2. Build the gravel coverage image on the worker and update the texture once.
3. Retire cells by freeing nodes incrementally or pooling
   `MultiMeshInstance3D`s; avoid the per-change lambda sort by maintaining
   the pending list incrementally.
4. Replace synchronous macro texture `load()` with
   `ResourceLoader.load_threaded_request` and swap when
   `load_threaded_get_status` reports ready; keep the two-swaps-per-frame cap
   for the swap itself.

## Acceptance and verification

- [ ] `stream_grass` (and a new `stream_gravel`/`stream_mineral_textures`
  reading) p99 and maxima fall on the forest and rock traces with identical
  populations and effective settings; report per-run maxima.
- [ ] `tests/terrain_grass_suite.gd`, `tests/rock_gravel_suite.gd`,
  `tests/mineral_detail_suite.gd`, `tests/mineral_asset_suite.gd`,
  `tests/scenery_loading_suite.gd`, `tests/render_efficiency_suite.gd` and
  `tests/runtime_suite.gd` pass; the grass comparison harness still validates
  zero/on populations.
- [ ] Rendered inspection of grass and gravel at cell boundaries while
  streaming and of cliff macro detail switching at 280/420 m.
- [ ] One warmed candidate per affected route reporting frame p95/p99 and
  maxima versus the saved baselines; steady means within variation.
- [ ] Update [Rendering](../../docs/RENDERING.md#terrain-grass) and
  [#cosmetic-rock-gravel](../../docs/RENDERING.md#cosmetic-rock-gravel) where
  construction ownership changes; commit/push with a development note and
  Dev ID.

Human acceptance: none beyond rendered inspection.

## Open questions

None

## Completion record

Partially implemented on 2026-09-16: grass worker buffer/bounds preparation,
with the existing three-cell publication budget retained. The paired native
publication test measured 376.31 -> 77.85 us/cell (-79.3% main-thread cost);
packing itself moves to workers. Exact packed-data/bounds, density/cancellation,
asynchronous population and matched rendered checks passed. One clean timed
route was 93.13 FPS / 10.738 ms against the saved 92.64 / 10.798 average;
no meaningful FPS gain claimed. See the grass section of
[Performance handoff](../../docs/PERFORMANCE_HANDOFF.md#grass-worker-packing-16-september)
for scope statistics, cache limitation and compact evidence paths.

Remaining: gravel/image preparation, texture loading, cell retirement/sorting,
publication budgeting and their separate affected-route verification. Keep the
task ready for this remaining work; this milestone does not satisfy every
acceptance item above. Development note: `158a50a0f00841739760caa5cada6929`.

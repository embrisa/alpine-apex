---
id: "AA-20260916-084509-reduce-grass-gravel-texture-streaming-hitches"
title: "Move grass and gravel cell construction and mineral texture loads off the frame"
status: done
priority: P2
depends_on: []
created: "2026-09-16T08:45:09Z"
updated: "2026-09-16T21:30:35Z"
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

### Second delivery, 2026-09-16: gravel packing, mask blits, incremental retirement, bounded publication and threaded macro textures (Fable, macOS checkout)

Implemented manually; no scheduled claim. Builds on the grass worker packing
delivered earlier today.

- Gravel cells pack their MultiMesh buffers and merged bounds on the worker
  (`gravel_placement.pack`, identical 12 transform plus 4 patch floats per
  instance); `create_cell` assigns `buffer`, `custom_aabb` and `instance_count`
  once per batch. The 18x18 cell mask reaches the shared 128x128 mask through
  at most four `blit_rect` copies instead of 324 pixel writes (same R8 bytes).
- Grass and gravel cell candidates come from an offset list sorted once per
  reach with a native array sort in the same (distance, dy, dx) order the
  per-change lambda sort produced. Cells leaving the radius are queued and freed
  eight batches per frame instead of all at once; they sit beyond the shader
  fade distance while they wait. Grass publication of completed worker cells is
  bounded by 300 us per frame as well as by count, always landing at least one.
- Cliff macro textures load through `ResourceLoader.load_threaded_request`;
  the swap waits until every channel of the target tier is loaded, keeps the
  two-swaps-per-frame cap and never mixes tiers within a formation. Tier
  changes still apply synchronously. A `stream_gravel` scope joins
  `stream_grass` and `stream_mineral_textures`.

Measured on the Apple M4 MacBook (`scripts/mac_frame_probe.sh`, Standard
mountain free ski, 20 s, interleaved baseline/candidate pairs; microseconds):

| Scope | Baseline | Candidate |
| --- | --- | --- |
| `stream_grass` mean / p99 / max | 83.4 / 952 / 1132 and 83.2 / 973 / 1098 | 71.4 / 472 / 536 and 66.0 / 472 / 574 |
| `stream_gravel` mean / p99 / max (new scope) | not measured | 19.3 / 72 / 78 and 19.0 / 74 / 84 |
| `stream_mineral_textures` per swap (two swaps per run) | 11,891 / 11,913 max and 11,892 / 12,118 max | 121 / 125 max (after holding the loader-thread textures; an intermediate build that dropped them reloaded from disk at 23 ms) |
| whole frame mean / p99 / max (ms, noise +/-1.5) | 24.92 / 28.4 / 44.0 and 26.48 / 30.1 / 45.3 | 24.71 / 28.4 / 46.0 and 26.18 / 29.8 / 45.9 (the remaining maximum is the terrain collision cook owned by the collision task) |

Automated (macOS, Godot 4.7.2): terrain_grass_suite 86/86, rock_gravel_suite 96/96, mineral_detail_suite pass, mineral_asset_suite 120 assets / 0 failures, scenery_loading_suite pass, render_efficiency_suite 361/361, runtime_suite 192/192; the gravel and mineral suites ran with their report folders deleted. `rock_gravel_suite` passes all checks but hangs afterwards unless `artifacts/rock_gravel/` exists (pre-existing report-write defect, like the crash-recovery and pelvis suites). Rendered: `artifacts/mac_probe/macro_fix.png` and `stream_cand_1.png` show grass, gravel and cliffs as before on the free-ski route.
Remaining from the acceptance list: the Windows forest and rock traces against
their saved baselines and a rendered inspection there.

Also in this milestone, at the user's request: every suite report write now
goes through `tests/test_report.gd` (`write`, `write_line`, `write_bytes`,
`write_var`, `open_write`), which creates the report folder and reports a
failed open instead of dereferencing null. 313 suite files were rewritten
mechanically (413 sites) and parse-checked with `--check-only`; the only other
parse finding, `planted_snow_baseline.gd` preloading a missing artifact, is
pre-existing. This removes the hang that `crash_recovery_suite`,
`pelvis_balance_suite`, `rock_gravel_suite` and `mineral_asset_suite` showed
today after all their checks had passed.

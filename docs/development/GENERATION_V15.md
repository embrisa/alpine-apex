# V15 generation and configurable richness

V15 retains the Godot pipeline, six faces, 6,144 m square mountain, authoritative
4 m surface and independent 120 Hz solver. Model 27/replay v5 are unchanged.

## Recipes

`MountainDefinition.generate(seed, 15, settings = {}, job = null)` accepts the
canonical dictionary from `generation_settings.gd`. Empty settings mean Standard.
Four richness factors use 0.5-5.0; tree spacing uses 0.5-2.0. Values have 0.01
precision in both recipes and controls. Presets set density factors to 0.5/1/2/5 and
leave spacing at 1. Standard requests 200,000 trees and 16,022 minerals; Extreme
requests 1,000,000 and 80,110. Placement reports requested and achieved counts.
Natural populations may saturate; the requested one million is a capacity target,
not a requirement to fill protected terrain. The user accepts roughly 600,000
when space limits placement. Tree population 5 with spacing 0.5 and all other
factors at Standard achieved 730,854 trees in the default seed, preserving
non-overlap, protected areas and all six runouts. The one-million synthetic test
measures data/rendering capacity separately from natural placement feasibility.
Snow density changes counts, not heights. Landform complexity adds bounded shelves,
crags and ribs while retaining drainage bowls, summit access and runouts.

Schema-2 mountain files and schema-4 race references include all five settings.
Cache and record identities include them. Seed-only entry uses Standard. Old
saved versions fail validation without migration. V14/v13 APIs are explicit
comparison fixtures. Graphics quality does not change physical settings.

## Jobs and packed data

`packed_trees.gd` owns packed positions, dimensions, yaw, candidate IDs, ecology
flags and a linked spatial index. Production v15 leaves the dictionary obstacle
population empty. Collision, snow, previews, forest preparation and tree motion
use indexed access. Returned hit/record dictionaries are bounded queries.

`generation_job.gd` owns up to six threads, fixed result slots and a mutex-protected
queue/snapshot. Workers read immutable surface stages and return disjoint packed
results. Random streams derive from seed, stage and stable candidate ID. Placement
conflicts resolve in candidate order; deterministic thinning preserves distribution.
All workers join on cancellation. Faces hold weak owner references.

Indexed landform queries and an 8 m ecology filter avoid repeated full feature
scans. Exact support/material and protection checks still decide candidates.
Normals are rebuilt after support changes and reused within each immutable stage.
Tree-snow tiles read the same inputs, accumulate maximum overlap, then commit after
all reads finish. Added snow cannot expose rock. Final seating precedes construction
of mineral collision structures. No new native extension or runtime was added.

Named timings/work counters cover terrain, foundations/placement, candidates and
filtering, exposure, snow shaping/tree snow, seating, collision, normals, hashing
and physical-cache I/O. Counters identify vertices, candidates and placements.

## Scenery

`mountain_preparation.gd` prepares maps, chunk arrays, triangle/LOD templates,
snow readability, seated forest poses and mineral batch buffers on a worker.
Root metadata comes from assets on the main thread. Existing packed forest uploads
and bounded nearby detail residency consume prepared data and share poses with
tree motion. The unused dense-forest grouping pass is removed.

[Scenery v3](../world/OFFMAP_V3.md) trims unused square render corners beyond the existing
2,850 m return zone and connects the retained 4 m perimeter to one shared authored
background. It submits 478 terrain chunks / 3,610,880 base triangles; 84 partial
edge chunks keep exact triangles without coarse LODs. Physical arrays and v15
generation remain unchanged. Scenery identity 3 and scenery cache schema 2 reject
obsolete layouts, duplicate/missing chunks and invalid perimeter indices.

Scene Nodes, ArrayMesh/MultiMesh creation and GPU submission remain on the main
thread with yielding checkpoints. CPU preparation and scene construction have
separate measurements. Asset metadata and each upload stage also update the shared
job snapshot, including actual chunk/forest-region/mineral-batch counts. Submission timings include yielded/loading frames and are
not GPU execution time. Dense samples separately record render CPU, GPU and frame
p95/p99. Physical-cache loading alone is never complete time to ski.

## Caches and export

`user://mountain_cache_v15/<recipe SHA>.physical` stores final heights, snow,
exposure/contact material, normals, packed trees/index, face recipes, seated minerals
and collision entries/index. `.scenery` stores maps, terrain arrays/templates,
seated poses, regional tree buffers and mineral batches. Scenery validation also
includes physical fingerprints, preparation code/assets, engine and graphics level.

Archives contain bounded independently hashed sections (maximum 16 MiB), strict
lengths/types and an upper file bound. Validation hashes bytes before decoding;
it does not reserialize a whole payload. A unique temporary file is flushed before
atomic replacement. Failure/cancellation preserves the previous entry. Scenery
reconstruction decodes into a temporary object and publishes its members only
after structural checks succeed, preserving an existing caller result on failure. The 2 GiB
budget is configurable with `generation/cache_budget_mib` in ProjectSettings.
A recipe's physical/scenery files evict together by last use. Default and active
recipes are protected; an unusually small budget can remain exceeded by protected
entries, which the eviction result reports.

Development hashes actual dependencies and the running engine executable. The
engine digest is memoized only within its immutable running process; a shared
version label is insufficient for accepting a cache. `generation_export` builds use a manifest
carrying source/asset digests and target runtime identity. The export plugin
refreshes dependencies at export time and checks the selected runtime against its
prepared receipt. Optional bundled default caches receive the same validation.
No user preferences, saves or records are bundled.

## Estimates and cancellation

Creation and startup share the job snapshot: stage, completed/total work, elapsed
time, remaining range and cancellation state. Estimates separate physical work,
additional time to ski and broad peak memory. Completed local stages calibrate
costs using candidate counts, density and population. Explicit single-worker
experiments are excluded. Cache hints check the physical header's recipe,
source and engine identity; full integrity and scenery compatibility checks happen
in the loaders. Exported Standard estimates also recognize the bundled physical
and scenery files. Custom settings never inherit Standard bundle hints.
If an archive is rejected, the
loading snapshot switches back to the full fresh-generation estimate when recipe
work starts. Memory extrapolation scales population buffers additively while
retaining a fixed terrain/asset allowance.

Cancellation checks rows, tiles, candidates, sections and upload checkpoints.
The full physical mountain exists before skiing. Cancelled previews retain the
previous draft; startup releases partial scenes and offers Retry/Quit. A completed
physical cache can remain useful after later scenery cancellation.

## Measurements and acceptance

Fresh serial guarded v14 baselines replace the historical 207 s / 6.2 s figures.
The selected Godot 4.7.2 custom runtime was used for both versions. Three matched
Standard repetitions measured:

| Work | Fresh v14 mean | v15 mean | Saving |
| --- | ---: | ---: | ---: |
| Cold physical generation | 422.634 s | 135.579 s | 287.055 s / 67.92% |
| Complete physical-cache loading | 10.349 s | 5.402 s | 4.947 s / 47.80% |
| Cached rendered time to ski at 4K High | 144.683 s | 64.324 s | 80.359 s / 55.54% |

Cold generation excludes cache publication and scene construction. V14 cold
repetitions were 428.131, 429.905, 409.868 s; v15 138.127, 135.103, 133.506 s.
Complete physical-cache loading includes dependency validation: v14
10.455/10.851/9.742 s versus v15 4.774/6.652/4.781 s. V15 archive reconstruction
alone is a smaller internal stage and is not the comparison boundary.
All three v15 outputs and a 457.220 s single-worker build have identical height
and obstacle fingerprints; warm reconstructions match. Both Standard versions
contain 200,000 trees. V14 has 16,072 minerals, v15 16,022; the physical outputs
are intentionally versioned differently.

The final native fixture measured actual 3840x2160 output and 2880x1620 internal
rendering, High, Auto FSR 4.1.1 at 75%, a 120 FPS cap, frame generation off and
SDFGI off. V14 used its validated physical cache through the current shared
renderer: 163.678/138.112/132.258 s through the ready rendered frame. V15 took
78.143 s with a physical hit and preparation miss, then 57.938/71.299/63.735 s
with both caches. Preparation-cache reads averaged 5.402 s. Scene creation and
uploads are included in readiness; loading-frame yields are included in
submission stages. The v14 first run spent 32.6 s on rider/interface loading,
versus about 4.2 s later. All three v15 cached runs were faster than all three
v14 runs, but variation and memory pressure limit extrapolation.

The final camera fixture clamps its eye above local ground and samples dense
48 m patches on faces 0, 2 and 4, with a separate 90 m camera traversal. It asserts
actual output pixels at readiness and after each view. Earlier unclamped camera
samples and a decorated 3840x2126 window attempt remain in evidence but are
excluded from the final comparisons. Original preimplementation v14 captures
are retained for provenance. These scene samples disable the game process and
solver; they are not full-descent gameplay performance.

The Standard native guard recorded v14/v15 peak private committed memory of
6.902/5.833 GiB, resident working sets of 2.431/1.749 GiB and task-attributed
GPU allocations of 4.644/4.456 GiB. These are different measures: private commit
is not resident RAM, and Windows per-process GPU allocations can include shared
resources. Minimum free system RAM was 0.294/1.465 GiB with existing applications
left intact, so paging pressure is material. Exact guard samples are retained.

All 12 settings/seed world cases passed 253 checks, including all final tree and
mineral seats, non-overlap, bounded snow, terrain materials, custom recipe sharing,
exact warm reconstruction and six-face connectivity:

| Settings case | Achieved trees | Achieved minerals |
| --- | ---: | ---: |
| Standard, default seed | 200,000 | 16,022 |
| Light, seed 42 | 100,000 | 8,011 |
| Rich, seed 927461 | 202,092 | 32,044 |
| Tree population 5, spacing 1 | 334,357 | 16,022 |
| Tree population 5, spacing 0.5 | 730,854 | 16,022 |
| Mineral density 5 | 160,006 | 80,110 |
| Snow density 5 | 200,000 | 16,022 |
| Landform complexity 5 | 149,576 | 14,164 |
| Spacing 0.5, other factors Standard | 200,000 | 16,022 |
| Tree population 5, spacing 2 | 102,639 | 16,022 |
| Extreme, spacing 1 | 205,124 | 52,922 |
| Extreme, spacing 0.5 | 474,745 | 52,922 |

A tree factor of 5 requests one million; achieved counts respect placement
constraints. Full Extreme also reserves substantially more terrain for minerals
and landforms. Approximately 600,000 is an acceptable natural saturation outcome,
not a universal cap or minimum. Snow factor 5 produces 6,840 bounded features.
Extreme cold builds took 442.965 s at normal spacing and 446.222 s at half spacing.

The final physics/runtime, rock terrain, snow readability/response/coverage,
thick-snow control, scenery-loading and race suites passed. Settings/cache
contracts passed 80 checks; estimate calibration passed five. Transactional
scenery rejection passed four checks. Generation/cache/scenery cancellation
released worker-owned results, with the longest tested recipe cancellation
1.332 s. Native startup cancellation passed physical-cache read, terrain upload,
rider/interface and ready checkpoints in 29/362/801/701 ms respectively,
releasing partial scenes and retaining usable prior caches and retry state.

The final synthetic one-million-tree native fixture passed all 16 checks at
actual 3840x2160 output. It covers packed data/index, 804 successful collision
queries across the population, physical and scenery archive round trips,
invalid/corrupt scenery rejection, all-tree uploads, 81 nearby resident regions
and shared indexed poses. It built one million poses using a 48 MB packed
transform array; tree GPU submission took 16.825 s. This is an artificial regular
forest without natural placement restrictions. Native forest preparation
separately passed 2,097 checks.

Standard summit/dense forest and Extreme summit/face 2 captures were inspected:
continuous visible snow, seated trunks and open summits were present. Extreme
retains a broad clear summit bordered by more pronounced relief. Close foliage
is dense and coarse in these deliberate worst-density views; branches can obscure
the ground. Extreme at normal spacing reached the ready 4K frame in 118.173 s
with a physical hit and preparation miss. Half-spacing Extreme completed in
136.490 s with the same cache state. Its summit/face 4 images were inspected:
the summit remains open, while very close branches heavily obstruct the densest
forest view. This limits visual readability in that patch. Both rendered stress
runs passed.

The Windows validation export passed its dependency-manifest/engine audit,
163 current script checks, exclusion audit and six physical-bundle checks.
An empty-profile native launch reused both bundled caches, reached readiness in
69.512 s, reconstructed physical data in 2.610 s, and constructed the scene in
39.821 s. Readiness also includes rider/interface resources; archive timing
excludes the test's initial bundle preflight. This 1280x720 functional export
check is separate from the matched 4K measurements above. FSR 4.1.1/native wind
loaded, the skier moved 13.14 m, and no script/native errors were logged.
Standard/Custom controls and scrolling were inspected at 1280x720. The final
smoke test additionally verifies that Standard estimates recognize bundled
caches while Custom settings do not inherit them. No player preferences or
race records were written by the test.

The complete local package is `builds/AlpineApex-v15-validation/`, with a player
README, required native DLLs/licenses, both default caches and
`validation_manifest.json` containing versions, fingerprints, file sizes/hashes
and measured evidence. It has not been published or zipped. Export evidence is
in `artifacts/generation_v15_export_smoke_final/`.

For later forest work, these diagnostic scene timings are retained. Values are
means of each view's mean/p95/p99, not pooled whole-descent percentiles:

| Scene | Static mean / p95 / p99 (ms) | Camera traversal mean / p95 / p99 (ms) |
| --- | ---: | ---: |
| Standard | 15.31 / 16.60 / 17.14 | 15.41 / 18.37 / 24.39 |
| Extreme, spacing 1 | 20.08 / 21.96 / 23.05 | 20.42 / 23.29 / 25.43 |
| Extreme, spacing 0.5 | 41.19 / 43.59 / 44.70 | 40.77 / 46.20 / 48.94 |

Extreme/half-spacing Extreme peak private commit was 5.984/6.136 GiB,
resident working set 2.091/2.184 GiB and task GPU allocation 4.167/4.105 GiB.
The synthetic forest-only capacity fixture used 2.659 GiB private commit,
2.148 GiB resident memory and 1.236 GiB task GPU allocation; it omits the full
scene and cannot be used as a whole-game memory or performance estimate.

Forest FPS optimization and 90-120 FPS target compliance are deferred at the
user's request. Existing scene-frame measurements remain diagnostic evidence;
this version does not claim that target or subjective skiing acceptance.

Evidence: `artifacts/generation_v15/` and `artifacts/guarded/v15_*`.
Historical sources: `v14_source_receipt.json`. Artifacts are disposable. Reproduce
with these scripts through `scripts/run_snow_check.ps1`, respecting the validation
lock and running workloads serially:

- `tests/generation_baseline.gd`: three cold/warm v14 builds.
- `tests/generation_v15_baseline.gd`: three matched builds plus worker determinism.
- `tests/generation_v15_contract_suite.gd`: settings, identities, integrity, eviction.
- `tests/generation_v15_world_suite.gd -- --case=standard`: seating, spacing, snow,
  material/support and six-face connectivity. Cases also include `alternate_light`,
  `alternate_rich`, `extreme`, `extreme_tight`, `saturation`, `trees`, `trees_tight`, `minerals`,
  `snow`, `landforms`, and `spacing`.
- `tests/generation_v15_capacity_suite.gd`: synthetic one-million-tree data/index,
  collision and cache; run with `-Native` for forest upload/residency evidence.
- `tests/generation_v15_cancellation_suite.gd`: generation/cache/scenery cancellation.
- `tests/generation_render_profile.gd`: actual 4K High scene readiness, dense frame
  distributions, memory and screenshots. Use `--profile-version=15` and preset 1/3.

The world suite checks continuous downhill connections on all six faces with
1.8 m node / 1.5 m edge clearance, downhill gradients and the existing maximum
30 m exposed-rock run. It reports the older 500 m exit-spread benchmark separately
and requires it for Standard. High density can retain connectivity with narrower
route choice: the first final Extreme/tight build reached all six runouts, with
303-342 m exit spread on two faces. These are measured route-choice limitations,
not evidence of user skiing acceptance. `--physical-clearance` explicitly selects
0.6 m nodes / 0.5 m edges for a separate audit, beyond the solver's 0.35 m trunk
expansion; it never alters generation or the retained Standard benchmark.

Synthetic capacity deliberately ignores natural feasibility. Stored/collidable/
uploaded population, performance-target compliance, visual review and user skiing
acceptance remain distinct. Measured remaining opportunities include mineral and
forest submission, dependency fingerprint reads, and serial geology placement. Final seating already runs in bounded tiles.

Godot references: [thread safety](https://docs.godotengine.org/en/stable/tutorials/performance/thread_safe_apis.html)
and [export plugins](https://docs.godotengine.org/en/stable/classes/class_editorexportplugin.html).

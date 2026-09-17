# World generation and terrain

## Recipe and retained landforms

[MountainDefinition](../scripts/world/mountain_definition.gd) owns portable
recipes and field reconstruction. Routine mountain work uses
`MountainDefinition.generate(849205174)` or
`mountain_cache_v17.gd.generate(849205174)`; explicit older generators remain
test/comparison entrypoints, not the normal startup path.

[GenerationSettings](../scripts/world/generation_settings.gd) canonicalizes five
settings at 0.01 precision: tree population, mineral density, snow-feature density
and landform complexity range 0.5–5.0; tree spacing ranges 0.5–2.0. Empty settings
mean Standard. Light/Standard/Rich/Extreme set density factors to 0.5/1/2/5 and
spacing to 1. Source keys and canonicalization are authoritative. Physical
settings travel in mountain files, race references, cache keys and record
identities; graphics quality cannot change them. Snow density changes counts,
not feature heights.

The 6,144 m square mountain retains six faces, drainage bowls, geological ribs,
shelves, crags, summit access, drop approaches/landings and broad runouts. The
shared support grid is 4 m. Local complexity must retain route branching and
protected openings; no feature applies a racing-line force. Seeded ecology
varies slope/elevation/exposure and preserves mineral/tree non-overlap.

Generator 17 requests 85,000 / 170,000 / 340,000 / 850,000 trees for Light /
Standard / Rich / Extreme. Custom retains the same factor semantics. Mineral
targets remain 8,011 / 16,022 / 32,044 / 80,110. Report achieved counts separately:
spacing and protected terrain can saturate placement. Synthetic capacity tests
do not prove natural placement feasibility or skiable routes.

## Previous bounded default-v15 route evidence

These version-15 measurements do not certify generator 17. The new generation
change uses the bounded forest routes and two-seed evidence linked below.

The current source-hashed route scenario is produced by
the then-current `alpine_v15_route_audit.gd` (now maintained as [`alpine_v17_route_audit.gd`](../tests/alpine_v17_route_audit.gd)), using
`MountainDefinition.generate(849205174)` with Standard settings and the
source/engine-validated physical cache. It surveys all six faces, then performs
three matched **15-second**, 170 km/h, full-tuck/no-brake speed-controlled
probes on each face. The retained v13-named planner supplies test-only steering
over the current field; it never loads a historical bake or saved route. The
[historical bounded receipt](CURRENT_V15_BOUNDED_ROUTE_RESULTS.json) records its
model, generator, source/engine/terrain hashes and every probe.

The 2026-09-13 receipt captured model 35 on generator 15: all 18 probes ran
the exact 1,800-tick window, held 169.99997-170.00003 km/h, and travelled
707.61-707.82 m. Those facts describe the source-hashed automated scenario
only; the receipt, not this paragraph, carries the complete current identity.

This is automated bounded route evidence only: the speed controller is a
benchmark fixture, so it does not establish ordinary handling, full-route
skiability, rendered quality, frame performance, player/controller acceptance,
alternate-path coverage, or other seeds. Those acceptance types remain separate.

Reproduce the current bounded scenario under the validation guard, then publish
the receipt:

```powershell
./scripts/run_guarded.ps1 -FilePath ./godotw.ps1 -Arguments @('--headless','--script','tests/alpine_v15_route_audit.gd') -Label current-v15-bounded-route-audit -TimeoutSeconds 900 -FullMountain -FullMountainReason 'Current default-v15 route geometry and bounded speed-controlled probe evidence'
python tests/report_v15_route_audit.py
```

## Historical default-v15 route audit (model 28)

The following 2026-09-11 audit and its
[model-28 receipt](V15_ROUTE_AUDIT_RESULTS.json) are preserved for provenance.
Their recorded source identity has drifted and they are **not current route
acceptance**. At capture, the audit used the same default seed and Standard
settings with a then-current test-only planner/pilot; no historical bake or
saved route was loaded.

2026-09-11, model 28: all six surveys returned two paths, all twelve paths had
finite support and zero tree/mineral sweep hits (13,962 support samples and
11,126 swept segments). Five pilots completed; face 5's pilot stalled without
crashing after reaching a maximum radius of 2,053.42 m (72.05% of the base
radius). No second attempt was made. Labels below are one-based; indices match
the source and receipt.

| Face (index) | Survey | Graph rejoin nodes | Pilot outcome (simulation seconds) |
|---|---|---:|---|
| 1 (0) | Two swept-clear paths | 34,012 | Completed, 288.03 s |
| 2 (1) | Two swept-clear paths | 30,180 | Completed, 280.29 s |
| 3 (2) | Two swept-clear paths | 32,925 | Completed, 289.96 s |
| 4 (3) | Two swept-clear paths | 32,785 | Completed, 297.24 s |
| 5 (4) | Two swept-clear paths | 23,559 | Stalled at 72.05%, 227.78 s |
| 6 (5) | Two swept-clear paths | 35,632 | Completed, 323.48 s |

All surveys used the initial 6 × 12 m grid. Their two paths first crossed the
base boundary 1,847.58–2,266.91 m apart. The finer support check measured contact
normal Y as low as 0.539 between graph nodes: node constraints do not bound
every point along an edge. Collision clearance alone does not establish dynamic
skiability. Only path 0 was piloted on each face; alternate-path and deliberate
branch/rejoin skiing remain untested. Sampled pilot positions (one-second
intervals plus final positions) stayed within each face's ±30° sector.

The graph samples every 6 m across and 12 m downhill, with at most one 3 × 6 m
refinement. Nodes use a 1.8 m clearance and edges a 1.5 m sampled clearance.
Reachable width counts reachable columns, not a single unobstructed corridor.
Rejoin nodes have multiple accepted incoming graph edges; that count does not
establish independently skied branches. Returned polylines receive support
samples and production tree/mineral rider sweeps at intervals no longer than
4 m. Local graph endpoints are at downhill coordinate 2,784 m and can extend
beyond the playable disk; the receipt separately records the first crossings
of the 2,850 m base boundary and their separation.

Each face received one ordinary-input pilot attempt from its normal launch, using
the first swept-clear path. The fallback order is the first nonempty path, then
an explicitly unsurveyed radial target. The pilot steps the unchanged solver at
120 Hz, refreshes intent every 12 ticks, and pulses jump release for one tick.
It stops on a crash, the production base boundary, 800 simulation seconds, or
30 seconds without a 2 m increase in maximum radius. No session, record store,
rendered view or timing benchmark is involved. Pilot failure limits that
attempt's evidence; it does not prove an unskiable mountain. User skiing and
other seeds were separate acceptance work and remain so.

Detailed historical polylines, tick inputs, one-second position samples and logs
remain in ignored `artifacts/v15_route_audit/` and
`artifacts/guarded/v15-route-audit/`. The receipt's recorded producer command
belongs to its model-28 source snapshot; rerunning the current producer creates
the bounded current receipt above, not a replacement for that historical record.

## Deterministic jobs and packed data

[GenerationJob](../scripts/world/generation_job.gd) owns up to six workers, a
mutex-protected queue/snapshot and fixed result slots. Workers read immutable
stages and return disjoint packed results. Random streams derive from seed,
stage and stable candidate ID; conflicts/thinning resolve in candidate order.
Cancellation joins every worker. Face records hold weak owner references.

[PackedTrees](../scripts/world/packed_trees.gd) owns packed positions, dimensions,
yaw, candidate/ecology metadata and a linked spatial index. Production v17 does
not populate the old dictionary obstacle list. Collision, snow, previews,
forest preparation and motion use indexed access; returned dictionaries are
bounded query results.

Visual species assignment stays in `ForestPlacement.warm_asset`, shared with the
direct scenery path. Coherent noise forms broadleaf pockets within living conifer
stands; a separate noise channel gives golden birch or maple local dominance with
soft mixed edges. Bare/dead trees retain their existing assignment. A dominant
variant plus minority per-tree silhouettes avoids repeated neighboring crowns.
These rules consume position/seed without advancing physical random streams.
Changing the art or visual assignment refreshes scenery preparation only; physical
tree positions, dimensions, candidate/ecology IDs and the 4 m support grid remain
unchanged by visual assignment. Generator 17 retains the generator 16 physical
Standard target reduction of 15% and sparse upper trees within that total. Dense stands
retain their previous treeline fade. A coherent sparse band uses actual shaped
altitude, thins toward isolated trees above the local treeline, and fades from
4,080 m to a noise-varied ceiling near 4,250 m. The user selected trees reaching
around 4,200 m, with very sparse coverage closer to the summit. Gentle, low-rock
support is preferred. A 120-280 m radial fade protects the summit centre; existing slope, mineral,
trunk-spacing, drop and natural-opening exclusions still apply. The forest-only
Dev94 revision preserved foundation terrain and mineral placement. Generator 17
also changes channels and clearance as described below.
Old version-16 recipes and their race/record/ghost references are incompatible;
regenerate worlds and input fixtures rather than changing recorded identities.
Personal files remain untouched. Historical Dev94 verification: [natural forest review](../artifacts/natural_forest_20260917/REVIEW.md).

Indexed landforms and an 8 m ecology filter narrow candidates before exact
surface/material/protection checks. Rebuild normals after support mutations;
reuse them inside an immutable stage. Tree-snow tiles read the same inputs,
combine overlap by maximum, then commit. Final seating precedes collision-index
construction. Timings distinguish terrain, placement/filtering, snow, seating,
collision, normals, hashing and I/O.

[MountainPreparation](../scripts/world/mountain_preparation.gd) prepares maps,
chunk arrays, shared triangle/LOD templates, readability fields, seated forest
poses and mineral buffers off-thread. Asset/root metadata is acquired on main.
Scenes, resources and GPU submissions remain on supported main-thread paths;
physical reconstruction, scenery preparation and scene upload are different costs.

## Physical snow

The shared heightfield's `sample_height` preserves the exact triangle choice,
clamping and arithmetic of `sample`, and omits its dictionary and unused normal.
The four-metre contact stencil uses this narrower query. The base heightfield and
current massif opt in by exact script identity before publication; derived
adapters retain virtual `sample` dispatch, including inherited overrides. Heights,
bounds and mutable adapter values are read on every call; no terrain results are
cached and worker queries never mutate dispatch metadata.

V15 powder queries skip faces with zero sector weight and snow outside the face's
depth envelope. The narrow channel-floor query omits unused cut depth and keeps
the full query's float32 result rounding. Continuous snow noise, bowl weights,
tree deposits and material interpolation retain their existing equations.

Most ordinary snowy terrain has roughly 19–27 cm of loose depth, with deeper
sheltered deposits. Material/depth are physical inputs, including between trees;
snowy appearance alone does not determine grip. Contact laws live in [Physics](PHYSICS.md#snow-contact-and-small-banks).

Continuous seeded wind waves and broad rounded relief supplement localized
wave patches, mounds and sheltered banks. Their scale must be representable on
the 4 m grid (broad features approximately 15–50 m); snow randomness is separate
from geology/ecology. Relief fades around rock, summit, shallow exits and
protected drop approaches, including snowy cross-slopes. Shape from immutable
input rows before final seating.

Tree-anchor deposits use approximately 9–16 m footprints with a 1 m grid-addition
cap. Overlap uses maximum, not addition. Measure actual trunk rise/local prominence
against surrounding added snow; a grid peak is not visible mound height. Reseat
trees/mineral foundations and preserve the original material/exposure contract:
changed normal stencils must not expose rock merely because snow was added.
Runtime contact cannot modify this immutable mountain. Cosmetic powder/tracks
are in [Rendering](RENDERING.md#snow-presentation).

## Geology and collision

[CrashCollision](../scripts/world/crash_collision.gd) owns the ragdoll-only
terrain/obstacle neighborhood, separate from the 120 Hz skiing support solver.
Interior square terrain chunks use `HeightMapShape3D` from the completed 4 m
height array, avoiding render-mesh extraction and general triangle cooking.
The grid origin, scale and cell diagonal match terrain rendering; clipped
footprint edges and irregular meshes keep their exact triangle shape. Jolt's
height-field compression can move ragdoll contacts by a fraction of a millimetre
(below 0.5 mm in the Standard fixture). This does not change ski support samples,
the deterministic solver, recorded recovery events or cache formats. Terrain
keeps its 240 m preparation / 350 m retention and 45 m refresh thresholds.
`tests/terrain_collision_suite.gd` checks full grids, clipped holes, normals,
travel, retirement and return with real Jolt ray contacts.

Obstacle refresh reads packed positions for distance/retirement checks and only
expands a full tree record when publishing a new body. Resident body identity,
exact cylinder dimensions, material tags and diagnostic filters remain intact.
Mineral bodies still publish all authoritative convex pieces immediately inside
the existing 175 m preparation / 240 m retention window. Jolt cooks convex
resources lazily on first body attachment. A nearest-first 300 m lookahead warms
shared catalog pieces through one reusable body with collision layer/mask zero;
its shape owner is cleared after every piece. Main-thread work stops after eight
pieces or 750 microseconds, whichever is reached first. One native cook cannot be
interrupted, so this is a scheduling budget, not a hard frame-time guarantee.

Movement rebuilds the bounded record queue alongside the existing 45 m
neighborhood refresh. Leaving the lookahead cancels obsolete queued work; a
required formation completes synchronously even if warming is incomplete.
Cached shapes belong to catalog records, not visited placements, and share the
existing world lifetime. Restarting the world releases the cache and warmup
body. `tests/streaming_collision_suite.gd` covers partial preparation, fast/reverse
travel, cancellation, full publication and ray-tested scaled collision.

[MountainGeology](../scripts/world/mountain_geology.gd) owns placement and spatial
collision data; [MineralCatalog](../scripts/world/mineral_catalog.gd) loads a shared
compressed resource validated against its source catalog. All 120 v3 base assets
are eligible; seeded geological context selects a subset rather than a fixed
quota. Cliffs sit along scarps, buried crags on ribs, debris below sources and
glacier formations in upper sheltered pockets. Avoid tiny upright wall modules
scattered through talus.

Catalog underside samples are at most 2 m apart plus boundary samples. Large
foundations may raise terrain through a smooth 16 m kernel, bounded to 8 m and
combined by maximum. Final snow shaping is followed by seating validation.
Reject vanished/unseatable placements; do not flatten rectangular pedestals.
Glacier footings include elevated lobes and a connected irregular apron.
Protected summit entries, drainage floors, ramps and drop approaches remain clear.

Continuous SAT sweeps the upright 0.7 × 1.6 × 0.7 m rider box against convex
pieces, including edge axes. The field returns the earliest tree/mineral hit;
the flavor adapter adds hut/gate contacts. Per-formation hierarchies reject
irrelevant pieces; projection spans are computed lazily. Nearby Jolt collision
uses the same points/transforms and shared shapes, not a Node per convex piece.
Rocks are solid obstacles, not another ski-support surface.

`prop_collision_surface.gd` wraps the terrain once; normal gameplay uses
`world.ski_surface`. Bound flavor props register oriented boxes and unregister
on removal. Call `sync_collision()` after changing a bound prop transform;
Godot colliders follow transforms independently. All LODs share collision.
Static prop bodies use layers 1 and 4 (mask 9) for the crash contract.

Offline decomposition/refinement preserves authored connected components.
Merging intersecting lobes first can close visible openings. The proxy audit
compares the complete rider box against source-triangle occupancy; corrections
subtract only source-verified empty regions. This is sampled free-space evidence,
not microscopic equivalence. Source triangles remain intact. Seating changes
enter height identity; placements/proxies enter obstacle identity.

## Zone, discoveries and background boundary

[MountainZone](../scripts/world/mountain_zone.gd) defines the 2,850 m summit-return
disk. Warning begins in the last 150 m. Race endpoints remain at least 25 m inside;
crossing aborts unfinished races and returns to summit free skiing through the
existing fade. A finish strictly before crossing survives; a tie does not.

Flavor placements provide seeded discoveries and solid hut/race-prop envelopes.
Authoring, picking, collision and rendering consume the same placement contract.
See [Racing](RACING.md#race-authoring) and [asset sources](ASSETS.md#flavor-and-equipment).

`mountain_footprint.gd` selects an irregular rendered outline from existing 32 m
blocks of the 4 m grid, without changing physical terrain/zone/obstacles. Partial
edge chunks retain exact triangles; preview uses the same outline. Scenery
identity/cache validation covers this retained layout. The authored, nonphysical
outer background and its adaptive connector are in [Rendering](RENDERING.md#background).
Optional [horizon shadows](RENDERING.md#distant-mountain-shadows) omit the variable
central mountain and fade outside its connector. They do not change physical
heights, collision, placement, race identity or terrain cache payloads.

## Terrain grass

`presentation/grass_placement.gd` reads the immutable 4 m heightfield and existing
habitat functions. Each 16 m cell uses a private seed and at most 160 candidates;
cluster noise leaves gaps and forest suitability raises patch density. Candidate
rank, scale, shape and orientation remain stable across streaming and graphics
changes. No tree, mineral, obstacle index, terrain sample, solver or race data is
added or changed by grass. The existing mineral overlay owns elevated rock grass;
terrain tufts are excluded beneath mineral bounds to avoid duplicate vegetation.

Snow **coverage** is `1-smoothstep(.42,.58,rock_fraction_at)`, matching the terrain
contact-material shader. It selects green, mixed or snow-strip geometry. **Coating**
is snow attached to blades, retaining their green base and shading. **Burial** is
the physical mantle depth multiplied by snowy coverage, lowering the authored
root beneath the visible surface. Raw mantle depth is never treated as exposed
ground cover. Blades with less than 7.5 cm remaining above snow are suppressed;
snowy depth above 29 cm, deep powder regions, ice-mask areas and slopes with up
normal below .70 are excluded. Ordinary open snow has sparse growth; sheltered
forest pockets admit taller coated blades. The physical snow mantle is unchanged.

`presentation/terrain_grass.gd` prepares only cells near the active camera,
preparing up to three cells concurrently on low priority worker pool jobs,
submitting at most three completed cells per frame and retaining at most 625 cells (including empty
ones). It neither scans the whole mountain each frame nor persists grass data.
New worlds own fresh residency and swept influence; cancellation drops pending
cells. Every job owns its placement RNG/noise and result and reads the completed,
immutable terrain/ecology and mineral broad-phase bounds. It creates no nodes,
resources or GPU uploads. Workers also filter the fixed density, group assets,
pack the shared 16-float transform/custom-data buffer and merge both LOD bounds
with the existing 0.65 m sway margin. Mesh AABBs are copied to value data when
grass is built; workers do not access mesh resources. The main thread collects
completed jobs, discards obsolete cells, creates the render resources and assigns
each buffer and bound once per LOD. Preparation timings include this packing;
`stream_grass` measures main-thread collection/publication. Density changes,
cancellation and teardown join the bounded outstanding jobs before releasing
inputs; ordinary frames never wait for unfinished preparation. Explicit synchronous
`stream` calls remain available for finite QA population/readback checks.
Existing physical/scenery payload schemas remain unchanged. Grass scripts,
shaders, runtime manifest and every mesh enter generation source identity and
export receipts. The existing `generation_sources.gd` self-hash rule also
invalidates physical caches when that source list changes, despite unchanged
generator/model versions and physical outputs; regenerate rather than bypass it.

## Caches and export

`user://mountain_cache_v17/<recipe SHA>.physical` stores final heights, snow,
material, normals, packed trees/index, face recipes, seated minerals and collision.
The paired `.scenery` stores maps, terrain arrays/templates, seated transforms
and regional batches. Scenery identity also pins physical fingerprints,
preparation source/assets, engine and graphics level.

Archives use independently hashed sections up to 16 MiB, strict bounded
lengths/types and a total-file limit. Validate bytes before decoding. Publish
only after structural validation; flush a unique temporary file before replacing
an entry. Failure/cancellation preserves previous data and existing caller results.

The configurable `generation/cache_budget_mib` default is 2 GiB. Eviction groups
physical/scenery files by recipe and last use; default and active recipes are
protected. A tiny budget may remain exceeded by protected entries and must report
that condition. Source builds hash actual dependencies and the running executable;
engine hashes are memoized only within the immutable running process. A shared
version label alone is insufficient.

Exports use the generation dependency manifest and prepared target-runtime
receipt. For the default recipe, a valid player-local slot precedes an optional
bundled bake; the bundle is read in place. Invalid/missing data falls through to
current generation with normal source/engine/integrity checks. Random/Custom
recipes cannot inherit Standard bundle hints. No user data is bundled.

## Loading estimates and cancellation

Creation/startup expose stage, completed/total work, elapsed time, remaining range
and cancellation state. Distinguish physical generation, additional time to ski
and peak-memory estimates. Local completed stages calibrate work; explicit
single-worker experiments are excluded. Header cache hints are provisional until
full integrity/scenery checks. A rejected archive restores fresh-work estimates.

Cancellation checks rows, tiles, candidates, archive sections and upload
checkpoints; the entire physical mountain exists before skiing. Cancelled previews
retain the previous draft. Startup frees partial scenes and offers Retry/Quit
after joining workers. A completed physical cache may survive later scenery
cancellation. Tests and current coverage are in [Validation](VALIDATION.md#mountain-evidence).

## Cosmetic rock gravel

`gravel_placement.gd` reads the completed 4 m field and mineral collision index.
Private seeded 12 m regions select irregular gravel beds and sparse surrounding
accents. No generator RNG, height, tree, obstacle or mineral placement is written.
There is no physical-map regeneration or compatibility-version change.

Each half-metre tile checks its centre and corners: contact rock fraction >=0.60
(the terrain shader is fully rock at 0.58), normal.y >=0.78, in-bounds and no ice
exposure. Mineral envelopes exclude covered terrain. A filtered, bounded mask
excludes existing grass roots with rounded gaps; it uses the same deterministic
grass candidates and never reduces their density. Bed edges select individual
stones rather than cutting visible tiles into squares.

The vertex shader seats each stone along the exact triangle normal and clamps
exposure at triangle creases. Burial is at least 30 percent of source height and
at least source height minus 1 cm. These are render vertices only: gravel owns
no contact surface, collider, obstacle proxy or skiing response.

`mineral_scenery.gd` attaches the scene-owned streamer after mineral submission
and forwards quality changes. Gravel cells/materials are never persisted in
scenery or physical caches. Changing this wrapper refreshes scenery preparation
once; independent gravel implementation/resources are runtime inputs, not cache
payload dependencies. The generation dependency owner and physical signature
remain unchanged. See [Rendering](RENDERING.md#cosmetic-rock-gravel) for residency
and [Validation](VALIDATION.md#cosmetic-gravel-checks) for evidence.

## Connected local openings and upper groves (generator 17)

Woodland glades use finite bent passages with tapered, varying-width edges.
The former straight 250 m extension at each end is removed. Channel cuts are
shallower, more sinuous and tapered within each tier. Their narrower cores keep
continuous obstacle clearance through bends and forks, connecting the lower
forest stands without long straight lanes. Shorter, narrower links connect both
ends of local glades to the existing network or open runout. Rare large boulders
may split an opening; downstream alternatives remain required. Sheltered groups
become fuller near 3,500 m, fading into sparse higher trees within the fixed
170,000 Standard total. Altitude counts remain seed dependent, not quotas.
Summit access, drop approaches and the shared
4 m support remain authoritative. Downhill connections are measured on the final
physical world; generated openings never apply a force or steer the player.

Generator 16 recipes and their race/record identities are incompatible with 17.
The Dev94 forest measurements remain historical; their timing routes cannot
certify this changed terrain. See the current opening evidence in
`artifacts/natural_openings_20260917/` and the scoped development note.

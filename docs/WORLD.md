# World generation and terrain

## Recipe and retained landforms

[MountainDefinition](../scripts/world/mountain_definition.gd) owns portable
recipes and field reconstruction. Routine mountain work uses
`MountainDefinition.generate(849205174, 15)` or
`mountain_cache_v15.gd.generate(849205174)`; explicit older generators remain
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

Standard requests 200,000 trees and 16,022 minerals; Extreme requests 1,000,000
and 80,110. Report achieved counts separately: spacing/protected terrain can
saturate placement. The user accepts roughly 600,000 trees where natural space
limits the million-tree request. Synthetic capacity tests do not prove natural
placement feasibility or skiable routes.

## Deterministic jobs and packed data

[GenerationJob](../scripts/world/generation_job.gd) owns up to six workers, a
mutex-protected queue/snapshot and fixed result slots. Workers read immutable
stages and return disjoint packed results. Random streams derive from seed,
stage and stable candidate ID; conflicts/thinning resolve in candidate order.
Cancellation joins every worker. Face records hold weak owner references.

[PackedTrees](../scripts/world/packed_trees.gd) owns packed positions, dimensions,
yaw, candidate/ecology metadata and a linked spatial index. Production v15 does
not populate the old dictionary obstacle list. Collision, snow, previews,
forest preparation and motion use indexed access; returned dictionaries are
bounded query results.

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

## Caches and export

`user://mountain_cache_v15/<recipe SHA>.physical` stores final heights, snow,
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

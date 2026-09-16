---
id: "AA-20260914-094136-render-distant-forest-stands"
title: "Render distant forest stands with coherent grouped representations"
status: ready
priority: P2
depends_on: []
created: "2026-09-14T09:41:36Z"
updated: "2026-09-16T21:59:44Z"
source_thread: "01a09c68-b71e-7cc1-b01a-291cd5c446e8"
---

# Render distant forest stands with coherent grouped representations

## Current disposition — 16 September 2026

Independent representation experiment, grouped with forest GPU work. Existing
far trees already use two-triangle cards; a stand proxy must save measured total
work beyond those cards, not merely have fewer source triangles. The previous
8 m batches, CPU per-frame LOD compaction and LOD1 alpha trimming were rejected;
do not repeat them. Reuse a matching saved baseline and reject poor visuals before
timing. The old baseline investigation is no longer a dispatch prerequisite.

## Outcome

Make distant forests substantially cheaper by rendering coherent stands as
groups while retaining the mountain's recognizable canopy outlines, openings,
depth and natural species pockets. Nearby trees retain individual geometry and
interaction. This changes visual representation, not physical map generation.

## Current state and evidence

At Dev 31 / 36b25d3 the production forest already has individual near/mid tree
meshes, eight-view far impostors and spatial MultiMesh groups. The 384 m distant
grouping in [ForestPlacement](../../scripts/presentation/forest_placement.gd)
reduces submissions but still represents each tree separately. It is not a
stand-level proxy. [Rendering](../../docs/RENDERING.md#terrain-forests-and-lighting)
owns the current distance, bounds and foliage-aid contract.

The [colorful forest receipt](../../docs/COLORFUL_FOREST_RESULTS.json) retains
about 1,620 mean draw submissions and 13.737 million submitted primitives in a
dense scene, but neither metric isolates distant forest cost. Far individual
cards are already only two triangles; stand HLOD is promising only if it removes
enough submissions, overlapping cutout pixels or material work to exceed its
own proxy cost. Adding more cards can make it worse.

Warm variants are deliberately coherent birch/maple pockets with an evergreen
backbone, not uniformly random tree colours. Physical Standard remains 200,000
trees. The user asked for natural mixes and deferred density/upper-altitude
regeneration to [its own task](AA-20260913-232221-natural-forest-generation.md).
[Godot HLOD](https://docs.godotengine.org/en/stable/tutorials/3d/visibility_ranges.html)
supports replacing groups at distance; the actual representation and transition
must be validated against this game's steep slopes and fast moving camera.

## Agreed decisions and scope

Own derived distant forest representation and its selection/publication only.
Build from the actual seated transforms, tree variants and terrain of the cached
mountain. Do not reroll species, placement or physics, thin stands, shrink the
forest draw distance or replace nearby branches with cards earlier merely for FPS.
Original source assets, runtime imports and UIDs stay byte-identical; new derived
resources need provenance and the existing $5/month LFS hard stop.

Keep Godot, the Node-independent 120 Hz solver, shared 4 m terrain authority,
tree/mineral collision, skiing response, race/replay and personal data unchanged.

Approve a visually equivalent or better representation, including bounded
multi-view/depth-aware stand proxies or simplified clustered geometry. Routine
choice belongs to the measured prototype. Maintain silhouette, important internal
gaps, warm pockets and snow; opaque blobs, billboard walls, baked lighting that
breaks weather/night, and visibility pops are not acceptable tradeoffs.

This task depends on the repeatable baseline. Prefer evaluating after
[tree selection](../blocked/AA-20260914-094136-select-forest-lods-before-submission.md) if delivered, then rebaseline; its completion
is not a hard dependency because the two mechanisms can be investigated
independently. Coordinate shared forest files and serialized timing. Occlusion
and shader/pass changes have separate owners; do not combine them in the A/B.

## Implementation approach

1. Attribute far forest submissions, vertices, cutout overdraw and GPU intervals
   on a distant valley/stand view and a dense skiing route. Record projected
   coverage and separate near geometry, individual cards and background vistas.
   Estimate an upper bound on saved cost before authoring a large proxy library.
2. Derive stable stand clusters from actual positions and canopy occupancy,
   retaining clearings, terrain breaks and species transitions. Cluster size is
   a render decision, not an ecology change; prevent obvious square grid edges
   and any reassignment of the accepted natural mixes.
3. Prototype one bounded representation on a small selection of existing stands.
   Compare grouped geometry against depth/multi-view proxies as evidence requires.
   Use projected error and conservative bounds to keep nearby silhouettes and
   internal parallax accurate. Representation-switch distance may change only
   when matched moving review shows equal or better perceptible detail; forest
   reach and visible density stay fixed. Preserve the individual-card fallback
   until a stand proxy is ready and across unsupported views.
4. Define proxy ownership for daytime/cloud/night lighting, snow, canopy aid,
   FSR motion and shadow policy. Current far cards do not cast shadows; do not
   introduce an unmeasured new shadow/GI pass. Wind can remain small at distance
   but must not freeze or jump at the handoff. Stable IDs and coverage prevent
   double canopies, holes, crossfaded transparency cost and ghosted history.
5. Store derived scenery independently of physical generation. Key it by actual
   placement/asset/material/bake inputs and renderer schema; reject and rebuild
   incompatible derived data. Record generation time, storage, texture bandwidth,
   GPU allocation and repeated-load cost. Bound resident proxy data and teardown.
   No full map regeneration or new paid service is needed.
6. Evaluate the prototype against the current individual-tree renderer. Expand
   only if named cost and total frame improvement justify it. If distant work is
   too small or visual equivalence fails, preserve the negative result and restore
   owned experiments; do not ship lower quality to force an optimization claim.

## Acceptance and verification

- [ ] Separate [baseline](../abandoned/AA-20260914-094136-establish-repeatable-rendering-baseline.md) attribution proves enough far-forest
  work is removed. Three matched capture-free 15-second before/after windows
  demonstrate repeatable rendered-FPS or frame-tail gain and lower relevant GPU
  or submission cost; near forest/open/mineral controls show no reproducible
  regression. Report every repetition, memory/bake/storage cost and uncertainty.
- [ ] Use perf-vegetation/perf-mixed for local component checks and a qualified
  existing Standard valley/forest route for actual mountain scope, under the
  documented Shared/Exclusive/FpsCritical guards. Retain 4K High, Auto 0.75,
  effects and density, plus a separate normal 120-cap confirmation. Do not use
  the gravel shelf or old snow-facing trace as distant-stand acceptance.
- [ ] Native matched stills and chronological movement cover valley views,
  oblique steep slopes, skyline stands, visible clearings, silhouette crossings,
  rapid look-back, approaching/receding transitions and 170 km/h travel. Check
  native and Auto reconstruction separately, affected quality tiers, daylight,
  dusk/night, snowfall and canopy aid. Inspect a second existing/cached seed or
  a targeted synthetic stand for different shapes; never trigger a cold map bake.
- [ ] Automated deterministic grouping, bounds, ownership/fallback, cache
  invalidation, cancellation, quality switching, re-entry and teardown checks
  pass alongside affected density_lod_suite, density_spatial_suite,
  colorful_forest_suite, foliage_sight_suite and native forest_preparation_suite.
  Exact physical placement/collision checksums remain unchanged.
- [ ] Original asset/import bytes and IDs are preserved; new derived resources
  have reproducible generation and verified provenance/size. No growth across
  repeated traversal, no missing/double canopy and no wrong-instance motion.
- [ ] Update Assets, Rendering and World where their contracts change, plus
  Validation/skills for maintained producers. Commit/push only validated owned
  work with a captured development note. Preserve failed prototypes/evidence
  needed for review and clean disposable outputs after push.

Human acceptance: final forest appearance and continuous motion comfort are
separate user follow-ups, not worker-completion gates; agent visual inspection
must still pass before retaining the implementation.

## Open questions

None

## Completion record

Pending implementation. Record whether stand proxies improved the measured
workload, the representation and ownership contract, comparison/source identities,
checks, remaining acceptance, Dev ID and commit/push. A prototype alone is not
task completion; record blocked findings if the performance/visual gate fails.

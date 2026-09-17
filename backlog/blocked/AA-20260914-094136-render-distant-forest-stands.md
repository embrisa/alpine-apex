---
id: "AA-20260914-094136-render-distant-forest-stands"
title: "Render distant forest stands with coherent grouped representations"
status: blocked
priority: P2
depends_on: []
created: "2026-09-14T09:41:36Z"
updated: "2026-09-17T22:40:00Z"
source_thread: "01a09c68-b71e-7cc1-b01a-291cd5c446e8"
---

# Render distant forest stands with coherent grouped representations

## Corrected reconstruction follow-up — 18 September 2026

Root reviewed Terra's diagnosis and verified the depth path using a rendered
three-plane calibration. R8 depth and full3D orthographic unprojection pass;
the original shared grid and viewport-aspect mapping had concrete defects.
Independent patches remove ribbons, but horizontal front-layer bakes lose canopy
from elevated views. Elevated actual-depth bakes restore canopy; conservative
patch padding still leaves chunky crowns, square holes and disconnected pieces
in the matched400m side view.

**Candidate is visually unacceptable; no timing.** This remains an isolated
1,686-tree generator18 cell. Production is unchanged. Final candidate inventory:
267,274 triangles across all views,25.51MiB color textures before mesh memory;
scene draws fall31 to11–13 but submitted primitives rise substantially. Counters
are not a performance result. No residency, moving-view or LOD handoff is accepted.
See `artifacts/far_stand_splats_20260918/REVIEW.md` for the compact review, source,
numeric calibration and six matched images. Do not time these variants unchanged.
Resume with a materially different representation and bounded memory/residency.
On18September the user authorized progressing the four prepared ideas while this
task and the unavailable-Mac task remain blocked.

## New bounded representation pilot — 17 September 2026

A generator 18 local pilot replaced iterative depth-texture projection with
coarse indexed depth meshes and one color lookup per fragment. It uses one
current 384 m cell with 1,686 production-seated trees, four 192 m tiles, eight views,
four slabs and 8 px cells, plus complementary view coverage.

**Visually rejected without timing:** matched native front/oblique/side views
show stretched canopy ribbons and broken silhouettes. Production is unchanged.
The current user approval of pole animation does not approve this forest pilot.
The exact decoding/interpolation cause is not yet isolated; this result rejects
the current reconstruction rather than every grouped representation. No whole
mountain memory/residency design or LOD handoff is implemented. Retained source,
inputs and six images: `artifacts/far_stand_mesh_20260917/REVIEW.md`.
Do not time this variant unchanged. The corrected follow-up above supersedes the
unresolved decoding question. The user's gaming session has ended; visual quality
is the remaining gate for this representation.

## Earlier disposition — 17 September 2026, user-approved timing

The user accepted the prototype screenshots for performance measurement,
superseding the earlier agent-only visual gate. The 428-tree patch was timed:
head-on 201.24 → 200.12 FPS; oblique 189.58 → 189.08 FPS. Its shared original batches
remained submitted, so one complete 384 m cell was tested to resolve that limitation.

The complete cell replaces 2104 trees in 26 far batches with 16 grouped quads.
At 4K High Auto 75, capture-free stationary comparisons give 205.04 → 201.07 FPS
head-on and 194.74 → 189.19 FPS obliquely. GPU cost rises 0.106–0.147 ms despite
10 fewer draws and 4176 fewer submitted primitives. No consistent CPU gain.
These are matched distant mountain views, not the dense-route skiing baseline.

**Blocked on performance: candidate has no meaningful performance gain.**
Production cards, assets, placement and settings remain unchanged. The expanded
images also show more obvious canopy loss; the user approved the original patch
for timing, not this larger variant for production. This does not establish that
all grouped representations fail. [Current review](../../artifacts/far_stands_timing_20260917/REVIEW.md).

**Resume condition:** a materially different representation with lower total
GPU/frame cost and a bounded memory/residency design. Respect the user's accepted
visual tradeoff; do not reinstate the earlier agent-only veto or automatically
repeat the unchanged four-layer shader. Reuse the completed attribution.
The separate [material-submission idea](../ideas/archive/IDEA-20260917-090000-share-far-tree-material-submissions.md)
remains unimplemented. The current economical one-candidate policy supersedes the
older broad repetition matrix below; the extra cell check resolved a specific
measured partial-batch limitation.

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
regeneration to [its own task](../tasks/AA-20260913-232221-natural-forest-generation.md).
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
[tree selection](../abandoned/AA-20260914-094136-select-forest-lods-before-submission.md) if delivered, then rebaseline; its completion
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

Dev 92 (milestone `changes/bc95cefe1c3f4d82a8a9d142b9d5991f.json`): bounded
attribution and rejected prototype recorded; implementation remains blocked.
Guarded native diagnostic and visual runs exited 0; exact replay/focus checks and
paired camera metadata passed. Visual acceptance failed. No candidate FPS claim.
No production runtime, source asset/import, generation, collision or settings edit.
Remaining: acceptable representation, valley cost/coverage attribution, full moving
transition/lifecycle/quality/weather checks, bounded storage/residency and actual
candidate timing if the visual gate passes. Human acceptance is not this blocker.


Dev93 follow-up (`changes/2df364d43da84473b92013daa54cb63a.json`): user visual
acceptance authorized timing. Both guarded comparisons exited0, all paired
cameras/residency matched and focus loss was zero. No performance gain in either
the pictured patch or the complete-cell extension. Production remains unchanged;
the current blocker is effective rendering cost. No skiing,transition,quality/cache
lifecycle or whole-forest integration acceptance is claimed.

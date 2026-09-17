---
id: "AA-20260913-232221-natural-forest-generation"
title: "Thin forests by 15 percent and extend sparse trees into higher terrain"
status: done
priority: P2
depends_on: ["AA-20260912-094935-colorful-forest-variety"]
created: "2026-09-13T23:22:21Z"
updated: "2026-09-17T10:31:37Z"
source_thread: "01a09c68-b71e-7cc1-b01a-291cd5c446e8"
---

# Thin forests by 15 percent and extend sparse trees into higher terrain

## Outcome

Make the mountain's forests less crowded overall, with a natural transition to
occasional trees higher up. The user requested "like 15% less trees and also
sparse trees at higher altitudes", then explicitly deferred map regeneration
to a later backlog task. They also requested "natural nature mixes of forest
and not crazy mixes". Authoring this task does not regenerate any map now.

## Authoring state and evidence

Source inspected on 2026-09-14 local time at Dev 25 / `9fb3bad`, with the colorful
tree integration and an unrelated startup task still dirty in the shared checkout.
These observations are code evidence, not a generated result or acceptance.

- [GenerationSettings](../../scripts/world/generation_settings.gd) owns the
  200,000-tree Standard baseline; preset factors request 100,000 / 200,000 /
  400,000 / 1,000,000 trees. Achieved counts can saturate independently of targets.
- [Massif placement](../../scripts/world/generators/alpine_massif_v16.gd) uses an
  8 m ecology filter, rejects candidates inside a roughly 950 m summit radius,
  checks slope/rock coverage, protected openings, spacing and mineral clearance,
  and publishes deterministic [PackedTrees](../../scripts/world/packed_trees.gd).
  Changing a treeline parameter alone cannot bypass all existing upper-area gates.
- [Face ecology](../../scripts/world/generators/alpine_face_v16.gd) gives each face
  a treeline of 3,270â€“3,450 m plus coherent variation. Both woodland and scattered
  paths currently share a fade from treeline minus 180 m to plus 90 m. Scattered
  density also excludes uphill local coordinates below 900 m. Preserve the
  distinction between altitude and radial/downhill coordinates.
- [ForestPlacement](../../scripts/presentation/forest_placement.gd) owns visual
  family/variant assignment and root seating. The prerequisite integrates birch
  and maple pockets into the existing physical trees. It does not change tree
  count, physical ecology, terrain or collision. Build on its delivered state.
- [World](../../docs/WORLD.md), [Architecture](../../docs/ARCHITECTURE.md) and
  [Validation](../../docs/VALIDATION.md) own generation, compatibility and bounded
  validation. No existing active/archived task with this density/upper-tree scope
  was found during authoring.

## Agreed decisions and scope

- Reduce the Standard physical tree target by 15%, from 200,000 to **170,000**.
  Apply the same baseline reduction to the density presets and Custom factor;
  preserve settings semantics and report requested versus achieved populations.
  Upper-altitude trees are included in that total, not added on top.
- Extend a sparse, irregular tree population above the current dense forest
  boundary. Let woodland density taper into small groups and isolated trees,
  with exposed high ridges and the summit still mostly open. Choose bounded
  altitude/exposure thresholds from current terrain surveys; do not blanket the
  alpine zone or simply move a sharp forest wall uphill.
- Use coherent, plausible local species groupings and gradual transitions.
  Retain an evergreen backbone; birch/maple pockets should have recognizable
  dominant families and restrained neighboring mixtures. Avoid random rainbow
  selection and identical striped, circular or grid-shaped stands. The existing
  stylized warm foliage is intentional; exact winter botany is not a requirement.
- This is a physical generator change: increment the current generator identity,
  reject/regenerate incompatible mountain and scenery caches, and create fresh
  traces/fixtures. Do not add migration or compatibility shims. Explain effects
  on races, records and ghosts using their actual source/schema contracts.
- Preserve the Node-independent 120 Hz solver, 4 m terrain authority, mineral
  populations/collision and physical tree collision behavior. Keep established
  landforms, routes/openings and ski response; only tree ecology/population and
  consequent tree-local snow/seating may change. No animation-driven steering.
- Preserve existing asset/import bytes, UIDs, art quality and maximum visibility.
  The requested population reduction is a world design decision, not permission
  to hide physical trees through graphics settings or reduce other scenery.

On 17 September the user reviewed the first result (highest trees 3,680-3,730 m)
and explicitly chose a higher sparse extension: **around 4,200 m, with very sparse
trees much closer to the summit**. Keep the 170,000 total and open summit centre.
The initial lower-reaching candidate is retained as preliminary evidence only.

## Implementation approach

1. Recheck the prerequisite, dirty ownership and current identity. Save matched
   old-world surveys before edits: counts by face/elevation/ecology, nearest-neighbor
   spacing, slope/rock/protected-opening exclusions, representative stand images
   and bounded riding/performance windows. Record actual altitude distributions.
2. Update baseline population and the narrow ecology/placement gates together.
   Use a separate sparse upper transition where necessary; retain deterministic
   candidate order, worker independence, cancellation and spatial clearance.
   Fit existing tree scale/proxies to altitude without changing collision rules.
3. Bump the authoritative generator and replace affected current fixture/cache
   paths coherently. Keep historical evidence explicitly historical; remove only
   superseded implementations within scope. Prepare the required seeds explicitly
   under Exclusive full-mountain admission; missing caches never cause an implicit
   cold bake during ordinary tests.
4. Update preview/population estimates, generator/source manifests, export fixture
   production and affected tests/docs. Inspect the maintained test map and producer
   catalogs rather than copying obsolete v15 commands into a new generator claim.

## Acceptance and verification

- [x] Standard requests 170,000 trees; the default and one additional seed achieve
  approximately 15% fewer trees than their matched old worlds. Report saturation
  or exclusions explicitly. Verify settings/preset targets and deterministic
  worker-count/cancellation/cache roundtrip behavior with focused automated tests.
- [x] Elevation/face histograms and inspected mountain views show sparse trees in
  previously empty suitable higher terrain, a gradual density transition, and
  preserved summit/ridge/opening readability. Check several faces and two seeds;
  provide normal chase and first-person views with visible trees, not snow-only
  framing, plus a short chronological clip through a representative transition.
- [x] Root seating, tree/mineral non-overlap, spacing, collision proxies and 4 m
  support remain valid. Run affected generation, scenery-integrity, grounding,
  density-LOD and cache suites using the smallest applicable fixtures. Any
  physics/input/session edits require the full physics/runtime suites through
  `./godotw --headless --script ...` under the guard.
- [x] Fresh 15â€“30 second ordinary-input traces cover lower forest, the upper
  transition and a mixed stand. Run the three bounded 4K High route comparisons, each with one warmed candidate sample under the current economical policy
  under FpsCritical with unchanged rendering settings/camera/weather; keep images
  outside timing. Report FPS, mean/p95/p99, CPU/GPU cost, loading/preparation and
  actual changed populations. Because physical placement changes, state which
  routes/inputs remain comparable and do not call changed endpoints identical.
  Attribute tree-count savings separately from any rendering optimization.
- [x] Regenerated current fixtures reject old incompatible identities cleanly;
  personal records/preferences and original recordings remain preserved. Update
  owning guides and affected skills, validate the backlog with preserve-dirty,
  record a new development note with scoped metadata and actual checks, then commit
  and push only owned work. Preserve unresolved evidence during scoped cleanup.

Human acceptance: the user's visual and skiing review of openness, natural species
mixes and upper-tree placement is separately pending, not a worker completion gate.
Automated placement and bounded FPS evidence do not establish human acceptance or
full-descent route coverage.

## Open questions

None

## Completion record

Implemented generator 16 in Dev94, with development note
`changes/49a053e57adb49ad97e223763b12e061.json`. Standard now requests and achieves
170,000 trees on seeds 849205174 and 638201943; presets retain their factors.
The user-selected upper extension reaches 4,234.1 / 4,194.4 m, with only 36 / 32
trees above 4,000 m. Dense stands retain their previous fade; summit centre,
mineral clearances, protected openings and trunk spacing remain intact.

The actual source-based surveys preserve landforms and mineral placement;
foundation differences after removing tree-local snow stay below 1 mm. Full
world checks passed on both seeds, including every neighboring trunk, root and
mineral foundation, exact cache reconstruction and six connected downhill graphs.
Worker counts 1/2/6 and cancellation passed. Full physics (56) and runtime (192),
grounding, LOD, terrain-query, current fixture, scenery integrity and off-map
checks passed. Unchanged compact checks were reused after the upper-band tuning;
affected ecology and full-world checks were repeated. Initial legacy snow-mode
and stale v15 fixture failures were corrected before acceptance.

Matched production chase/first-person views on both seeds and the 15-second
chronological transition were inspected separately from timing. Human skiing and
visual acceptance remains separately pending. No full-descent claim is made.

Fresh ordinary-input routes ran with native 4K High / Auto 75% / FG and GI off,
normal timed ghost recording, one route warmup and one clean sample each.

- Upper: **144.03 FPS / 6.943 ms**, GPU 5.300 ms; p95/p99 8.872/11.350 ms. Old inputs preserved: True; endpoint difference 0.000 m.

- Mixed: **139.59 FPS / 7.164 ms**, GPU 5.749 ms; p95/p99 9.518/10.948 ms. Old inputs preserved: False; endpoint difference 0.209 m.

- Lower: **127.40 FPS / 7.849 ms**, GPU 6.535 ms; p95/p99 10.026/13.100 ms. Old inputs preserved: False; endpoint difference 52.172 m.

Only the upper route retains identical old inputs and endpoint. Lower and mixed
needed fresh controls after old inputs encountered changed trees; these are new
current-world references, not exact A/B FPS gains. The Dev78 v15 dense average
is retained with an explicit mismatch notice. Tree thinning is the agreed world
design change; no separate renderer optimization is claimed.

Generator 15 identities are rejected; current fixtures and export manifest were
regenerated. Personal preferences, records and original recordings remain intact.
The 120 Hz solver, 4 m authority, tree asset/import bytes, UIDs, LOD distances and
rendering quality are preserved. Renamed source/test UIDs move with their files.

Evidence: [structured results](../../docs/NATURAL_FOREST_RESULTS.json),
`artifacts/natural_forest_20260917/REVIEW.md`, matched views, compact transition
clip, current traces and native timing receipts. The first lower-reaching
candidate remains explicitly preliminary. Updated World, Architecture,
Development, Validation, performance handoff, relevant skills and producer map.
The [scoped benchmark metadata idea](../ideas/IDEA-20260917-110000-use-scoped-benchmark-metadata.md)
is recorded for the final ideas phase. Backlog validation uses preserve-dirty;
source and artifact hash audits were skipped under the current policy.

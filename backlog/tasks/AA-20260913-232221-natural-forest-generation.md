---
id: "AA-20260913-232221-natural-forest-generation"
title: "Thin forests by 15 percent and extend sparse trees into higher terrain"
status: ready
priority: P2
depends_on: ["AA-20260912-094935-colorful-forest-variety"]
created: "2026-09-13T23:22:21Z"
updated: "2026-09-13T23:22:21Z"
source_thread: "01a09c68-b71e-7cc1-b01a-291cd5c446e8"
---

# Thin forests by 15 percent and extend sparse trees into higher terrain

## Outcome

Make the mountain's forests less crowded overall, with a natural transition to
occasional trees higher up. The user requested "like 15% less trees and also
sparse trees at higher altitudes", then explicitly deferred map regeneration
to a later backlog task. They also requested "natural nature mixes of forest
and not crazy mixes". Authoring this task does not regenerate any map now.

## Current state and evidence

Source inspected on 2026-09-14 local time at Dev 25 / `9fb3bad`, with the colorful
tree integration and an unrelated startup task still dirty in the shared checkout.
These observations are code evidence, not a generated result or acceptance.

- [GenerationSettings](../../scripts/world/generation_settings.gd) owns the
  200,000-tree Standard baseline; preset factors request 100,000 / 200,000 /
  400,000 / 1,000,000 trees. Achieved counts can saturate independently of targets.
- [Massif placement](../../scripts/world/generators/alpine_massif_v15.gd) uses an
  8 m ecology filter, rejects candidates inside a roughly 950 m summit radius,
  checks slope/rock coverage, protected openings, spacing and mineral clearance,
  and publishes deterministic [PackedTrees](../../scripts/world/packed_trees.gd).
  Changing a treeline parameter alone cannot bypass all existing upper-area gates.
- [Face ecology](../../scripts/world/generators/alpine_face_v15.gd) gives each face
  a treeline of 3,270–3,450 m plus coherent variation. Both woodland and scattered
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

- [ ] Standard requests 170,000 trees; the default and one additional seed achieve
  approximately 15% fewer trees than their matched old worlds. Report saturation
  or exclusions explicitly. Verify settings/preset targets and deterministic
  worker-count/cancellation/cache roundtrip behavior with focused automated tests.
- [ ] Elevation/face histograms and inspected mountain views show sparse trees in
  previously empty suitable higher terrain, a gradual density transition, and
  preserved summit/ridge/opening readability. Check several faces and two seeds;
  provide normal chase and first-person views with visible trees, not snow-only
  framing, plus a short chronological clip through a representative transition.
- [ ] Root seating, tree/mineral non-overlap, spacing, collision proxies and 4 m
  support remain valid. Run affected generation, scenery-integrity, grounding,
  density-LOD and cache suites using the smallest applicable fixtures. Any
  physics/input/session edits require the full physics/runtime suites through
  `./godotw --headless --script ...` under the guard.
- [ ] Fresh 15–30 second ordinary-input traces cover lower forest, the upper
  transition and a mixed stand. Run three independently warmed 4K High comparisons
  under FpsCritical with unchanged rendering settings/camera/weather; keep images
  outside timing. Report FPS, mean/p95/p99, CPU/GPU cost, loading/preparation and
  actual changed populations. Because physical placement changes, state which
  routes/inputs remain comparable and do not call changed endpoints identical.
  Attribute tree-count savings separately from any rendering optimization.
- [ ] Regenerated current fixtures reject old incompatible identities cleanly;
  personal records/preferences and original recordings remain preserved. Update
  owning guides and affected skills, validate the backlog with preserve-dirty,
  record a new development note with input hashes and actual checks, then commit
  and push only owned work. Preserve unresolved evidence during scoped cleanup.

Human acceptance: the user's visual and skiing review of openness, natural species
mixes and upper-tree placement is separately pending, not a worker completion gate.
Automated placement and bounded FPS evidence do not establish human acceptance or
full-descent route coverage.

## Open questions

None

## Completion record

Pending implementation in a later task. No physical map, terrain, tree population,
generator version or trace was changed while authoring this record. The worker
must record actual verification, compatibility effects, retained evidence,
documentation and pushed development identity; record any blocker explicitly.

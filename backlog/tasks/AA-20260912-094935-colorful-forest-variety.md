---
id: "AA-20260912-094935-colorful-forest-variety"
title: "Add colorful forests with distinct tree and leaf types"
status: ready
priority: P2
depends_on: ["AA-20260912-004316-forest-transparency-strength"]
created: "2026-09-12T09:49:35Z"
updated: "2026-09-12T09:51:45Z"
source_thread: "01a09503-6090-7991-bd5c-c3105a5bfd12"
---

# Add colorful forests with distinct tree and leaf types

## Outcome

Make forests visibly more colorful and varied while skiing. The user initially
asked for greater variety of tree kinds, then clarified the priority: "i want
some orange/red/yellow foliage to bring a little bit more of color/variation to
forests because they are all same colored boring green now". Warm foliage should
form recognizable trees and stands among the existing evergreens, with distinct
crown shapes as well as color. The user additionally requested "trees with
diffretne leaf types": leaf structure itself must vary, not only tree silhouettes
or foliage tint.

The earlier tentative preference for a much broader species mix was qualified by
that clarification. This task does not require five new families, redwoods or an
exotic species collection. A focused colorful mix is the intended result.

## Current state and evidence

Read-only inspection on 2026-09-12 at base commit `47a1a3d`, with concurrent
presentation/gameplay edits present; implementation must recheck current source.
No tree rendering or performance measurements were made during authoring.

- [Assets](../../docs/ASSETS.md#trees) and the
  [manifest](../../assets/graphics/trees/manifest.json) describe 24 variants:
  four each spruce, fir, pine, bare winter birch, dead snag and broken crown.
  [build_tree_collection.py](../../scripts/art/build_tree_collection.py) uses
  spruce presets for all three leafy evergreen families; birch uses forked birch
  presets and currently skips foliage. More labels alone will not establish
  visible variety. The purchased `TreeDesigner + 400 trees/TreeDesigner.blend`
  exists locally; suitable additional presets have not yet been audited.
- [ForestPlacement](../../scripts/presentation/forest_placement.gd) selects a
  dominant spruce/fir/pine family per 256 m region, adds occasional family mixing,
  selects a birch/snag/broken family for roughly one in seven hashed positions,
  and chooses one of four variants on 48 m cells. Metadata preparation assumes
  six families/four variants and reports a fixed total of 24. This is the packed
  production path; changing a gallery or a fallback alone will not affect it.
- [PackedTrees](../../scripts/world/packed_trees.gd) owns authoritative positions,
  trunk dimensions, candidate IDs and woodland/scattered ecology. Visual family
  selection and seated poses belong to presentation. Preserve that separation.
- [AlpineScenery](../../scripts/world/alpine_scenery.gd) has additional family
  mappings on its other paths, including larch/rowan mapped to birch.
  [AlpineAssets](../../scripts/presentation/alpine_assets.gd) explicitly recognizes
  spruce/fir/pine impostors for foliage grading and visibility assistance.
  [DensityForest](../../scripts/presentation/density_forest.gd) groups each region
  by asset: more asset diversity can increase submissions and residency costs.
- [The rebuild wrapper](../../scripts/art/rebuild_foliage.ps1) currently accepts
  only the twelve living conifers; [the gallery](../../scripts/art/tree_gallery.gd)
  and [collection suite](../../tests/tree_collection_suite.gd) assume six families
  or 24 assets. Update these consumers coherently rather than adding assets which
  production tools cannot rebuild or inspect.
- [GenerationSources](../../scripts/world/generation_sources.gd) already includes
  tree manifests, models, textures and presentation dependencies in scenery
  identity. [SceneryCache](../../scripts/world/scenery_cache.gd) consumes it.
  Verify new dependencies invalidate scenery correctly without changing physical
  mountain identity merely for an art revision.
- No overlapping tree-variety task or selected worker idea was found. The
  [forest transparency task](AA-20260912-004316-forest-transparency-strength.md)
  is a dependency because new leaf and impostor materials must inherit its final
  behavior. [Terrain grass](AA-20260911-193341-terrain-grass.md) is adjacent work,
  not a dependency or part of this task. Coordinate shared shaders/material code.

## Agreed decisions and scope

- Orange, red and yellow foliage is the priority; retain green evergreens and
  existing bare/dead trees. Colorful foliage in snow is an intentional art choice,
  not a seasonal simulation or a requirement for strict winter botany.
- Bounded implementation target: add at least two recognizably distinct leafy
  broadleaf families, with at least three meaningful crown/branch variants per
  family. Aspen/birch-like golden crowns and maple-like spreading red/orange
  crowns are suitable starting directions; exact botanical labels and source
  presets are implementer choices. Reuse or extend existing source where useful,
  but recoloring spruce needles or duplicating meshes does not satisfy this goal.
- Include at least three visibly different foliage structures in the combined
  forest: existing conifer needles, rounded or heart-shaped broad leaves, and
  lobed maple-like leaves. The two added leafy families must use distinct leaf
  shapes, proportions and attachment patterns rather than the same generic leaf
  mesh/texture recolored. Exact species names remain an implementation choice.
- Ensure yellow, orange and red are all visible in the playable forest mix.
  Keep a green backbone with substantial warm-colored pockets; avoid isolated
  token trees, uniform recoloring of the forest or random rainbow confetti.
  Use restrained variation within a crown and coherent neighboring stands.
- Preserve the established lush stylized presentation. Snow rests on suitable
  upper surfaces while allowing leaf color to remain readable; do not bleach
  crowns white or turn the whole material orange, including bark and snow.
- Preserve physical tree count, placement, spacing, trunk collision dimensions,
  terrain support, solver, routes, replay/record eligibility and race identity.
  Fit authored trunk/root geometry to existing proxies and seat trees correctly;
  do not introduce huge trunks or extra collidable trees to showcase species.
- Prioritize the forest encountered while skiing and its distant LODs. Update
  other active render paths for consistency, but a separate off-map landscape
  redesign, species settings UI, seasons and new tree physics are outside scope.
- Use owned/local sources and authored derivatives. No purchase or subscription
  is authorized. Retain source provenance and export hashes, preserve unrelated
  assets/UIDs, and respect the existing $5/month hard LFS budget.

## Implementation approach

1. Inspect suitable local TreeDesigner presets with a bounded guarded probe.
   Build a small pilot showing two clearly different broadleaf silhouettes and
   the three requested warm color groups under production lighting. Use leaf
   geometry/textures appropriate to broadleaf forms, with useful LOD reduction;
   evaluate opaque/cutout cost and choose the measured practical implementation.
   Show leaf-level close-ups with production materials at comparable scale to
   verify needle, rounded/heart-shaped and lobed forms before expanding variants.
2. Extend the collection manifest and existing builder/packing/import workflow.
   Represent foliage capability and palette explicitly where family-name checks
   would otherwise omit new assets. Update rebuild selection, gallery navigation,
   progress totals, material registration and meaningful collection assertions;
   remove replaced hard-coded assumptions within scope.
3. Integrate deterministic visual family/palette selection into ForestPlacement.
   Use stable seed/candidate/position data and spatially coherent patches, with
   blended boundaries and existing ecology/elevation cues where useful. Retain
   natural local mixing without assigning every variant to every small region.
   Keep physical packed data untouched and bound batches, texture residency and
   preparation work. Verify uncached, restored and streamed forests agree.
4. Carry distinct crown silhouettes and palettes through near/mid geometry,
   directional far impostors, shadows, snow masks, weather lighting, branch wind
   and cosmetic contact response. New leaves must receive forest visibility
   assistance while woody geometry remains readable. Verify all quality tiers
   retain the palette identity, including lower texture tiers.
5. Update Assets with the actual collection and rebuild commands; update
   Rendering only for changed rendering contracts. Store detailed visual and
   timing evidence under a task-owned `artifacts/colorful_forest_variety/` folder.
   Follow the [incremental engine strategy](../../docs/ARCHITECTURE.md#engine-strategy)
   and [artifact lifecycle](../../docs/DEVELOPMENT.md#artifact-lifecycle).

## Acceptance and verification

All checks below are planned for implementation, not already passed.

- [ ] At least two additional leafy crown families and three variants each are
  rebuildable, imported, referenced by production and visually distinguishable
  beyond a change of tint or uniform scale. Gallery views show leaf, bark and
  snow separation and retain the existing collection.
- [ ] Comparable native close-ups demonstrate at least three distinct foliage
  structures across the forest, including two new broadleaf types. Rounded or
  heart-shaped leaves and lobed leaves remain recognizable in shape without
  relying on their color. Mid/far views retain their characteristic crown texture
  and silhouette; individual distant leaves need not remain separately resolved.
- [ ] Fixed before/after skiing views on seed 849205174 / current Standard show
  clearly visible yellow, orange and red foliage among green evergreens in
  representative woodland, forest-edge and scattered-tree locations. Record
  exact positions/camera/settings and family/palette counts. A second seed checks
  that color distribution is not a hand-authored showcase exception.
- [ ] Native moving review crosses patch boundaries and near/mid/far transitions;
  crowns retain color and silhouette without obvious popping, floating roots,
  clipped bounds, excessive leaf shimmer or severe snow masking. Review normal
  daylight and overcast/snowfall, plus foliage-aid strength 0/50/100. Inspect the
  actual trees on the mountain as well as normalized gallery comparisons.
- [ ] Deterministic assignment, complete asset references, new material receiver
  registration, scenery-cache invalidation/roundtrip and unchanged physical
  tree/terrain checksums have focused coverage. Repeated load and residency
  changes retain the same visual assignment. Run applicable collection, density
  LOD, forest preparation, grounding and foliage sight suites serially:

  ```powershell
  ./scripts/run_guarded.ps1 -FilePath ./godotw.ps1 -Arguments @('--headless','--script','tests/tree_collection_suite.gd') -Label colorful-trees-collection
  ./scripts/run_guarded.ps1 -FilePath ./godotw.ps1 -Arguments @('--headless','--script','tests/density_lod_suite.gd') -Label colorful-trees-lod
  ./scripts/run_guarded.ps1 -FilePath ./godotw.ps1 -Arguments @('--headless','--script','tests/forest_preparation_suite.gd') -Label colorful-trees-preparation
  ./scripts/run_guarded.ps1 -FilePath ./godotw.ps1 -Arguments @('--headless','--script','tests/tree_grounding_suite.gd') -Label colorful-trees-grounding
  ./scripts/run_guarded.ps1 -FilePath ./godotw.ps1 -Arguments @('--headless','--script','tests/foliage_sight_suite.gd') -Label colorful-trees-sight
  ```

  Wait for the shared guard; do not nest guards. Adapt affected existing tests
  to verify the new contract. If physics/input/session code changes become
  necessary, run the mandatory physics and runtime suites through `./godotw`
  under the guard and explain why those edits are in scope.
- [ ] Measure three independently warmed before/after repetitions of matching
  15–30 second dense mixed-forest scenarios, following
  [bounded descents](../../docs/VALIDATION.md#bounded-test-descents). Reuse the
  production benchmark with an identity-valid bounded trace and explicit
  `-TrialSeconds`, `-TrialStartSeconds` and `-Repetitions 3`; wrap it in the guard
  according to its current ownership. Separate loading/warm-up and still capture
  from timing. Keep physical world, camera, weather, settings and background
  workloads matched; record changed art/scenery identities. Report rendered FPS,
  p95/p99, CPU/GPU cost, batches, texture/VRAM use and preparation/time-to-ski.
  Do not offset regressions by reducing forest count or maximum visibility.
  Investigate repeatable regressions beyond run noise and meet the maintained
  rendering budgets or record a concrete blocker. Existing baseline misses stay
  explicit; bounded results are not full-descent performance acceptance.
- [ ] Update the owning guides, validate the backlog, commit/push only owned
  source/assets/docs and record hashes and actual verification. Clean only this
  task's unneeded artifacts after delivery; retain evidence awaiting review.

Human acceptance: the user's visual/skiing review of color balance, repetition
and readability is separately pending acceptance, not a worker completion gate.
Present representative mountain views and a short moving clip; do not claim
that automated tests or agent inspection prove the user likes the forest.

## Open questions

None

## Completion record

Pending implementation. Record shipped family/palette coverage, verification
actually performed, remaining human acceptance, performance findings, updated
guides and commit/push references. If blocked, record the exact blocker and
unfinished work. Link separately proposed ideas only if any were written; they
remain non-executable until selected by the user.

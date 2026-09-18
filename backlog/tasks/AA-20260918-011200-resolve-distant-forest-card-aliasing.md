---
id: "AA-20260918-011200-resolve-distant-forest-card-aliasing"
title: "Stop distant forest cards reading as shimmering pepper noise"
status: ready
priority: P1
depends_on: []
created: "2026-09-18T01:12:00Z"
updated: "2026-09-18T01:12:00Z"
source_thread: null
---

# Stop distant forest cards reading as shimmering pepper noise

## Outcome

Distant forest should read as continuous stands of trees against snow rather than
thousands of isolated dark specks. Today the far bands are the most conspicuous
defect in any wide shot: individual impostor cards fall below one pixel and
scatter into high-frequency dots that also crawl under camera motion. The player
should see coherent tree cover whose tone settles with distance, with no per-card
twinkling while skiing.

## Current state and evidence

Read-only inspection and bounded rendered macOS probes on 2026-09-18 at `main` `7c2d049`. Probe captures used `scripts/mac_frame_probe.sh` with the deterministic `--probe-hold`/`--probe-at-tick` options; the Standard fixture (seed 849205174) was rebaked because the local cache was `mountain_cache_v15` against current `mountain_cache_v17`. macOS frame times are not the performance target in [Rendering](../../docs/RENDERING.md#performance-policy); they indicate direction only.

- The defect is visible across the far ridges and the upper massif in
  `artifacts/snow_wind_drift/frame_before.png` and `artifacts/mac_probe/det_off.png`,
  both captured at recommended High.
- [`forest_placement.gd`](../../scripts/presentation/forest_placement.gd) owns the
  384 m distant-card partition and
  [`pc_tree_impostor.gdshader`](../../assets/graphics/pc_tree_impostor.gdshader)
  draws the cards. Foliage cutouts use one explicit `discard` at their alpha
  threshold, recorded in
  [Rendering](../../docs/RENDERING.md#terrain-forests-and-lighting), so a
  sub-pixel card is either fully drawn or fully gone: there is no coverage
  falloff and nothing converges as the pixel footprint grows.
- Tree draw distance is 1,300 m at preset 7 and 2,000 m at preset 10
  ([`graphics_presets.gd`](../../scripts/presentation/graphics_presets.gd),
  `tree_far_m`), so a wide distance band is drawn entirely with sub-pixel cards.
- This is an appearance defect, distinct from
  [grouped distant stands](../blocked/AA-20260914-094136-render-distant-forest-stands.md),
  which is blocked on a performance-motivated grouped representation whose
  candidates broke canopy silhouettes, and from
  [shared far-tree materials](../completed/AA-20260917-222200-share-far-tree-material-submissions.md),
  a frozen render-CPU prototype that is not installed. Read both first: their
  rejected representations must not be re-proposed unchanged.
- The defect is worse in low light. `artifacts/mac_probe/look_dusk.png` and
  `look_night.png`, captured at `a94b93b`, show the far bands as high-contrast
  dark specks against pale snow, with more of the mountain affected than at noon.
  Include a dusk or night condition in the reproduction.
- A snowy winter forest with reversible seasonal selection landed upstream at
  `c6aa92c` after this evidence was gathered, adding
  [`forest_appearance.gd`](../../scripts/presentation/forest_appearance.gd) and a
  second authored tree family. Both seasonal appearances must be reproduced and
  accepted; the evidence above describes the autumn family only.
- Hypothesis, not established: alpha-to-coverage, or a footprint-driven fade of
  each card toward a stand-average tone, will converge correctly. The same
  pixel-footprint approach visibly stabilised snow surface detail in this session.

## Agreed decisions and scope

- Appearance is the outcome. A frame-time improvement is welcome but a candidate
  that fixes cost and keeps the shimmer fails.
- Preserve every physical tree population, the existing distance bands, canopy
  silhouettes and the foliage-sight canopy aid. Do not thin or remove trees to
  reduce aliasing, and do not shorten `tree_far_m` as the fix.
- Presentation only: no placement, collision, generation or cache changes.
- Keep the single `discard` cutout contract unless a replacement is measured;
  wood carries the LOD dither, so the null-fragment depth pre-pass stays closed.
- Out of scope: near and mid tree geometry, forest colour grading, forest
  generation and the blocked grouped-stand representation.

## Implementation approach

1. Reproduce first. Capture matched stills and a moving-camera sequence of a far
   forest band at presets 7 and 10, native and with production upscaling, so the
   crawling is visible and attributable. Temporal reconstruction can both hide
   and amplify this; record which path produced each capture.
2. Establish where cards cross one pixel by deriving the card's projected
   footprint in the impostor shader, and confirm it against the captures before
   changing any look.
3. Try convergent candidates before any new representation: fade each card's
   coverage toward its own mean canopy tone as the footprint approaches its
   width, and separately evaluate alpha-to-coverage for the far band only. Both
   must leave the near and mid bands visually unchanged.
4. Reject visually before timing, per the
   [experiment budget](../../docs/VALIDATION.md#reusable-baselines-and-experiment-budget).
   Only then measure. A candidate that removes the shimmer at a small cost is
   acceptable under the user's stated tolerance for good visuals.

## Acceptance and verification

- [ ] Matched far-band stills and a moving-camera sequence show continuous stands
  with no isolated twinkling specks, at presets 7 and 10, native and production
  upscaling, in clear and overcast light.
- [ ] Near and mid forest bands, canopy silhouettes, the LOD cross-fade handover
  and the foliage-sight aid are visually unchanged; verify the handover distance
  explicitly rather than only the far band.
- [ ] Run `tests/colorful_forest_suite.gd` and the producers in
  [Validation](../../docs/VALIDATION.md#forest-batch-submission). Record the six
  known pre-existing LOD1 material-identity failures separately from any new one.
- [ ] Bounded warmed before/after frame and GPU comparison on a dense-forest
  route, with the measured noise floor stated. Do not claim a performance gain
  from reduced draw calls alone.
- [ ] Update [Rendering](../../docs/RENDERING.md#terrain-forests-and-lighting),
  validate the backlog and push owned changes with evidence retained.

Human acceptance: the user's judgement of how distant forest should read is a
completion gate; worker rendered inspection does not substitute for it.

## Open questions

None.

## Completion record

Pending implementation.

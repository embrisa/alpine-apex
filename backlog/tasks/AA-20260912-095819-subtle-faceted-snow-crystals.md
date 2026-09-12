---
id: "AA-20260912-095819-subtle-faceted-snow-crystals"
title: "Replace large white ground-snow dots with subtle faceted sparkles"
status: ready
priority: P2
depends_on: []
created: "2026-09-12T09:58:19Z"
updated: "2026-09-12T09:58:19Z"
source_thread: null
---

# Replace large white ground-snow dots with subtle faceted sparkles

## Outcome

Remove the conspicuous big white circular crystal highlights on ground snow,
leaving small, subtle faceted sparkles and the soft, luminous, textured snow.
The user asked whether crystals could look more like snowflakes without costing
performance, then selected: "Small, subtle faceted sparkles with the big white
dots removed (recommended)". Recognizable six-point flakes are not required.

## Current state and evidence

Read-only inspection on 2026-09-12 at HEAD
`31aef5ceb5c9c536877394a7f18d9f275c2aa73e`, with concurrent uncommitted work:

- [Crystal sampling](../../assets/graphics/snow_crystals.gdshaderinc) constructs
  a circular grain using `length(delta)` and `smoothstep`. Two layers use
  scale/radius 24/.045 and 8/.085, with footprint widening/filtering and fades
  at 10-32 m and 20-60 m. This confirms circular masks, not the visual root cause.
- [Shared lighting](../../assets/cloud_light.gdshaderinc) adds directional
  facet highlights with exponents 64/48 and a .70 large-layer multiplier;
  sheen is a separate broad contribution. Large-layer coverage/intensity and
  bloom expansion are hypotheses for the reported blobs, requiring isolation.
- Receivers include [terrain](../../assets/graphics/alpine_surface_fragment.gdshaderinc),
  [powder caps](../../assets/graphics/powder_cap.gdshader),
  [tracks](../../assets/graphics/ski_track.gdshader) and the current local-powder
  shader path. [Quality](../../scripts/presentation/graphics_quality.gd) owns
  crystal strength/density and material application.
- [Soft-snow captures](../../tests/soft_snow_playtest.gd) and
  [layer isolation](../../tests/snow_dreamlike_material_playtest.gd) provide
  harness patterns. Their historical snapshots/interfaces are not a current
  baseline or proof they still run unchanged.
- No duplicate crystal task was found in tasks, archives or ideas.
  [Distant snow](AA-20260911-230603-scenery-snow-material.md) and
  [local snow boundary](AA-20260912-005323-subtle-local-snow-boundary.md) have
  different outcomes. Coordinate shared receiver edits, preserving worker-owned
  and concurrent changes; neither is a functional prerequisite.

No visual reproduction or timing was performed during authoring. Follow
[Rendering](../../docs/RENDERING.md#snow-presentation) and
[Validation](../../docs/VALIDATION.md#bounded-test-descents).

## Agreed decisions and scope

- Prioritize eliminating large white dots while retaining small faceted sparkle.
  Preserve soft sheen, recognizable texture, terrain readability and variation;
  do not solve this by disabling all sparkle or globally flattening exposure/glow.
- Require no measurable performance regression. A shape change is optional if
  size/coverage/intensity tuning achieves the selected look more cheaply. Do not
  promise literally zero shader cost without measurements.
- Presentation only. Preserve world locking, projected-footprint filtering,
  distance fade, sun/view response, cloud/shadow attenuation and night suppression.
  Keep exposed rock free of snow-crystal highlights.
- No added particles, geometry, draw passes, texture assets or settings UI for
  this fix. Retain existing quality controls, including sparkle off. Preserve
  the 120 Hz solver, 4 m terrain, generation, replay and contact behavior.
- Airborne weather snowflakes and unrelated material/lighting redesign are out
  of scope. Human visual acceptance is a separate follow-up, not a completion gate.

## Implementation approach

1. Freeze a current shader/quality baseline without reverting concurrent work.
   Reproduce close ground blobs from chase and first-person views in direct sun.
   Isolate fine/large crystal contributions and glow to establish the cause.
2. Reduce excessive large-grain coverage, footprint expansion and/or highlight
   energy at their owner. If useful, replace the radial mask with a compact
   faceted mask using simple arithmetic and existing stable per-cell data.
   Avoid extra noise layers, neighbor searches or decorative snowflake branches.
   Do not enlarge subpixel grains merely to keep their shape visible.
3. Preserve smooth antialiasing/fades and inspect moving highlights after temporal
   reconstruction. Reuse the shared sampler across affected receivers; remove
   replaced code within scope rather than retaining a second production path.
4. Compare the cheaper size/intensity candidate with any faceted-mask candidate.
   Ship only a visually acceptable candidate within baseline timing variability.
   If none meets both requirements, record the blocker rather than silently
   accepting extra cost or removing the snow's sparkle entirely.

## Acceptance and verification

- [ ] Matched native DX12 stills and chronological motion show small, restrained
  sparkles with no conspicuous white circular blobs, stamped large flakes,
  crawling grid, hard fade edges or new shimmer. Include near-ground, normal
  chase/first-person and oblique sun views, tracks, powder and caps.
- [ ] Confirm clear sun, low sun, overcast/shadow and night behavior. Isolate
  crystal and sheen contributions; night retains zero artistic crystal emission.
  Check current quality presets, sparkle off, native AA and production upscaling.
- [ ] Build a focused current-baseline visual harness, adapting the references
  above, and run it through `./scripts/run_guarded.ps1 -FilePath ./godotw.ps1
  -Arguments @('--script','tests/snow_crystal_shape_playtest.gd')
  -Label snow-crystal-shape -TimeoutSeconds 300` if using that new filename.
  Record the actual command and source/settings hashes in
  `artifacts/snow_crystal_shape/`. Engine errors fail verification.
- [ ] Run `./scripts/test_pc_environment.ps1 -Suites
  graphics_suite,pc_graphics_suite,graphics_override_suite` if quality propagation
  changes. It owns its guard; do not nest guards. Shader compilation and rendered
  inspection are required regardless of whether quality code changes.
- [ ] Measure three independently warmed before/after repetitions of identical
  15-30 second ordinary-input snow scenarios, including close bright ground.
  Use the current validated mountain/trace, 4K High, Auto 75%, FG off, GI off,
  uncapped, capture-free timing. Use `scripts/benchmark_pc.ps1` with explicit
  `-TrialSeconds 15 -TrialStartSeconds 90 -Repetitions 3 -FrameCap 0
  -ProfileFrameCosts -FrameGeneration off -TerrainGI off` under the guard,
  selecting another recorded start if needed to cover visible crystals.
  Record median GPU/frame time, p95/p99, rendered FPS and baseline run variability.
  Investigate any repeatable increase beyond that variability; it fails the
  performance requirement. If measurements cannot resolve the difference, report
  that limit rather than claiming zero cost. These are bounded scenario results,
  not full-descent or human acceptance.
- [ ] Tests use isolated preferences and unranked runs, never personal bests.
  Wait for `artifacts/validation.lock`; preserve concurrent engine workloads.
- [ ] Update the owning Rendering guide, validate backlog, commit/push owned
  changes and retain necessary comparison evidence using the artifact lifecycle.

Human acceptance: the user's preferred sparkle appearance remains pending visual
follow-up. Worker-rendered inspection and performance evidence are completion
requirements and must be reported separately from user acceptance.

## Open questions

None.

## Completion record

Pending implementation. Record cause, chosen change, actual checks and timings,
remaining acceptance, documentation, evidence and commit/push references. If
blocked, record the unmet visual/performance requirement and remaining work.
Link any separate ideas or state that none were proposed.

---
id: "AA-20260912-095819-subtle-faceted-snow-crystals"
title: "Replace large white ground-snow dots with subtle faceted sparkles"
status: done
priority: P2
depends_on: []
created: "2026-09-12T09:58:19Z"
updated: "2026-09-12T10:26:05Z"
source_thread: "01a0950b-ae88-7393-82d7-39f1378dfb40"
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
  [Distant snow](../blocked/AA-20260911-230603-scenery-snow-material.md) and
  [local snow boundary](../blocked/AA-20260912-005323-subtle-local-snow-boundary.md) have
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

- [x] Matched native DX12 stills and chronological motion show small, restrained
  sparkles with no conspicuous white circular blobs, stamped large flakes,
  crawling grid, hard fade edges or new shimmer. Include near-ground, normal
  chase/first-person and oblique sun views, tracks, powder and caps.
- [x] Confirm clear sun, low sun, overcast/shadow and night behavior. Isolate
  crystal and sheen contributions; night retains zero artistic crystal emission.
  Check current quality presets, sparkle off, native AA and production upscaling.
- [x] Build a focused current-baseline visual harness, adapting the references
  above, and run it through `./scripts/run_guarded.ps1 -FilePath ./godotw.ps1
  -Arguments @('--script','tests/snow_crystal_shape_playtest.gd')
  -Label snow-crystal-shape -TimeoutSeconds 300` if using that new filename.
  Record the actual command and source/settings hashes in
  `artifacts/snow_crystal_shape/`. Engine errors fail verification.
- [x] Run `./scripts/test_pc_environment.ps1 -Suites
  graphics_suite,pc_graphics_suite,graphics_override_suite` if quality propagation
  changes. It owns its guard; do not nest guards. Shader compilation and rendered
  inspection are required regardless of whether quality code changes.
- [x] Measure three independently warmed before/after repetitions of identical
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
- [x] Tests use isolated preferences and unranked runs, never personal bests.
  Wait for `artifacts/validation.lock`; preserve concurrent engine workloads.
- [x] Update the owning Rendering guide, validate backlog, commit/push owned
  changes and retain necessary comparison evidence using the artifact lifecycle.

Human acceptance: the user's preferred sparkle appearance remains pending visual
follow-up. Worker-rendered inspection and performance evidence are completion
requirements and must be reported separately from user acceptance.

## Open questions

None.

## Completion record

Implemented manually at the user's request; no scheduled claim was taken.
Production sampler and reproducible fixtures committed/pushed to `main` as
`400501e` (2026-09-12). The coarse circular layer reproduced the large white
discs. Adopted compact hexagonal masks, radius-bounded footprint widening,
coarse radius .040 instead of .085 and .70 coarse coverage. Broad sheen,
world locking, filtering/light gates and existing quality routing are retained.

Actual verification:

- 35 native DX12 4K captures, including layer/glow isolation, distance, light,
  quality, upscaling and rider views; no errors/source drift. Night crystal
  on/off is byte-identical. Fixed ground-crop largest bright patch 2,091 to
  394 pixels (81% smaller), with 450 separated highlights remaining.
- Four 4-second motion clips (480 frames, captured at 1080p from 4K rendering),
  matched before/after chase and first-person trajectories, no crashes/errors.
  Human appearance/controller acceptance remains separately pending.
- Three valid pairs of independently warmed 1,800-tick ordinary-input trials
  (15 simulated seconds each), 4K High Auto/75%, FG/GI off and uncapped.
  Mean GPU medians 7.940 to 7.972 ms (+.032 ms, .41%); all candidate medians
  lie within baseline variation. First two pairs improve, third is slower
  with CPU/frame-tail variation too: no consistent regression, no claim of
  exact zero cost or improved FPS. Full-descent acceptance is not established.
- One original pair was discarded because a minimized window returned stale
  renderer timings; the replacement pair confirmed 1,800 rendered frames and
  1,799 fresh query updates in each trial. Added explicit minimization/frame/
  query checks. Production source hashes and all accepted trajectories match.
- Quality propagation did not change, so conditional graphics-setting suites
  were unnecessary; the live preset renders and native shader checks ran.
  Physics/input/session code was untouched by this task. Isolated preferences
  and unranked sessions verified throughout.

Detailed scope, exact commands, distributions, excluded-data rationale and
retention decision: `artifacts/snow_crystal_shape/RESULTS.md`, `summary.json`,
`visual/report.json`, `motion/report.json`, `timing/report.json`,
`timing/INVALIDATED_LAST_PAIR.md` and `timing_repeat/report.json`; corresponding
guard labels are `snow-crystal-visual`, `snow-crystal-timing-motion` and
`snow-crystal-timing-repeat`. `tests/report_snow_crystal_shape.py` regenerates
the summary/comparison with NumPy and Pillow and excludes the invalid pair.

The owning Rendering paragraph was inserted by the concurrent eight-task
coordinator (`01a094f2-3331-7720-8ff9-622d3be54920`) for its explicitly staged
documentation milestone; this task did not stage that task's unrelated guide
edits. Review evidence and the documentation handoff note are retained until
the active user review/integration is complete; no broad artifact cleanup.
No separate next-step ideas were proposed.

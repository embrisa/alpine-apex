---
id: "AA-20260911-230603-scenery-snow-material"
title: "Restore snow detail and shape contrast in distant scenery"
status: blocked
priority: P2
depends_on: []
created: "2026-09-11T23:06:03Z"
updated: "2026-09-13T21:02:19Z"
source_thread: "01a092b4-c1a2-7d50-a577-a5e08a7f15d8"
---

# Restore snow detail and shape contrast in distant scenery

## Outcome

Make snowy scenery slopes and mountains read as shaped snow, consistent with
the playable mountain, while preserving responsive skiing. The user finds them
detail/shadowless and approved a material improvement followed by a separate
landscape-shadow task. They require: "if they have large performance impact it
should definitely be some sort of setting."

## Current state and evidence

Source inspection at `9f687775e53c229ffb858f1dcbdcb0f57313ae10` found:

- [Scenery shader](../../assets/graphics/alpine_wilderness.gdshader) disables
  shadows/specular and uses mesh normals and fully rough diffuse lighting.
- [Shared off-map material](../../assets/graphics/offmap_surface.gdshaderinc)
  blends mostly white snow with a filtered albedo texture. `offmap_detail`
  affects rock, not snow. Wrapped snow lighting reduces face contrast.
- [Playable snow](../../assets/graphics/alpine_surface_fragment.gdshaderinc)
  additionally has broad deposits/drifts, normal detail, hollow tint and sheen.
  Its apron branch blends away those features into the off-map material.
- [Wilderness recipe](../../scripts/authoring/wilderness_recipe.gd) stores a
  hollow-derived value in mask alpha; off-map snow currently does not use it.
- [Atmosphere](../../scripts/world/wilderness_atmosphere.gd) applies uniform
  cloud dimming, while extra valley haze further reduces distance contrast.

These are code findings, not measured visual improvements or performance claims.
Follow [Rendering](../../docs/RENDERING.md),
[World](../../docs/WORLD.md) and [Validation](../../docs/VALIDATION.md).
No duplicate snow-scenery task was found in active/archive tasks or ideas.
The [weather upgrade](AA-20260911-160307-weather-upgrade-storm-races.md) owns
weather behavior; consume its current interface without depending on its delivery.

## Agreed decisions and scope

- Improve broad snow variation, subtle lighting-normal detail and hollow cues;
  reduce excessive wrapped-light fill while retaining bright alpine snow.
- Keep the playable boundary and distant apron visually continuous. Preserve
  the exact connector collar, terrain silhouette, props and physical data.
- Presentation only: no solver, 4 m support, replay, race, placement or weather
  behavior changes. Large-scale ridge shadows belong to
  [the dependent task](AA-20260911-230604-scenery-mountain-shadows.md).
- Preserve a cheap mode. Any costly extra detail must be independently reducible
  or disabled through saved graphics settings, without reducing scenery coverage
  or playable snow quality. Use the existing settings/preset system, not a new UI.
- Conservative implementation trigger: a repeatable increase of at least 0.5 ms
  median GPU time or 5% in frame p95/p99 versus the matched cheap mode requires
  an exposed quality/off control. Smaller but material startup/memory costs also
  require a cheaper choice. These are engineering gates, not measured results.
  Do not enable a costly mode by default on recommended High; select defaults
  from measurements and record the decision. Baseline tail targets already fail.

## Implementation approach

Keep `offmap_surface.gdshaderinc` as the shared distant material owner for ridges
and apron. Add world-locked broad drift/deposit variation and filtered normal
variation at scales visible from skiing cameras; fade fine detail by projected
size/distance to avoid shimmer. Reuse the authored hollow mask conservatively,
checking its scale and baked tiers rather than treating it as the playable 4 m
readability map. Shade hollows without painting dark dirt or bright ridge outlines.
Keep directional response consistent as daylight changes; never bake noon light
into albedo. Preserve atmospheric depth instead of globally removing fog.

Route quality through [graphics presets](../../scripts/presentation/graphics_presets.gd),
[effective quality](../../scripts/presentation/graphics_quality.gd) and
[saved overrides](../../scripts/presentation/pc_graphics_settings.gd).
Apply changes to both existing and newly created/replaced scenery, including
same-tier overrides, reset and reload. Cheap mode must skip expensive work.
No per-frame terrain analysis or physical regeneration on setting changes.

## Acceptance and verification

- [x] Matched before/after summit views across all six faces and riding/apron
  views show clearer snowy ridges/hollows without dirty patches, tiling, seams,
  faceting amplification or shimmer. Inspect chronological movement plus clear
  midday, low sun, overcast/snowfall and night. Hold camera/weather/exposure fixed.
- [x] Capture a new frozen current-production baseline; the old v2 comparison in
  `tests/offmap_v3_playtest.gd` is a harness reference, not this task's baseline.
  Record exact new capture commands and hashes under `artifacts/scenery_snow/`.
- [x] Native DX12 compilation/rendering passes. Extend relevant setting and
  boundary checks, then run `./scripts/test_pc_environment.ps1 -Suites
  graphics_suite,pc_graphics_suite,graphics_override_suite,offmap_geometry_suite,offmap_atmosphere_suite,offmap_lifecycle_suite`
  as one command. This wrapper owns the shared guard; do not nest it.
- [x] Verify cheap/enhanced modes, presets, saved overrides, reset, live changes
  and replacement scenery. No personal preferences/records change during tests.
- [ ] Separately benchmark baseline/cheap/enhanced at 4K, High, Auto 75%, FG off,
  GI off on the current validated v15 Standard fixture and complete ordinary-input
  descent, with at least three repetitions and identical source/engine/route.
  Use `scripts/benchmark_pc.ps1` and the performance method in Validation;
  add explicit mode selection to the harness if needed. Capture-free timing must
  include frame/GPU median and p95/p99, rendered FPS, memory and startup costs.
  Never infer improvement from capped FPS or generated frames. Required controls
  and conservative defaults satisfy the cost gate above.
- [x] Update only the owning Rendering guide with adopted behavior/settings and
  link detailed evidence. Validate backlog, commit and push owned work.

Human acceptance: user's scenery preference and skiing comfort remain separately
pending follow-up, not a worker-completion gate. Worker-rendered inspection and
performance evidence are required; do not claim human acceptance.

## Open questions

None.

## Completion record

Functional milestone validated in development note
`changes/c6127dac08f24db78695d64e6ee0c56e.json`. The task remains **blocked only on
the later performance gate**. The user explicitly deferred all
comparative 4K FPS, frame-tail, GPU and startup benchmarks; that later gate is
still required for full task acceptance. The control is exposed now, with every
preset including recommended High kept cheap until measurements.

Implementation: shared ridge/apron hollow tint and reduced wrapped-light fill;
opt-in world-locked deposits and filtered lighting-normal variation; continuous
apron normal/diffuse blend; saved independent Scenery override, same-tier live
application and replacement initialization. No terrain/physics, generator, race,
weather or scenery coverage changes are owned by this milestone.

Evidence, commands, source/capture hashes and current verification outcomes:
`artifacts/scenery_snow/REPORT.md`. Owning behavior is in Rendering / Background.
The frozen baseline is production material at `742fcb326210240a180a145d6cf93d41deeb2993`,
not the old v2 geometry comparison. Same-scene baseline/cheap/enhanced comparisons
hold geometry, camera, time/weather and exposure fixed.

Later performance gate (not run or inferred here): baseline/cheap/enhanced at
3840x2160, High, Auto 75%, frame generation off, GI off, current validated v15
Standard, identical ordinary-input complete descent, source and engine, at least
three repetitions each through `scripts/benchmark_pc.ps1`. Keep timing capture-free;
record rendered FPS, frame and GPU medians/p95/p99, memory and startup costs.
Wire explicit mode selection into that benchmark harness (PCGraphicsSettings now
accepts `--offmap-snow-detail=on|off`); use the frozen production material baseline
with identical current geometry. Evaluate +0.5 ms median GPU or +5% frame p95/p99
versus cheap, plus material startup/memory costs, then decide defaults. Existing
failing tail targets remain unresolved. No separate new task was proposed.

Functional verification: native DX12 matrix passed at 1920x1080 High, Auto 75%,
FG/GI off and an actual 30 FPS cap. Reviewed 58 baseline/cheap/enhanced triplets
(174 stills): all six summit faces, two paused riding-camera positions and three
apron bearings across clear midday, dusk, overcast, snowfall and night, plus all
three baked tiers. Chronological camera samples support restrained, stable detail;
paused riding poses are not simulated/ordinary-input descent evidence and their
framing emphasizes foreground snow. No human/controller acceptance is claimed.

The required single-command six-suite batch passed **221 checks** (28 graphics,
16 PC graphics, 104 overrides, 25 geometry, 10 atmosphere, 38 lifecycle), with
`stable_build_sources=true`. Guarded static shader include/Python checks, explicit
test-map admission, owned whitespace and backlog validation also passed. Native
capture used Exclusive admission for the source-keyed scenery cache refresh;
ordinary regression/static checks used Shared. Existing player-only deformation
allocation assertions in the affected override suite were corrected to the current
aggregate ghost allocation; runtime deformation behavior was not changed.

Human scenery preference and skiing comfort remain pending, separately from
worker-rendered inspection. Rendering owns the adopted contract; the development
note and retained report identify verification inputs and delivery scope.

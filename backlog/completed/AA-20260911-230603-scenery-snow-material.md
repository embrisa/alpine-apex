---
id: "AA-20260911-230603-scenery-snow-material"
title: "Restore snow detail and shape contrast in distant scenery"
status: done
priority: P2
depends_on: []
created: "2026-09-11T23:06:03Z"
updated: "2026-09-17T13:14:45+00:00"
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
The [weather upgrade](../abandoned/AA-20260911-160307-weather-upgrade-storm-races.md) owns
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
  Record versions, paths, settings and commands; current policy skips hash audits.
- [x] Native DX12 compilation/rendering passes. Extend relevant setting and
  boundary checks, then run `./scripts/test_pc_environment.ps1 -Suites
  graphics_suite,pc_graphics_suite,graphics_override_suite,offmap_geometry_suite,offmap_atmosphere_suite,offmap_lifecycle_suite`
  as one command. This wrapper owns the shared guard; do not nest it.
- [x] Verify cheap/enhanced modes, presets, saved overrides, reset, live changes
  and replacement scenery. No personal preferences/records change during tests.
- [x] Current economical acceptance: one 15-second warmed original/cheap/enhanced
  comparison on a visually qualified world17 Standard open route, 4K High,
  Auto75%, FG/GI off. First complete route traversal excluded. Capture-free native
  timing records actual frame/GPU distributions and FPS, shared startup and
  allocation telemetry. The current bounded policy supersedes the former v15
  full-descent/three-repetition/hash-audit recipe. All presets remain cheap.
- [x] Update only the owning Rendering guide with adopted behavior/settings and
  link detailed evidence. Validate backlog, commit and push owned work.

Human acceptance: user's scenery preference and skiing comfort remain separately
pending follow-up, not a worker-completion gate. Worker-rendered inspection and
performance evidence are required; do not claim human acceptance.

## Open questions

None.

## Completion record

Functional material milestone: `e14f9ef4`, note
`changes/c6127dac08f24db78695d64e6ee0c56e.json`. Shared ridge/apron hollow tint,
reduced wrap fill and optional filtered world-locked deposits/normal variation
were implemented with a saved independent Scenery override. Historical native
review covered 58 three-mode triplets, all six faces, riding/apron, five lighting
conditions and three baked tiers plus chronological movement;221 functional
checks passed. The original bulky captures were retired. The material sources
remain unchanged; no new production shader, terrain, density or physics change
is part of this cost milestone.

Cost gate completed 17 September 2026, note
`changes/c993558af368434d9b2e2a39a57b2073.json`. Current seven view groups were
inspected separately from timing; native DX12 comparison and 152 focused settings,
atmosphere and lifecycle checks passed. The initial lower route was rejected for
cost coverage because its trees hide the distant scenery. The final open route
covers 275.33 m from approximately 3868 to 3690 m altitude using ordinary controls,
with identical trajectory in every material arm. This is not dense-forest or
whole-descent performance acceptance.

| Material | Average FPS | Mean frame ms | GPU median ms | Frame p95 / p99 ms |
|---|---:|---:|---:|---:|
| Original material |147.26|6.7908|5.2770|8.943 /9.947|
| Current cheap |148.71|6.7244|5.2240|8.895 /10.111|
| Enhanced |148.24|6.7459|5.2275|8.884 /10.002|

Enhanced adds an observed 0.0215 ms mean frame and 0.0147 ms mean GPU versus cheap;
median GPU changes 0.0035 ms. Such small single-arm differences are inconclusive,
not a proven gain or fixed penalty. **All ten presets remain cheap; enhancement
stays optional.** The conservative 0.5 ms / 5% trigger is not shown here.

One shared startup: physical cache 3.93 s, scene-ready 56.70 s, both cache hits;
shader preparation 0.74 s outside measurement. Peak engine video allocation was
3585.02MiB original and 3711.02 MiB for both current modes. This is shared-process
allocator telemetry, not physical VRAM or an isolated 126 MiB feature attribution.
Enhanced introduces no new textures/meshes; per-mode cold startup was not isolated.
The optional control and unchanged conservative defaults retain the cheap choice.

Compact current report and complete measurement limits:
`artifacts/scenery_snow_cost/REPORT.md`; raw production distributions:
`artifacts/pc_environment/scenery_snow_cost_20260917/`. Owning behavior remains in
Rendering; reusable comparison commands are in Validation. Snapshot records
Git revision/paths/sizes and retains current cloud includes. No manual hash audit.
Human scenery preference and skiing comfort remain separately pending.

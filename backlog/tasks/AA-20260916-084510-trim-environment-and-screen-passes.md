---
id: "AA-20260916-084510-trim-environment-and-screen-passes"
title: "Measure and trim always-on environment and screen-space passes"
status: ready
priority: P2
depends_on: []
created: "2026-09-16T08:45:10Z"
updated: "2026-09-16T15:10:00Z"
source_thread: null
---

# Measure and trim always-on environment and screen-space passes

## Outcome

Recover GPU time from post-processing and environment features that run every
frame at the recommended High preset, delivering the changes that are
invisible immediately and presenting any visible trade-off to the user with
matched stills before it ships.

## Current state and evidence

- Recorded native pass means in [the GPU task](AA-20260912-105302-reduce-dense-scene-gpu-cost.md):
  glow 0.557 ms, SSIL 0.475, SSAO 0.200, tonemap 0.331, fog 0.085; the
  rendering baseline lists glow 0.43 and SSIL 0.38 ms. The 90-120 FPS target
  needs 31.8-43.1 percent less total frame time.
- Source inspected at Dev 43 / `a9c2acb` (2026-09-16):
  - [`graphics_presets.gd:60-64`](../../scripts/presentation/graphics_presets.gd)
    enables SSAO for id above 1, SSIL and volumetric sun shafts for id 7 and
    above, glow for id above 1. [`alpine_atmosphere.gd:20-33`](../../scripts/presentation/alpine_atmosphere.gd)
    uses additive glow with five non-zero levels of seven and `hdr_scale 1.8`,
    and a 128x128x64 volumetric fog volume with temporal reprojection enabled
    in clear daylight (`shaft_weight = day * clear²`).
    [`alpine_world.gd:187-200`](../../scripts/world/alpine_world.gd) sets SSAO
    radius .65 and SSIL radius 2.0.
  - [`alpine_world.gd:176-180`](../../scripts/world/alpine_world.gd) keeps the
    weather sky in `PROCESS_MODE_REALTIME` although the sky shader cubemap
    branch depends only on slowly changing weather parameters.
  - [`speed_periphery.gdshader:3,27-35`](../../assets/speed_periphery.gdshader)
    is a full-output-resolution `hint_screen_texture` blur with five taps,
    visible whenever speed times strength exceeds .005
    (`main.gd:1023`), so a 4K back-buffer copy per frame at speed.
  - [`snow_tracks.gd:44-52`](../../scripts/presentation/snow_tracks.gd) puts
    up to 6,144 track instances in one MultiMesh whose AABB spans the whole
    trail (never culled); [`ski_track.gdshader`](../../assets/graphics/ski_track.gdshader)
    is `blend_mix, depth_draw_never, cull_disabled` and fades alpha to zero
    beyond 380 m without discarding, so far fragments still shade.
  - `alpine_atmosphere.gd:33` sets the global volumetric fog volume size and
    never restores it when shafts are off (harmless persistence).
  - SDFGI (`alpine_world.gd:202-208`, `sdfgi_min_cell_size 1.0`, four
    cascades) is off by default; when the user enables Terrain GI, cascade 0
    is about 128 m and re-voxelises continuously at 47 m/s.
- Presets and their visible output are a product contract in
  [Rendering](../../docs/RENDERING.md#graphics-and-display); the project
  contract states frame rate precedes graphics, but visible default changes
  still need the user's acceptance.

## Agreed decisions and scope

Own `scripts/presentation/graphics_presets.gd`, `alpine_atmosphere.gd`, the
environment setup in `scripts/world/alpine_world.gd`, `assets/speed_periphery.gdshader`,
the speed periphery setup in `scripts/main.gd`, and the track culling in
`snow_tracks.gd`/`ski_track.gdshader`. Two tiers of change:

- Invisible (deliver directly): sky `PROCESS_MODE_INCREMENTAL` when the
  cubemap does not change per frame, ski-track early `discard` beyond the
  existing 380 m fade and `cull_back` where cards face the camera, periphery
  blur at half resolution or via the existing compositor effect if output is
  indistinguishable, restoring the fog volume size when shafts are disabled,
  and SDFGI cell/cascade settings that only affect the opt-in Terrain GI path.
- Visible (measure, propose, wait for the user): glow level count, SSAO
  quality/half resolution, SSIL as Ultra-only, volumetric shaft volume size or
  default-off in clear weather. Prepare matched 4K stills and per-pass ms for
  each; do not commit a visible default change without the user's decision.

## Implementation approach

1. Use the GPU attribution route to read glow, SSAO, SSIL, fog, sky and
   periphery costs on the dense and open traces at High.
2. Deliver the invisible tier with matched stills proving no change.
3. For the visible tier, produce an options table (pass ms saved, stills at
   4K High, which presets change) and record it in the task for the user;
   implement only what the user selects, as a follow-up milestone.

## Acceptance and verification

- [ ] Invisible-tier changes show identical matched stills and a measured GPU
  reduction or neutral result; retain negatives.
- [ ] `tests/graphics_suite.gd`, `tests/pc_graphics_suite.gd`,
  `tests/graphics_override_suite.gd`, `tests/weather_suite.gd`,
  `tests/scene_motion_blur_suite.gd`, `tests/impact_warning_suite.gd`,
  `tests/render_efficiency_suite.gd` and `tests/runtime_suite.gd` pass.
- [ ] One warmed candidate per route versus the saved baselines with GPU ms
  and frame statistics; the visible-tier options table is complete with
  stills and numbers.
- [ ] Update [Rendering](../../docs/RENDERING.md) for delivered settings;
  commit/push with a development note and Dev ID.

Human acceptance: the visible tier is gated on the user's choice from the
options table; it is not part of worker completion.

## Open questions

None

## Completion record

Partial delivery, 2026-09-16: the user explicitly authorized small visual
tradeoffs for measured FPS gains and autonomous integration. That authorization
covers the SSAO/SSIL default change below; no additional approval is pending.

- Presets 1-7 now default contact shading and screen-space indirect lighting
  off; 8-10 default both on. Individual overrides remain available. Matched
  4K forest and clear/cloudy/rock views passed agent inspection with slightly
  less contact darkening and indirect fill. Geometry, shadows and other budgets
  are unchanged. Both effects already ran half-size at medium quality.
- Their shared normal/roughness prepass prerequisite was the main saving:
  native scene depth **3.098 -> 1.739 ms**; opaque **2.149 -> 2.055 ms**;
  their own passes totalled **0.496 ms**. No isolated LOD1 counter claim.
- Clean free-ski **92.28 -> 113.94 FPS**, **10.837 -> 8.776 ms/frame**, GPU
  **9.588 -> 7.500 ms**. P95/p99 **11.652/14.294 ms**. Saved average reused;
  one warmed candidate, with matched route/camera/population and both caches hit.
- Timed recording **82.72 -> 96.68 FPS** includes the earlier powder reduction
  as well as lighting. All 1,800 ticks and 451 pose samples matched. Startup
  rebuilt scenery before warmup. Current references and limitations are in
  [Performance handoff](../../docs/PERFORMANCE_HANDOFF.md#screen-space-lighting-and-current-references).
- All eight requested suites pass: **842 checks**. Corrected the graphics
  fixture's stale family-name assertion; production selection is unchanged.
  [Rendering](../../docs/RENDERING.md#graphics-and-display) owns the preset contract.
  Development note: `changes/b0e42eba151c4521950a0a3d15b06373.json`.
  Compact local evidence: `artifacts/depth_lighting_20260916/`.

Keep this task ready for the remaining sky, tracks, glow, periphery and fog
hypotheses. Open-route timing, human review and sustained frame-tail acceptance
remain open; do not repeat the already half-resolution proposal or treat the
whole task as complete.

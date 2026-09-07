# Golden cinematic sunlight at the existing noon

The shared environment now uses warmer direct sunlight, luminous snow highlights, a larger controlled sun halo, HDR highlight glow and nearby shadowed volumetric light. The default remains **12:00 at the original 24-degree elevation / -58-degree orientation**. No afternoon offset or change to the 20-minute day cycle is applied.

Technical Showcase remains **v7 / 849205174**. Camera positions, authoritative 4 m terrain, collisions, tracks, archived generators, race/replay identity and the independent 120 Hz solver are outside this presentation change. Existing assets and particle allocations are reused. No generation credits or purchases were used.

## Implementation and settings

`presentation/alpine_atmosphere.gd` consumes the existing blended weather/daylight state from `alpine_world.gd`. It owns exposure, highlight rolloff, glow, and volumetric settings. `graphics_quality.gd` owns their quality switches. There is no extra timer or time-of-day state. Immediate quality changes reapply the current state; pause retains weather, clouds and wind, and restart retains the chosen settings and weather progression.

| Setting | Clear noon value |
|---|---|
| Direct sun | Energy 1.9; `#ffdfb1` |
| Ambient fill | Energy 0.38; `#b9d6f4`; existing 42% sky contribution |
| Sky top / horizon | `#2f6fa9` / `#c1d7e5` |
| Distant fog | Density 0.000065; `#b4c9da` |
| Filmic exposure / white | 1.3 / 2.8; smoothly returns toward 1 / 1 as daylight or clarity fades |
| Sun disc | HDR energy 14 at Clear noon; same angular disc size, broader multi-scale halo |
| Volumetric light | High only; 120 m length, density 0.0001, sun multiplier 16 |
| Volumetric sampling | 128 base resolution × 64 depth slices, filtering enabled |
| Scattering / history | Anisotropy 0.65; temporal reprojection amount 0.6; sky affect 0.65 |
| Volumetric GI / ambient injection | Both 0; moon injection 0 |
| Highlight glow | Balanced and High; intensity 0.18; additive, HDR threshold 1.4, full-screen bloom 0 |
| Low | Same warm light, sky and exposure; glow and volumetric shafts disabled |

Clear receives the strongest treatment. Cloudy has warm illuminated breaks with stronger direct illumination (0.85) and sharply reduced shafts. Snowfall and rain retain their overcast palette and contrast. Rays and daytime glow switch off at night; Weather FX Off retains the warm direct-light treatment and disables the added effects. Only the existing daylight controller sets the sun and moon directions.

The volume stays inside High's existing 160 m tree-shadow and 220 m terrain-shadow budgets. Minimal density limits extinction, while a directional-light multiplier makes the scattered light visible. Real directional shadows determine occlusion. The short history reduces trailing; no emissive beam meshes or screen-space fake rays are added. This follows [Godot's shadowed volumetric-lighting approach](https://docs.godotengine.org/en/stable/tutorials/3d/volumetric_fog.html).

Glow is limited to HDR highlights with bounded mip levels and no full-screen bloom. The bright sun disc is excluded from the radiance cubemap branch to avoid unstable environment-reflection sparkles. The HUD remains in the existing non-HDR 2D composition. See [Godot's glow controls](https://docs.godotengine.org/en/stable/tutorials/3d/environment_and_post_processing.html#glow).

Snow's existing world-anchored, sun/view-dependent crystals increase from strength 3.0 to 4.2; their derivative filtering, shadow attenuation and night suppression remain. Snow and rock roughness receive small reductions. Needle/branch-snow highlights stay broad, bark stays matte, and restrained needle transmission obeys geometry and cloud shadows. Slightly stronger existing needle wind and clear spindrift reinforce motion. Powder is more neutral in albedo, and formerly unlit precipitation/spindrift now shares real sun/cloud illumination. Particle counts are unchanged.

## Evidence and acceptance

The initial working tree was saved before presentation edits, including a runnable baseline. The [matched gallery](../artifacts/golden_sunlight/review/index.html) compares 39 fresh 4K captures. Its metadata asserts equal camera position/basis/FOV, weather, time, cloud offset, sun direction and height/obstacle hashes. It includes gully (900 m), cliff band (1370 m) and forest (2170 m), toward/across/away from the sun in Clear, Cloudy, Snowfall and Rain, plus separate dawn/dusk/night views. These are scene locations along the descent, not camera altitudes.

The [lighting-only patch](../artifacts/golden_sunlight/lighting.patch) and [source hash audit](../artifacts/golden_sunlight/comparison_source_audit.json) identify the 14 runtime file differences from that saved starting state. Test/report additions are separate. Concurrent interface changes and pre-existing physics/environment work remain in the live working tree.

Twelve additional [canopy controls](../artifacts/pc_environment/golden_final/fixtures.json) compare shafts enabled, shafts disabled, and directional shadows disabled at four positions beneath existing trees. The shadow-disabled controls deliberately affect surface shadows too and are diagnostic captures only. No control override is used in gameplay or benchmarks.

[Motion fixtures](../artifacts/pc_environment/golden_motion/motion.json) cover both drainages, gully/cliff/drop/forest transitions, Clear/Snowfall, and chase/first person. Each fixture advances the real solver at 120 Hz and presentation/particles at 60 Hz for three seconds. The 1080p review videos sample at 30 FPS from actual 3840×2160 output, with native 4K adjacent 60 Hz samples retained separately. GPU particle time is advanced explicitly so screenshot stalls do not accelerate precipitation and spray. This is rendered evidence, not a human skiing observation or a frame-rate benchmark.

<!-- FINAL_AUTOMATED -->
**Automated acceptance is qualified.** The latest results across 17 PC suites contain **611 passing checks and 8 failed assertions**. All **30 atmosphere checks pass**, including exact noon direction, cycle/solver timing, effect suppression, live quality changes, cloud/daylight transitions, pause/restart and unchanged ranked eligibility. The native PC suite separately passes **16 checks**, including actual 3840×2160 output, 4K texture binding, all 18 tree mask imports and FSR2 without redundant MSAA.

All seven hazard assertions (v5/v6/v7 deliberate rock/tree crashes, plus v5 no-braking consequences) reproduce on the untouched saved starting state. The lighting patch changes no solver/contact code. One competitive history/split-panel viewport-bounds assertion still fails in the live tree during the separate UI work. The **isolated initial UI plus this lighting patch passes all 64 competitive checks**, including preservation of benchmark files. An initial mountain-library error caught that UI work mid-update; the completed integration recheck passes all 48 library checks.

Evidence: [latest regression summary](../artifacts/golden_sunlight/regression_summary.json), [native PC log](../artifacts/golden_sunlight/native_pc_suite.log), [baseline hazard reproduction](../artifacts/golden_sunlight/baseline_project/artifacts/pc_environment/regression/results.json), [isolated competitive checks](../artifacts/golden_sunlight/comparison_competitive.log). The complete live regression set is **not green**; the unrelated failures are retained rather than changing collision rules or the concurrent HUD work.

**Rendered review:** all 39 static camera/terrain comparisons match metadata exactly. Across those stills, the largest fraction of pixels with all RGB channels at least 254 falls from 0.270% before to 0.046% after. This SDR readback statistic includes sky and sun pixels; it is not a snow segmentation or HDR measurement. Warm Clear snow retains relief, blue shade, track lips and distant ridge separation in the inspected views. Separate Snowfall and night views retain their cool palette.

All **32 motion fixtures complete without a crash**, producing 2,880 review frames and 160 native samples. Nineteen complete clips were preserved after an early clean recorder exit, then the remaining fixtures resumed with per-clip checkpoints. Their recovered metadata identifies the original completion log; unavailable end positions were left null. The [motion filmstrips](../artifacts/golden_sunlight/review/motion_sequences.jpg) and gallery videos show the evidence directly. No broad halo clipping, terrain ray leak or gross volumetric trail was apparent in the inspected samples; fine temporal shimmer and subjective ray strength remain user-review items.

[Native quality views](../artifacts/pc_environment/golden_quality/fixtures.json) retain the shared warm noon treatment on Low/Balanced/High, with the intended shaft/glow switches. These captures are separate from the timing runs.
<!-- END_FINAL_AUTOMATED -->

<!-- FINAL_PERFORMANCE -->
**Performance acceptance meets the mean GPU budget and p95/p99 targets on these runs; slowest-1% performance remains below 90 FPS.** Four fresh complete descents ran on the Ryzen 5 5600X / RX 9070 / 16 GB PC with Godot 4.7.2, Forward+ / D3D12, actual **3840 x 2160**, **2880 x 1620 internal / 75% FSR2**, **High**, **120 FPS cap** and **SDFGI off**. Each measurement excludes generation, world construction, 120 warmup frames, and screenshot readback. The initial dimension readback occurs before measurement and the finish capture after it.

The before/after copies share the frozen starting source and assets, with only the 14 audited lighting file differences. No measured source changed during any run. Both weather pairs have exactly equal finish position, simulated elapsed time, output settings and terrain/obstacle fingerprints, and all four completed without a crash and stayed unranked. Clear follows the west drainage; Snowfall follows the east, switching to first person in the forest.

| Metric | Clear before | Clear golden | Snowfall before | Snowfall golden |
|---|---:|---:|---:|---:|
| Average FPS | 119.7 | 119.5 | 119.2 | 118.7 |
| Mean frame, ms | 8.355 | 8.366 | 8.390 | 8.423 |
| Frame p95 / p99, ms | 8.827 / 9.892 | 8.830 / 9.895 | 8.972 / 10.256 | 9.186 / 10.619 |
| Slowest-1% FPS | 78.5 | 82.3 | 81.4 | 77.9 |
| Forest average FPS | 119.5 | 118.6 | 116.9 | 114.9 |
| Forest p95 / p99, ms | 9.459 / 10.575 | 9.639 / 10.681 | 10.143 / 11.219 | 10.458 / 11.700 |
| Forest slowest-1% FPS | 81.2 | 84.2 | 75.5 | 71.4 |
| Render GPU mean / p95, ms | 6.111 / 7.035 | 6.634 / 7.719 | 6.301 / 8.188 | 6.781 / 8.459 |
| Render CPU mean / p95, ms | 0.733 / 1.362 | 0.669 / 0.993 | 0.657 / 1.030 | 0.699 / 1.223 |
| Solver mean / p95, us | 404.4 / 593.0 | 377.2 / 476.0 | 379.4 / 536.0 | 400.4 / 602.0 |
| Draw calls mean / p95 | 275.3 / 377 | 275.5 / 377 | 271.7 / 379 | 271.8 / 379 |
| Measured frames | 44264 | 44202 | 43800 | 43627 |
| Descent duration, s | 369.83 | 369.83 | 367.48 | 367.48 |
| Engine video memory peak, GiB | 2.220 | 2.374 | 2.220 | 2.326 |
| Process private / working set peak, GiB | 3.088 / 0.892 | 3.251 / 0.902 | 2.982 / 0.818 | 3.205 / 0.906 |
| Minimum free system RAM, GiB | 2.487 | 3.200 | 3.064 | 1.317 |
| WoW observed samples | 0 / 197 | 0 / 195 | 0 / 194 | 0 / 193 |
| Generation / world build, ms (excluded) | 23236 / 9645 | 20605 / 7820 | 20754 / 7918 | 22053 / 8195 |

Mean GPU increment: **+0.523 ms Clear**, **+0.480 ms Snowfall**.

Clear mean frame cost changes by **+0.011 ms**, p95 by **+0.003 ms**. Snowfall mean frame cost changes by **+0.033 ms**, p95 by **+0.214 ms**. Both full-descent averages and forest averages stay within 90-120 FPS. The golden Snowfall forest is the most demanding measured section: p95 **10.458 ms**, p99 **11.700 ms**, and slowest-1% **71.4 FPS**. These are capped, single-pair comparisons, not evidence that every frame meets 90 FPS or that the patch improves frame pacing.

CPU render timings measure Godot's viewport render work; solver timings measure the independent physics steps. Neither is total CPU frame time. Engine video memory excludes other applications and driver allocations. Process private/working-set peaks and minimum available system RAM are sampled across startup and descent, so their scope differs from steady-state frame statistics. Other applications stayed open; available system RAM varied, reaching **1.317 GiB** in the golden Snowfall run. This and normal run-to-run scheduling limit attribution of small CPU/frame-percentile differences.

The requested later workload has no WoW requirement, and it was absent in every sample. The frozen engine harness retains its old descriptive `background_workload` string mentioning WoW; that legacy text is not an observation. `system.json` contains the actual process samples and is authoritative. The earlier PC implementation report used different workload conditions and already exceeded its p95 target; the fresh starting-state measurements here must be used to assess this patch's incremental cost.

Evidence: [full comparison JSON](../artifacts/golden_sunlight/benchmark_comparison.json), [raw engine/system reports and logs](../artifacts/golden_sunlight/benchmarks/), [source audit](../artifacts/golden_sunlight/comparison_source_audit.json). Raw reports are retained unchanged. The controlled timing comparison excludes the concurrent UI edits; live-tree automated and rendered checks are reported separately above.
<!-- END_FINAL_PERFORMANCE -->

**User skiing acceptance remains pending.** Captured frames and sampled sequences cannot certify every fine-needle shimmer, fast-turn temporal trail or shadow transition on the user's display. The final skiing review should check the golden appearance, track/snow readability, glow around the sun and bright reflections, and shafts while passing nearby trees. Existing geometry, LOD silhouettes and collisions were not redesigned.

## Reproduction

Start with `./godotw.ps1`, select Technical Showcase, Clear, Day and High. Recommended settings remain Forward+ / D3D12, 3840×2160 output, 75% FSR2 (2880×1620 internal), 120 FPS cap, optional SDFGI off.

```powershell
./godotw.ps1 --script tests/golden_sunlight_playtest.gd '--' --views --include-canopy --benchmark-label=golden_review --benchmark-resolution=3840x2160 --graphics-quality=high --upscaler=fsr2 --render-scale=0.75 --fps-limit=120 --terrain-gi=off
./godotw.ps1 --script tests/golden_sunlight_motion.gd '--' --motion --benchmark-label=golden_motion --benchmark-resolution=3840x2160 --graphics-quality=high --upscaler=fsr2 --render-scale=0.75 --fps-limit=120 --terrain-gi=off
./godotw.ps1 --headless --script tests/golden_sunlight_suite.gd
./scripts/test_pc_environment.ps1 -OutputDirectory artifacts/golden_sunlight/regression_new
./scripts/benchmark_pc.ps1 -Label golden_clear_new -Side -1 -Weather clear
./scripts/benchmark_pc.ps1 -Label golden_snow_new -Side 1 -Weather snowfall
```

The user's later instruction removes WoW from the workload requirement. Existing applications are left untouched; actual WoW presence is still sampled. Do not use the older WoW-co-running report as a controlled measurement of this lighting patch.

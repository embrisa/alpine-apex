# PC alpine environment: implementation and acceptance

The PC environment upgrade is implemented in the working tree. Technical Showcase selects **849205174 / v7**. Random Mountain and bare seeds remain v4; archived v1-v6 generators are unchanged. The GPU frame-pacing target must be assessed from the final measurements below, separately from functional completion and user skiing acceptance.

## Delivered

- High defaults to 3840x2160 output on this 4K screen, 75% FSR2 (2880x1620 internal), a 120 FPS cap, SSAO/SSIL and optional SDFGI initially off. Low/Balanced/High identifiers remain. Native and exact two-thirds rendering, display mode and frame cap persist across application launches, restarts and mountain changes. These preferences do not affect ranked eligibility or recipe/replay identity.
- Exact output dimensions are verified from the rendered image. The Windows frame-border sizing error is fixed. HUD rendering remains at output resolution; FSR2 uses no additional MSAA/TAA. No dynamic resolution is used.
- Selective 4K CC0 snow, rock and bark maps, with 2K/1K derivatives, mipmaps and VRAM compression. Daylight, snow response, ambient sky fill and fog were retuned. The shared cloud layer now sits above the 4300 m summit instead of below it.
- v7 retains the south-face drainage, cliff, apron, optional drop and forest structure, adding angular buttress profiles and sheltered snow exposure on the same authoritative 4 m grid. Contacts, tracks, survey picking and crash terrain retain that authority.
- Nine conifers, three silhouettes each of spruce/fir/pine, with visible branches, fine needles, cutout clusters and independent snow masks. Six rock assets comprise two buttresses, two ledges and two boulders. Runtime exports: 33 GLBs including near/mid/far tree LODs and 18 directional-atlas texture derivatives.
- One surface per conifer; 16,580-28,004 near triangles, 6,821-11,659 mid triangles and two-triangle far cards. Regional MultiMesh batching remains. High transitions are 95/280 m with visibility to 1300 m; 20 m opaque dither transitions share exact batch bounds. Empty atlas sides are cropped in the shader. A matching mid-detail shadow proxy casts tree shadows to 160 m on High while terrain/rock shadows retain 220 m.
- Final GLBs preserve RGBA material masks without routing runtime trees through alpha blending. All 18 near/mid imports are explicitly counted and checked; a float-valued JSON LOD cannot silently skip validation. Benchmark/capture artifacts are excluded from Godot import scanning.

## Assets and provenance

Editable source: [pc_environment.blend](../art_source/blender/pc_environment/pc_environment.blend). Rebuild with [build_pc_environment.py](../scripts/art/build_pc_environment.py); [prepare_pc_textures.py](../scripts/art/prepare_pc_textures.py) verifies the pinned scanned maps. Runtime dimensions, material assignments, LOD counts, atlas sizes and hashes are recorded in [the asset manifest](../art_source/pc_environment_manifest.json), [texture provenance](../art_source/pc_texture_sources.json) and [runtime manifest](../assets/graphics/manifest.json).

**Meshy spending: 0 / 1500 authorized credits.** No generation batch or purchase was needed. The separate [PC credit ledger](../art_source/pc_environment_credit_ledger.json) preserves that accounting. The optional [Snowy Spruce Tree Pack](https://superhivemarket.com/products/low-poly-snowy-spruce-tree-pack) remains a potential time-saving source, unpurchased; the delivered assets use Blender and free sources.

## Automated acceptance

The regression pass completed **587 checks across 16 suites**: physics, runtime, graphics, PC graphics, mountain data, generated mountains, mountain library, summit, v5/v6/v7 showcase terrain and hazards, race and competitive. Two initial failures were rerun successfully after the concurrent restart/input work and updating the race test's obsolete v10 identity expectation to the current benchmark identity.

The strengthened **native PC suite passes 16 checks**, including all 18 tree mask/geometry checks, real 4K maps, exact 3840x2160 output, FSR2 without MSAA, persistence and unchanged ranked identity. **All 33 final GLBs pass independent Blender reimport**, checking dimensions/triangle counts and all four conifer masks. Logs: [regression results](../artifacts/pc_environment/regression/results.json), [native graphics](../artifacts/pc_graphics_verified_final.log), [final GLB validation](../artifacts/pc_glb_final_validation.log).

The old generator implementations and recipe fingerprints are preserved. v7 has 7947 obstacles and 46 spines. The v7 suite freezes its new height/obstacle fingerprints and verifies recipe reconstruction, race sharing, both solver descents, contact continuity and hazard responses. Automated descents remain unranked; competitive and race suites verify the player's benchmark files remain unchanged.

## Rendered acceptance

[Matched observer review](../artifacts/pc_environment/review/index.html) compares original and updated shared graphics on **the same v6 terrain, fixed survey-camera transforms, Low/native 1440x900**. Forest, cliff-band and complete-face views isolate the graphics treatment from the new v7 heightfield. Skier pose changes from concurrent physics work are outside this upgrade.

[Final v7 inspection metadata](../artifacts/pc_environment/final_review/views.json) covers 4K High chase/first-person views, both weather states, and separate dawn/dusk/night views. Close-up review confirmed bark texture, fine needle structure, separate snow deposits and readable lit/shaded snow. The original 32 real-solver motion fixtures cover both drainages, cliff approaches, the optional drop and forest, in clear/snowfall and chase/first person; all completed without a crash, with the drop taking off and landing normally. Eight forest fixtures were recaptured after the final export/LOD fixes in [final motion metadata](../artifacts/pc_environment/final_review/motion.json).

Motion evidence consists of successive captured frames, including adjacent 60 Hz presentation frames over a real 120 Hz solver. Capture overhead is excluded from full-descent timing. This does not establish continuous human perception of every shimmer, trail or shadow transition. Sparse needle edges, directional impostor blending, shadow distance transitions and the existing cylindrical collision approximations remain appropriate user skiing review points. No manual skiing acceptance is claimed.

## Performance acceptance

Both final full descents completed without a crash. Device: Ryzen 5 5600X, RX 9070, 16 GB RAM; Godot 4.7.2 Forward+ / D3D12. WoW Classic remained running at the user's request, detected in all **196 / 195 monitoring samples**, and the Godot editor/Blender GUI were preserved. Results are not isolated GPU measurements. Weather and drainage differ between the two runs, so their difference is not a measurement of snowfall cost alone.

Each full descent excludes startup and 120 warmup frames; screenshots are disabled during measurement. Actual output is **3840x2160**, with **2880x1620** internal size calculated from the active 75% viewport scale, FSR2, 120 FPS cap and High settings. Scripts, shaders, resource settings and manifests were hashed before/after each run: **no changes**. Separate section probes are labelled as tuning probes, never full descents.

| Full-descent metric | Clear / western drainage | Snowfall / eastern drainage |
|---|---:|---:|
| Measured frames | 41,681 | 42,183 |
| Descent duration | 369.83 s | 367.48 s |
| Average FPS | **112.7** | **114.8** |
| Mean frame time | 8.873 ms | 8.711 ms |
| p95 / p99 frame time | **13.037 / 16.526 ms** | **12.354 / 15.298 ms** |
| Slowest-1% FPS | 50.8 | 52.8 |
| Forest average FPS | 94.3 | 107.0 |
| Forest p95 / p99 | 16.010 / 19.146 ms | 13.519 / 16.693 ms |
| Render CPU mean / p95 | 0.897 / 1.339 ms | 0.905 / 1.416 ms |
| Render GPU mean / p95 | 5.741 / 9.105 ms | 5.618 / 8.925 ms |
| Solver step mean / p95 | 433.6 / 606 us | 437.2 / 625 us |
| Draw calls mean / p95 | 282.4 / 379 | 274.6 / 381 |
| Peak engine video memory | 2.223 GiB | 2.223 GiB |
| Peak engine private / working-set RAM | 3.089 / 0.889 GiB | 2.982 / 0.812 GiB |
| Minimum free system RAM | 3.911 GiB | 3.759 GiB |
| Generation / world construction, excluded | 25.20 / 9.40 s | 24.68 / 9.65 s |

**Performance acceptance is partial.** Both full-descent averages and forest averages are in the 90-120 FPS range, and both full-descent p99 results meet 16.7 ms. Neither full-descent p95 meets 11.1 ms; the western forest also exceeds the p99 target. These measurements do not establish sustained 90 FPS in every short interval. The remaining frame spikes cannot be attributed solely to Alpine Apex or WoW from this co-running test. Native and two-thirds rendering are exposed, but their full-descent performance is not certified by these 75% measurements.

Detailed engine and system reports: [clear](../artifacts/pc_environment/final_high_clear_west/native_-1_clear.json), [clear system](../artifacts/pc_environment/final_high_clear_west/system.json), [snowfall](../artifacts/pc_environment/final_high_snowfall_east/native_1_snowfall.json), [snowfall system](../artifacts/pc_environment/final_high_snowfall_east/system.json). A compact [JSON handoff](../artifacts/pc_environment/final_report.json) and [CSV table](../artifacts/pc_environment/final_benchmarks.csv) include both runs, acceptance status and editable-source hashes. Process/system RAM sampling spans startup and descent; the engine frame/video-memory measurements cover the warmed descent. CPU render timing is not total application CPU time, and engine-reported video memory is not total GPU memory used by all applications.

The initial pre-upgrade laboratory diagnostic was 77.3 FPS at **3856x2176**, p95/p99 **21.206/26.307 ms**, with the previous High settings. It is not a controlled v7 comparison. The first v7 development descent at exact 4K/75% averaged 98.5 FPS but only 52.4 FPS in the forest; it motivated LOD, shadow and export corrections. Preserve both as historical diagnostics rather than using their averages as final acceptance.

| Acceptance category | Status |
|---|---|
| Automated contracts and asset imports | Passed the reported suites and final import checks |
| Rendered inspection | Matched observer views, 4K views and sampled motion reviewed; continuous temporal-artifact acceptance remains open |
| Performance | Average and full-descent p99 targets met; p95 and western-forest spikes remain above target |
| User skiing | Pending manual chase/first-person review and subjective fidelity/feel acceptance |

## Handoff

Start with `./godotw.ps1`, choose **Generate / Saved Mountains > Technical Showcase**, then **Ski This Mountain**. High is the initial configuration; Visual Settings exposes the persistent rendering controls. The [portable v7 recipe](../examples/mountains/technical-showcase-v7.apexmountain) can also be imported or used by shared races.

Repeat full measurements with `./scripts/benchmark_pc.ps1 -Label my_clear_run -Side -1 -Weather clear` and a separate snowfall/eastern run. Repeat automated checks with `./scripts/test_pc_environment.ps1`. Godot MCP toolkit, addon/autoload configuration, original import changes and concurrent physics/input/HUD work are preserved. No commit, push, purchase or personal-best write was performed by this upgrade.

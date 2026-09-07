# Validation

## PC alpine environment and Technical Showcase v7 — 2026-09-07

The PC upgrade passes **587 regression checks across 16 suites**, a separate **16-check native PC graphics run**, and **33 independent Blender GLB reimports**. The final native checks explicitly inspect all 18 conifer near/mid masks and geometry budgets, exact 3840x2160 output, 4K maps, FSR2 antialiasing, preference persistence and unchanged ranked identity. Archived v1-v6 generators remain unchanged; v7 recipes and race references reconstruct the fixed seed 849205174. Tests and benchmark descents remain unranked. Concurrent model-v11 input/handling work is preserved.

At **4K output / 75% FSR2 / High / 120 FPS cap**, with **WoW Classic running throughout**, the final clear western descent averages **112.7 FPS**, p95/p99 **13.037/16.526 ms**, slowest-1% **50.8 FPS**. The snowfall eastern descent averages **114.8 FPS**, p95/p99 **12.354/15.298 ms**, slowest-1% **52.8 FPS**. Forest averages are **94.3 / 107.0 FPS**. Both finish without a crash after 369.83 / 367.48 seconds; startup and 120 warmup frames are excluded, with no captures during measurement. Scripts, shaders, resource settings and manifests stayed unchanged during each run.

**Performance acceptance is partial:** full-descent average and p99 targets pass, p95 does not; the western forest also misses p99. These are co-running PC measurements, not isolated GPU results. Matched fixed-camera v6 before/after captures and separate 4K v7 clear/snowfall, dawn/dusk/night and sampled motion views were reviewed. Continuous temporal-artifact perception and **user skiing acceptance remain pending**. The PC policy replaces the historical MacBook requirement; prior measurements below remain historical records.

See [the complete implementation and acceptance report](PC_ENVIRONMENT_IMPLEMENTATION.md), [matched capture review](../artifacts/pc_environment/review/index.html), [benchmark JSON](../artifacts/pc_environment/final_report.json) and [CSV](../artifacts/pc_environment/final_benchmarks.csv) for source hashes, CPU/GPU timings, memory, setup and reproduction commands.

Historical policy (2026-09-06, superseded by the PC policy above): approximately 60 FPS on the user's MacBook at Low, with Balanced and High free to prioritize fidelity. The older 1440p/120 FPS and 4K/60 comparisons below are also historical goals. The 120 Hz simulation remains independent. See [current graphics performance policy](GRAPHICS.md#performance-policy).

## Terrain surface variation and darker rock — 2026-09-05

The shared terrain material now blends randomized texture patches, adds irregular drift/mineral variation and exposes more charcoal/slate rock on the surrounding mountain faces. The existing heightfield and obstacle geometry are unchanged. Fine snow normal/roughness maps use ordinary mip filtering to limit the added sampling cost; color and rock retain anisotropic filtering.

**12/12 graphics and 10/10 native Terrain3D checks passed.** Native material inspection covers chase, first-person, open snow, cliffs and vistas at all three quality levels, plus six successive views in motion, for both renderers (42 captures). Final captures are in `artifacts/terrain_variation/filtered_{legacy,terrain3d}/`; baseline views are in `before_legacy/`. The inspected surfaces have less recognizable fixed texture repetition and darker, broader exposed mountain rock. The coarse decorative geometry, especially Terrain3D's distant faceting, remains visible. Scripted stills do not certify the absence of temporal shimmer on every device.

Matched screenshot-free full descents on Apple M4, Godot 4.7.2 Forward+/Metal, Balanced, clear noon, **2560×1440**:

| Material | Mean frame ms | Mean FPS | 1% low FPS | p95 / p99 ms |
|---|---:|---:|---:|---:|
| Before | 11.184 | 89.4 | 64.3 | 13.980 / 15.068 |
| Final | 12.785 | 78.2 | 56.0 | 16.099 / 17.271 |

The added variation costs **1.60 ms mean frame time (14.3%)** in these individual development-machine descents. This is a measured visual-quality tradeoff, not a performance improvement; the then-current 1440p/120 FPS target was unmet. GPU timing is unavailable, and desktop variance prevents exact attribution. Reported video memory remains 532 MiB. Both runs finish in 55.702894 s, peak at 144.056772 km/h, and have identical course identity and mountain height/environment checksums, with no crash or airtime. All runs remain unranked.

Evidence: `artifacts/terrain_variation/validation.json`, `artifacts/weather_benchmark_terrain_before.json`, and `artifacts/weather_benchmark_terrain_filtered_valid.json`. Earlier intermediate runs and the explicitly invalid sampler-filter experiment are excluded from these results.

## Graphics and seeded mountain foundation — 2026-09-05

The upgraded descent has textured snow/rock, a 42,430-triangle skier with separate equipment, three spruce derivatives with near/mid/far levels, three boulders, two scrub variants and independent graphics controls. A versioned scenery generator produces an 8.192 km heightfield and snow/rock/vegetation/exposure masks. Terrain3D 1.0.2 is integrated as a selectable renderer. The original renderer remains the default because the measured comparison did not establish a Terrain3D performance advantage in the current bounded course. Both renderers use the new art and shared mountain data.

### Correctness and native inspection

**45/45 physics, 72/72 runtime, 12/12 graphics, 6/6 mountain and 10/10 native Terrain3D checks pass.** The solver, tuning, input router, rider input, session and original laboratory generator are byte-identical to the pre-upgrade archive. All 99,009 source terrain vertices survive the generated image and Terrain3D import with zero measured error. Terrain3D collision is disabled; a moving patch retains the original contact triangles near the camera. Boundary tests cover exclusion clipping, region alignment and all quality presets.

Native harnesses produced **19 handling, 35 weather, 50 lighting and 10 graphics/terrain-edge captures**, with no failed assertions. The lighting total includes 48 listed captures plus the sunlit/shaded cloud comparison pair. Matching before/after chase and first-person captures show the changed snow detail, vegetation, equipment and mountains. Additional inspection covers tuck, carving, braking, airtime, landing, fast snowfall, nighttime rain/snow, the settings panel and both Terrain3D side boundaries. Central route and obstacle silhouettes remain readable. The cloud sweep changes rendered snow luminance by **0.123** and the jacket probe by **0.086**; these are screenshot RGB differences, not photometric measurements.

Remaining visual limits include per-region tree LOD popping, flat distant tree silhouettes and generated glove/clothing deformation in extreme poses. Stills and scripted captures do not certify temporal shimmer, subjective handling or end-to-end input latency. The surrounding mountains remain decorative; the generator does not implement hydraulic erosion, streaming or new playable race geometry.

Visual evidence:

- [Matching before/after cameras](../artifacts/graphics_before_after.png)
- [Handling and equipment](../artifacts/graphics_handling_comparison.png)
- [Weather, daylight and terrain boundary](../artifacts/graphics_conditions.png)
- [Machine-readable evidence index](../artifacts/graphics_validation.json)

### Final performance measurements

Native macOS on **Apple M4**, Godot 4.7.2, Forward+ / Metal. Actual viewport pixel dimensions were verified by a one-time readback before each run. The following descents exclude 120 warmup render frames and contain no screenshot captures. FPS is 1000 divided by mean elapsed frame time; 1% low is 1000 divided by the mean of the slowest 1% of frame times. GPU timing was unavailable. Draw calls are averages; memory is the peak reported video-memory allocation, not total process RAM.

| Preset / pixels / weather | Terrain renderer | Mean FPS | 1% low FPS | p95 / p99 ms | Draw calls | Video memory MiB |
|---|---|---:|---:|---:|---:|---:|
| Balanced / 2560×1440 / Clear | Legacy | 91.9 | 67.4 | 13.521 / 14.399 | 455 | 532 |
| Balanced / 2560×1440 / Clear | Terrain3D | 89.4 | 64.3 | 14.035 / 15.013 | 361 | 605 |
| Low / 1920×1080 / Clear | Terrain3D | 119.8 | 103.2 | 9.110 / 9.475 | 283 | 448 |
| High / 3840×2160 / Clear | Terrain3D | 44.3 | 31.8 | 28.322 / 30.202 | 439 | 950 |
| Balanced / 2560×1440 / Snowfall | Legacy | 92.8 | 68.6 | 13.342 / 14.142 | 456 | 532 |

These are individual development-machine runs. The small Clear/Snowfall and Legacy/Terrain3D differences can include desktop variance; they do not isolate GPU costs or establish a general renderer ranking. The original renderer remained the default at the time of this comparison. Terrain3D was available with `--terrain-renderer=terrain3d` at the time of this historical comparison; it has since been removed.

At the pre-upgrade **1440×900** resolution, an additional matched capture-enabled descent changed mean / p95 / p99 from **8.450 / 9.035 / 9.114 ms** to **8.501 / 9.168 / 9.919 ms**. This comparison includes synchronous screenshot stalls and is kept separate from the screenshot-free table. Its 1% low is not a useful normal-gameplay estimate. The old baseline did not record 1% lows or memory. Source reports are `weather_benchmark_graphics_before.json` and `weather_benchmark_final_baseline_resolution.json`.

Every measured descent finishes in **55.702894 s**, peaks at **144.056772 km/h**, and records no airtime or crash. All are unranked. Final world build times are roughly **0.88–1.02 seconds** on this machine, including generation, importing data and constructing scenery.

**1440p/120 FPS with 1% lows above 90 was not reached on this M4 in Balanced; 4K/60 was not reached in High.** The requested RTX 3060/RX 6600 XT, Windows/Linux and M2 baseline targets require direct tests. Shipping platform exports have not been validated. Cross-platform seed/checksum reproduction also remains unverified. Terrain3D's published Metal support is qualified; this local build loads and renders successfully but emits a Godot 4.7 deprecation warning for `instance_reset_physics_interpolation()`.

Use the commands in [GRAPHICS.md](GRAPHICS.md) to rebuild assets and run profiling. Final screenshot-free reports are `artifacts/weather_benchmark_final_{legacy_balanced_1440p,t3d_balanced_1440p,low_1080p,high_4k,snowfall_balanced}.json`. Earlier exploratory runs remain archived and are excluded from this table.

The reusable library includes editable Blender files, runtime GLBs, eleven standalone PBR GLBs with verified embedded images and reimports, texture provenance, and generation history. Meshy spending is **125 / 1,000 credits**, leaving **875** in the authorized allowance. See `art_source/meshy/credit_ledger.json` and `art_source/reusable/manifest.json`.

The sections below document earlier passes. Their measurements describe those builds; shared capture filenames may now contain the latest graphics. Use the evidence index above for the current result.

## Sun, cloud shadows and time of day — 2026-09-05

Added a shared projected cloud field to the sky and opaque surface lighting, enabled nearby terrain shadow casting, and added Dawn / Day / Dusk / Night with an optional twenty-minute cycle. Direct light, sky, ambient fill and fog respond to both weather and time. Moonlight maintains night visibility. Weather/time selection remains presentation-only; the solver, benchmark identity and personal-best schema are unchanged.

### Headless checks

**45/45 physics and 72/72 runtime checks pass.** The fifteen additional runtime checks cover sun warmth/strength/direction, moon activation, weather-dependent night light, shared cloud parameters on sky/snow/skier, paused cloud motion, world-space wind displacement, Effects Off at night, frozen title/pause clocks, cycle timing and wrap, retained settings on restart, connected time controls, and at most one active shadow-casting light through the complete cycle. The deterministic descent still finishes in **55.702894 s** at **144.056772 km/h** peak, with no crash or airtime. These checks do not validate rendered appearance or sound.

### Native visual inspection

`tests/lighting_playtest.gd` produced **50 unranked captures at 1440 × 900** with no failed assertions or engine errors. They cover:

- Four weather presets × four times of day × both gameplay cameras (32 captures, with precipitation hidden to isolate illumination).
- A 48-position cloud sweep, with sunlit/shaded image pairs and a cloud-shadow-disabled control. The rendered snow probe changed by **0.130** luminance and the sun-facing orange sleeve by **0.184** on the same frames. The ambient-facing sleeve correctly retains its fill light. Values are differences in weighted screenshot RGB, not photometric measurements.
- Sun and moon disks, local geometry shadows, six twilight samples around sunrise/sunset, and the time/weather panel.
- Moving Snowfall/Rain in both cameras at night, entered at 120 km/h and captured at approximately 104 km/h after a second of skiing.

Inspection confirms coordinated patches of cloud shade on the skier and ground, warm dawn/dusk color, cooler overcast light, readable blue moonlit terrain, and local tree/skier shadows. The central route, nearby obstacles, ski tips and HUD remain visible through nighttime precipitation. The enlarged settings panel fits the viewport. The moon/sun transition retains ambient visibility while directional light fades. Lighting-harness FPS readings are replaced with an inspection label; its synchronous GPU readbacks are not a performance test.

The **35-capture weather matrix was also rerun** after reducing the snow allocation. Both cameras retain precipitation coverage at 30/120/200 km/h entry speeds, with a clear central route. The transition, Low/Off, V, pause, camera switch and restart checks remain successful. Final allocations are 600 snow + 900 rain + 200 ground particles on High (1,700 total), and half that on Low (850).

No audio layers changed in this lighting pass. Prior source-level and mute checks remain valid; no new subjective listening assessment is claimed.

### Performance method and evidence

Fresh full-descent runs use the same fixed 1440 × 900 native viewport, input and capture schedule, with separate elapsed-frame and viewport-render fields. `--autoplay` now enables Godot's [viewport render measurements](https://docs.godotengine.org/en/stable/classes/class_renderingserver.html#class-renderingserver-method-viewport-get-measured-render-time-gpu). This Metal run returns CPU render timing but no positive GPU timing, so GPU measurements are marked unavailable. Effects Off retains the new directional geometry shadows and selected time of day: this comparison measures weather overhead against current basic lighting, not every lighting change against the older build.

The early cloud-only comparison had variable desktop frame pacing: cloud shadows disabled gave p95 **12.179 ms** and **16.353 ms** across two runs, while enabled gave **9.061 ms**. This does not establish that shadows improve performance. The pre-change attempt used a resized 1476 × 900 viewport and is excluded from direct comparisons. The final fixed-size measurements below supersede those exploratory runs.

Profiling prompted two cost reductions: cloud transmission is now sampled per vertex and interpolated over the four-metre terrain grid, and the High snow volume was reduced from 900 to 600 flakes. Object shadows and material lighting still evaluate per pixel. Sky cloud noise remains at half resolution. The Snowfall benchmark was repeated after the allocation change; the other final rows use the same active rain/spindrift counts and cloud shader, with an unused reserve of 300 extra snow particles. They are unaffected by that reserve during steady-state rendering.

Native macOS, Apple M4, Godot 4.7.2, Forward+ / Metal; first 120 frames excluded, screenshot overhead included:

| Case | Mean ms | p95 ms | p99 ms | Added p95 ms |
|---|---:|---:|---:|---:|
| Effects Off, Day | 8.456 | 8.894 | 9.042 | +0.000 |
| Clear, Day | 7.047 | 9.038 | 10.722 | +0.144 |
| Snowfall, Day | 8.438 | 9.043 | 9.241 | +0.149 |
| Rain, Day | 8.431 | 9.074 | 9.193 | +0.180 |
| Rain, Night | 8.298 | 9.054 | 11.917 | +0.160 |

The final set's largest added p95 is **0.180 ms**, within the 2 ms target against current Effects Off. All five runs finish in **55.702894 s**, peak at **144.056772 km/h**, and report no crash or airtime. The exploratory variance and differing mean/p99 values show that desktop frame pacing still matters; this is an observed run comparison, not an isolated GPU-cost claim or a hardware guarantee.

Commands and evidence:

```sh
./godotw --headless --script tests/physics_suite.gd
./godotw --headless --script tests/runtime_suite.gd
./godotw --script tests/lighting_playtest.gd
./godotw -- --autoplay --weather-quality=off --benchmark-label=lighting_off
./godotw -- --autoplay --weather=clear --benchmark-label=lighting_clear
./godotw -- --autoplay --weather=snowfall --benchmark-label=lighting_snowfall
./godotw -- --autoplay --weather=rain --benchmark-label=lighting_rain
./godotw -- --autoplay --weather=rain --time-of-day=night --benchmark-label=lighting_night_rain
```

Evidence: `artifacts/lighting_results.json`, `lighting_validation.json`, `weather_benchmark_lighting_*.json`, `lighting_physics.log`, `lighting_runtime.log` and `lighting_playtest.log`. Images are `light_*.png`; visual overviews are `lighting_contact_chase.png`, `lighting_contact_pov.png` and `lighting_contact_extra.png`.

Limits: one projected cloud layer, horizon-clamped cloud projection, local geometry shadow range of 220 m, and no geometry shadows from distant decorative mountains. The orbit is artistic, without dates, seasons, lunar phases or astronomical accuracy. No terrain generation, physical weather forces, snow accumulation or wet handling was added. These observations are from one Apple M4 development machine.

## Weather and arcade effects — 2026-09-05

Implemented four presentation presets, slow automatic transitions, two GPU precipitation volumes, ground spindrift, cloud/sun lighting, a rain loop, and arcade peripheral streaks. Weather controls are available from title/pause; settings survive restart for the application session. Physics model v3, generator v2, course identity and record schema are unchanged.

### Automated and rendered acceptance

- **45/45 physics checks and 57/57 runtime checks pass.** Runtime coverage adds weather controls, three-minute holds and twenty-second blends, cycle ordering, paused/frozen progression, restart retention, quality ceilings, original-sky restoration, V/M behavior, camera-switch/teleport resets, actual HUD conditions, and unchanged simulation/record state. Autoplay now ignores live movement input and gameplay hotkeys so a focused benchmark cannot be contaminated by keyboard/controller activity.
- **35 native rendered weather captures** were inspected: Clear/Cloudy/Snowfall/Rain × chase/first person × 30/120/200 km/h entry speeds, successive snow/rain motion frames, a turn, V off, Low, Off, a blend midpoint, pause/settings layout, and restart. Every capture is unranked, with no reported camera-clearance violation. Entry speed naturally changes during each short ride (the 200 km/h fixtures reach roughly 173 km/h before the main capture); the JSON records actual speed.
- The central route, nearby obstacles, ski tips/rider, and HUD remain readable. Precipitation fills both views, persists through the full descent, changes position across successive frames, and loses exaggerated stretching with V. The weather panel fits the 1440 × 900 viewport. Cloud shapes and illumination differ between presets; fog remains an artistic distance cue rather than a whiteout.
- Native audio playback was exercised; headless checks verify wind/rain mute levels. The 7.9-second rain loop is mono 22,050 Hz PCM with measured peak 0.384 and RMS 0.120, without clipped source samples. **No subjective listening assessment is claimed.** Balance against the ski/contact layers still needs a listener. Shutdown now stops loop playback before the native audio callback is torn down; the final snow/rain benchmark logs exit without resource warnings.

### Frame-time comparison

Native macOS, Apple M4, Godot 4.7.2, Forward+ / Metal, 1440 × 900, the same full tucked descent and capture schedule. Off provides a fresh baseline using the original atmosphere and existing camera/blur effects. High is used for Clear/Snowfall/Rain. Samples exclude the first 120 warmup frames and include screenshot overhead; the shutdown wait is outside the sample window.

| Weather | Mean ms | p95 ms | p99 ms | Added p95 ms |
|---|---:|---:|---:|---:|
| Off | 8.418 | 8.449 | 8.702 | +0.000 |
| Clear | 8.409 | 8.914 | 9.354 | +0.465 |
| Snowfall | 8.420 | 9.033 | 9.734 | +0.584 |
| Rain | 8.420 | 9.167 | 9.832 | +0.718 |

The worst measured added p95 is **0.718 ms**, below the 2 ms target on this machine. All four final benchmark reports finish in **55.702894 s**, peak at **144.056772 km/h**, and report **zero airtime and no crash**. This is an observed frame-time comparison on one desktop, not an isolated GPU timing measurement or a minimum hardware guarantee.

Commands and evidence:

```sh
./godotw --headless --script tests/physics_suite.gd
./godotw --headless --script tests/runtime_suite.gd
./godotw --script tests/presentation_playtest.gd -- --weather-matrix
./godotw -- --autoplay --weather-quality=off --benchmark-label=off
./godotw -- --autoplay --weather=clear --benchmark-label=clear
./godotw -- --autoplay --weather=snowfall --benchmark-label=snowfall
./godotw -- --autoplay --weather=rain --benchmark-label=rain
```

Structured evidence: `artifacts/weather_validation.json`, `weather_benchmark_*.json`, `weather_presentation_results.json`, `physics_results.json`, and `runtime_results.json`. Native captures are `artifacts/feel_weather_*.png`; overview sheets are `weather_contact_chase.png`, `weather_contact_pov.png`, and `weather_contact_lifecycle.png`.

Limitations of this earlier pass: precipitation uses bounded periodic volumes, depth testing and soft fades, without surface collision/splashes or shelter detection. Ground drift uses two emitter-level height/normal samples and approximates uneven terrain. The later lighting pass above adds moving cloud shadows and a day/night cycle. There is no accumulation, wet grip or physical wind force. Lower-end GPUs, other operating systems, subjective audio feel and physical controllers require their own playtests.

Godot 4.7.2 stable, native macOS, Apple M4, Forward+ / Metal. The user's project rendering, plugin and autoload configuration were preserved. The editor MCP connection was unavailable, so validation used `./godotw` and screenshots from the actual rendered viewport.

## Calibration and physics

| Measurement | Previous model | Model v2 |
|---|---:|---:|
| Default tucked descent | 38.964 s | 55.703 s |
| Peak on the default descent | 193.95 km/h | 144.06 km/h |
| Contact loss on that clean line | 0 s | 0 s |
| Tucked, 20 s on a planar 24.7° slope | 172.53 km/h | 135.34 km/h |
| Upright, same plane and duration | 128.80 km/h | 91.90 km/h |

The v2 default descent reaches 30 km/h after 6.225 s, 60 after 15.358 s, 90 after 20.092 s and 120 after 25.342 s. It does not reach 150. At ten seconds the speed is 45.38 km/h. The gentler start changes the benchmark's vertical drop to approximately 600 m over 1.55 km of slope.

There is **no speed cap**. On unobstructed synthetic planes, 90-second tucked runs reach:

| Pitch | Speed |
|---|---:|
| 10° | 85.60 km/h |
| 25° | 141.75 km/h |
| 35° | 166.96 km/h |
| 55° | 201.62 km/h |

These are design calibration fixtures, not empirical validation against real ski equipment. The 55° plane is not a new playable mountain. At 200 km/h a 12° equipment-heading error leaves 71.8% balance after 0.4 s; at 90 km/h the same error remains fully recoverable. Balance depends on lateral recovery distance and available grip, not a speed threshold or random roll.

## Automated checks

- **45/45 physics checks pass.** Gravity, passivity, turning costs, braking, uphill momentum, speed calibration, stance opening, slip recovery, cross-slope heading, contact/landing/air steering, seed repeatability, swept collisions, frame-schedule independence and finish timing/width.
- **32/32 runtime checks pass.** Lifecycle, pause/resume, input strengths/bindings, exact defaults, unranked speed entry through 200 km/h, automated restart eligibility, v2 benchmark identity, first-person toggle, motion toggle, eight speed labels and viewport layout.
- **19 native rendered handling captures** cover chase and first-person views from seven lab entry speeds, a loaded turn, braking, flight, landing and the workbench. The scripted traversal reports no camera-clearance violation and every capture is unranked. Entry speeds change naturally during each capture; `presentation_results.json` records actual speed, contact, tuck and balance.

Commands:

```sh
./godotw --headless --script tests/physics_suite.gd
./godotw --headless --script tests/runtime_suite.gd
./godotw --script tests/presentation_playtest.gd
./godotw -- --autoplay
./godotw -- --autoplay --first-person
```

The two headless suites do not establish visual feel, audio quality or physical controller behavior. Native captures were inspected for skier/ski-tip visibility, readable speed labels, turn/spray feedback, camera clearance, snow/trees and workbench fit. The presentation harness manually supplies 120 Hz steps while rendering; use the complete autoplay descent for frame-time profiling.

## Rendered benchmark

The final unranked autoplay descent uses the real scene, physics and presentation at 1440 × 900. Samples use elapsed microseconds between rendered callbacks after 120 warmup frames; screenshot capture overhead is included. These numbers come from the final `artifacts/render_benchmark.json` run.

| Measurement | Result |
|---|---:|
| Captured frames | 6457 |
| Mean frame time | 8.422 ms (~118.7 FPS) |
| p95 / p99 frame time | 8.780 / 9.052 ms |
| Final smoothed simulation/session tick | 0.119 ms |
| World construction | 390.8 ms |
| Descent outcome | Finished, no crash; 0.000 s airtime |

Raw evidence: `artifacts/physics_results.json`, `runtime_results.json`, `presentation_results.json`, and `render_benchmark.json`. Native screenshots are `artifacts/run_*.png` and `artifacts/feel_*.png`.

## Limits

- Human handling acceptance and listening tests remain necessary. The audio layers and haptics are driven by the measured state, but their subjective mix and physical vibration were not verified here.
- The reference image is an art direction target. The scene remains procedural prototype art in a bounded laboratory: no photoreal assets, streamed procedural mountain, race authoring, ghosts or sharing were added.
- Tree detail switches per 128 m region at 300 m. Some LOD popping is possible. Mesh detail, nearby shadows and screen effects need profiling on lower-end GPUs.
- Contact remains a constrained point mass with a four-metre normal stencil. There are no independent flexible skis, full-body balance, active absorption or ragdoll simulation.
- Fixed-tick repeatability is checked at 30/60/120/144/240 FPS schedules on this engine. Cross-platform bitwise replays are not established.
- No physical DualShock/DualSense hardware, other desktop operating systems, packaged exports or other GPUs were tested. A development-machine measurement is not a minimum frame-rate guarantee.
- Benchmark identity is now `laboratory-v3-physics-v4-default`; old model times are not compared with this tuning. The record schema remains v1. Production records still need tuning hashes and stronger replay validation.

## Steering correction — model v3

Corrected the yaw and edge sign for rider-relative left/right. Added six physics direction checks across three starting headings and four action-to-screen direction checks covering chase and first-person views. Both suites pass without engine errors. Generator v2 and speed calibration are unchanged; the rendered benchmark above was measured in the preceding speed pass. The native handling capture was rerun after the direction fix.

## Sculpted snow and contact — 2026-09-06

Laboratory generator v3 adds actual wind drifts, smaller scallops and mounds to the shared contact/render heightfield; the measured relief range in the test patch is 3.199 m. The triangle count remains 196,608. Mountain data is generator v2 and records the laboratory v3 authority. Model v4 adds bounded loose-snow resistance and penetration telemetry, driving paired tracks, powder and grains. Benchmark identity is `laboratory-v3-physics-v4-default`.

The updated physics suite passes 54 checks, including actual geometry displacement, loose/packed snow comparisons, penetration/planing, passive skidding, no airborne snow forces and render-schedule independence. The default clean descent finishes in 57.431 s with a 142.819 km/h peak, 40.744 km/h after ten seconds and zero airborne time. The previous flat-snow/model-v3 descent was 55.703 s / 144.057 km/h. This is an intentional benchmark change, not a performance regression in simulation timekeeping.

The native snow harness saves Low/Balanced/High, first-person, braking powder, tracks, low-angle drifts and a plain-material geometry view under `artifacts/snow_upgrade/`. Paired images confirm that sun-facing facets add visible highlights and the night image is unchanged when those highlights are disabled. Weather spindrift is hidden for these static comparisons because its independent animation would invalidate image differences. All playtests are unranked.

Limits: the 4 m contact grid resolves broad undulations; sub-metre grains/ripples remain shading detail. Ski grooves use optical recesses and raised lips without excavating collision terrain. Snow particles do not collide or accumulate, and worn tracks do not alter subsequent grip. These are local M4/Metal checks, not a claim about other hardware or subjective handling acceptance.

At 1440×900, Balanced, Legacy, clear midday, the final full descent averaged **8.333 ms/frame (~120 FPS)** versus 8.356 ms before. Final p95/p99 were 9.372/10.160 ms; 1% low was 97.50 FPS (before 96.76). Mean render CPU time was 0.749 ms versus 0.727 ms, with about three more draw calls. GPU timing was unavailable. Raw results are `artifacts/weather_benchmark_snow_before.json` and `artifacts/weather_benchmark_snow_after.json`; 120 warm-up frames and screenshot overhead are excluded. The course now differs, so this is a whole-run development-machine comparison, not an isolated shader benchmark.

Final integration checks: 72 runtime checks and 25 native graphics checks pass (24 headlessly, with GPU MultiMesh corner readback reserved for native rendering). Mountain and native Terrain3D suites pass, preserving every authoritative laboratory vertex through the scenery heightmap and Terrain3D import. Both rendered snow playtests pass with all three graphics qualities; the Terrain3D addon retains its pre-existing interpolation-reset deprecation warning.


## Ambient and contact lighting first increment

2026-09-06, native macOS / Apple M4 / Godot 4.7.2 / Forward+ Metal, Legacy terrain, actual rendered resolution **1440×900**. Low graphics, independent weather quality High (1,700 allocated particles). Unranked full autoplay descents exclude screenshots and the first 120 warm-up frames.

| Run | Average FPS | Mean frame ms | p95 / p99 ms | Slowest-1% mean FPS |
|---|---:|---:|---:|---:|
| Low clear, before | 120.0 | 8.333 | 10.058 / 10.411 | 95.4 |
| Low clear, after | 131.6 | 7.601 | 8.641 / 10.410 | 88.9 |
| Low snowfall, after | 120.0 | 8.333 | 9.370 / 10.405 | 95.5 |

The updated Low preset exceeds the approximately 60 FPS target in these clear and snowfall descents at this resolution. This does not establish performance at 1440p, every weather/time combination or on other hardware. The baseline and snowfall samples cluster near 120 FPS, while the updated clear run exceeds that rate; desktop/display pacing and brief headless tooling during the clear runs prevent attributing the difference to the lighting change. GPU timings are unavailable. These are budget checks, not proof of a speedup or an isolated SSAO-cost measurement. Balanced/High carry no MacBook FPS requirement and were inspected visually rather than benchmarked here.

All three descents finish in 57.431157 simulation seconds, peak at 142.818956 km/h, with no crash or airtime and identical course identity and mountain checksums. Raw reports are `artifacts/weather_benchmark_lighting_low_before.json`, `artifacts/weather_benchmark_lighting_low_after.json` and `artifacts/weather_benchmark_lighting_low_snowfall.json`.

`./godotw --headless --script tests/graphics_suite.gd` passes 24 checks, including repeated quality switching without changing the simulation, course geometry or record eligibility. `./godotw --script tests/ambient_lighting_playtest.gd` completes 34 native captures with no harness failures. Inspected before/after views and successive moving frames retain readable snow, trees, rocks and ski tips, including snowfall and twilight/night. No obvious broad contact-shading halos were seen in those views; the lighting difference is subtle. Screenshots do not establish subjective motion feel or universal freedom from temporal artifacts.

Captures and metadata are in `artifacts/ambient_lighting/`. `comparison.png` shows before on the left and after on the right: Low clear first person, Balanced clear chase, High snowfall chase, and Balanced night first person. The 120 Hz solver, course version and plugin/autoload configuration are unchanged.


## Local indirect lighting second increment

Native macOS / Apple M4 / Godot 4.7.2 / Forward+ Metal, Legacy terrain, **High at actual 2560×1440**, clear midday, High weather quality. Matched screenshot-free full descents toggle only SSIL through `tests/ssil_lighting_playtest.gd`; the first 120 render frames are excluded. The reports explicitly record SSAO on in both runs and SSIL off/on.

| Run | Average FPS | Mean frame ms | p95 / p99 ms | Slowest-1% mean FPS |
|---|---:|---:|---:|---:|
| SSIL off | 54.8 | 18.232 | 21.172 / 22.579 | 43.7 |
| SSIL on | 45.5 | 21.962 | 24.759 / 25.436 | 38.4 |

SSIL adds **3.73 ms** mean frame time in this pair (approximately 20.5%). This is a modest visual refinement with a measurable cost, so it is limited to High. High has no MacBook FPS requirement. Low and Balanced keep SSIL off; their lighting budgets are unchanged, and no new Low performance result is claimed. GPU timing is unavailable, and this sequential pair is not an isolated GPU measurement or cross-platform guarantee. Reported peak video memory rises from 1060.4 to 1142.8 MiB.

Both runs finish in 57.431157 simulation seconds and peak at 142.818956 km/h, without crash or airtime; course identity and mountain descriptors match exactly. Raw reports are `artifacts/weather_benchmark_ssil_high_off.json` and `artifacts/weather_benchmark_ssil_high_on.json`. The earlier exploratory `ssil_high_before` report lacks explicit lighting-state metadata and is not used for this comparison.

The existing headless graphics suite passes 24 checks. The final native SSIL harness completes 20 captures with no failures, including quality downgrades that disable SSIL after High has populated its history. Inspected SSIL-off/on pairs show a subtle local shading change rather than a major scene relight. The corrected rock camera clears the terrain; daylight, snowfall, twilight and night views retain readable terrain and obstacle silhouettes. Successive moving snowfall captures use no added settling frames and showed no obvious broad trails in the inspected samples. This short sequence does not establish freedom from artifacts in every turn, teleport or weather transition.

Final captures are in `artifacts/ssil_lighting/`; `comparison.png` has SSIL off on the left and on on the right, showing the nearby rock, clear chase view, snowfall first person and night first person. Physics, terrain generation and record compatibility are unchanged. SSIL remains a screen-space refinement, with limited visual benefit in open snow; larger GI and reflection changes remain separate increments.


## Terrain GI and Terrain3D removal

On 2026-09-06, the optional Terrain3D integration was removed at the user's request. Removed components: `addons/terrain_3d`, the renderer adapter and its custom shader, the shader exclusion branch, the backend selector, moving contact-patch handling, and the Terrain3D integration suite. Godot imports cleanly without the extension, with the existing MCP toolkit and its plugin/autoload entries intact. The benchmark's `legacy` terrain label remains for continuity. Prior Terrain3D measurements and captures are historical evidence, not a currently available backend.

The generated mountain data and authoritative laboratory meshes remain. After removal, headless suites pass **54 physics, 72 runtime, 6 mountain-data and 24 graphics checks**. No solver, course-generation or record-compatibility version change is required: this is a rendering/dependency change.

High now includes four-cascade SDFGI with 1 m minimum cells, half-resolution GI, occlusion and sky reading, 0.8 energy and 0.2 bounce feedback. The native SDFGI harness completed **23 captures**, with no failures, including High/Low/Balanced switching and unranked eligibility. Inspected daylight, nearby-rock, snowfall, night and moving views retain terrain/obstacle readability; indirect warmth and shaded-surface separation are visible but remain an approximation. Night terrain is darker. No obvious broad trailing was seen in the inspected moving samples; this does not rule out convergence or cascade artifacts across every camera trajectory.

The initial GI-only visual comparisons were captured while the unused Terrain3D addon was still installed, using Legacy throughout. Removal does not change that mesh path; the final rendered check and full descents below run after removal. Screenshots live in `artifacts/sdfgi_lighting/`, with GI off on the left and on on the right in `comparison.png`. Wind-driven vegetation and moving equipment/tracks receive GI without static contribution, so this pass does not establish canopy occlusion or dynamic-object GI. Cloud-shadow projection remains a direct-light effect.

Final full-descent measurements use Godot 4.7.2, native macOS / Apple M4 / Forward+ Metal and High weather quality. Samples exclude screenshot overhead and 120 warm-up frames. These are performance observations on one machine; High has no MacBook FPS requirement, and GPU timing is unavailable.

| Run | Pixels | Average FPS | Mean ms | p95 / p99 ms | Slowest-1% FPS |
|---|---|---:|---:|---:|---:|
| High, clear, GI on | 2560×1440 | 38.7 | 25.871 | 32.241 / 34.669 | 27.3 |
| Low, snowfall, GI off | 1440×900 | 119.8 | 8.346 | 9.277 / 10.431 | 84.3 |

Low remains above the approximately 60 FPS MacBook target in this full snowfall descent at 1440×900. Its report confirms SSAO, SSIL and SDFGI are all disabled. This does not establish Low performance at every resolution or weather/time combination. High's increased GPU work is intentional; it is not held to the Low target.

Both final descents finish in 57.431157 simulation seconds, peak at 142.818956 km/h, and have identical course identity and mountain data, with no crash or airtime. Raw reports are `artifacts/weather_benchmark_sdfgi_high_final.json` and `artifacts/weather_benchmark_sdfgi_low_final.json`. High reports about 1,504 MiB peak video memory; Low about 648 MiB. These different resolutions/qualities are not an isolated GI-cost comparison.

The final `tests/graphics_playtest.gd` run after removal completes eight native captures: four skier poses, all three graphics qualities and the settings panel. The High capture was inspected and renders the complete terrain, backdrop, skier and trees without missing-extension errors. Its short post-switch settling period produces darker GI than the 90-frame settled comparisons; a visible convergence period after enabling High remains a limitation. This is documented rather than claimed to be a seamless quality transition.

## In-world open-route race creation and sharing

2026-09-06, Godot 4.7.2, native macOS / Apple M4 / Forward+ Metal. The new authoring flow passes **51 headless race checks** and **52 rendered race checks** (the extra check exercises the system clipboard). Existing suites pass **54 physics and 72 runtime checks**. The unchanged benchmark still completes in 57.431157 simulation seconds with a 142.818956 km/h peak and no crash or airtime.

The race suite covers schema/version/type/bounds/obstacle validation, code round trips, isolated persistent personal bests, unranked exclusion, swept finish entry from five horizontal directions and vertically, high-speed passage through the entire target, invalid near/above misses, camera ray selection on the physical snow surface, frozen authoring state, local save/reload, import/deduplication, custom spawn/retry, and an authored race completed with the actual ski solver. A recipient library imports the portable definition independently. A different playable seed (12981) and scenery seed (78342) are then reconstructed through the real scene transition, followed by a return to the original benchmark terrain. Disposable test directories are removed; the user's benchmark record is checked before and after and remains unchanged.

Native **1440×900, Low graphics** captures were inspected for creation, saved/shared race controls, chase-view racing, and finish. The creator and library fit inside the viewport; the surrounding snow remains selectable, both endpoint labels are readable at survey and racing distances, the benchmark corridor markers are hidden for custom races, and the completion view shows the finish reached. The panel can scroll on shorter viewports. Captures: `artifacts/race_create.png`, `race_saved.png`, `race_racing.png`, `race_finished.png`; machine-readable results: `race_results.json` and `race_results_rendered.json`.

A local micro-measurement in the final native harness averages **0.542 µs per finish intersection** across 10,000 queries and **38.34 µs per snow pick** across 100 queries. Snow picking runs only while authoring; the rider is paused. These numbers measure the small new CPU operations, not whole-frame performance. The capture harness includes startup, synchronous test work and scene reloads, so its transient FPS HUD is not a gameplay frame-rate measurement. Existing full-descent Low performance measurements above remain separate evidence; no new universal frame-rate or hardware-control claim is made.

Authoring is keyboard/mouse, sharing is local copy/paste text, and the playable terrain remains the bounded laboratory. Endpoint validation does not prove route reachability; there is no online discovery, anti-tamper validation, checkpoint editor or ghost system. See [RACES.md](RACES.md) for the contract and player workflow.

## Milestone 5 — local competitive loop

2026-09-06. Final headless suites pass **54 physics, 72 runtime, 51 race-authoring and 64 competitive checks**. The competitive checks cover a first PB, a faster PB replacing its ghost, slower runs preserving it, bounded history, schema-1 migration, save failures, replay metadata/ordering/input validation, precise final samples, first-passage splits, pause/resume and restart, custom-race retention through workbench/history/library transitions, ghost independence, and exclusion of crashes/lab/automated attempts. Both legacy and new user benchmark files remain unchanged; test records use disposable directories.

The default fully tucked benchmark still completes in **57.431157 s**, peaks at **142.818956 km/h**, and has no crash or airtime. Its new PB ghost and splits round-trip through the same competitive persistence path as authored races. This pass does not change the ski model or benchmark identity.

Native rendered inspection covers six captures at 1440×900: title controls, history, chase ghost, first-person ghost, a new personal best and its split comparisons. The cyan silhouette is readable in both cameras and does not obscure the player when overlapping. PB/result/history controls stay within the viewport. A real simulated improvement from **21.919 s to 19.759 s** displays **−2.160 s** against the prior best, with each split retaining that prior comparison. The new PB becomes the next attempt's ghost. Captures are `artifacts/competitive_*.png`; results are `competitive_results.json` and `competitive_results_rendered.json`.

### Low graphics — full snowfall descents

Apple M4 / native macOS / Godot 4.7.2 / Forward+ Metal, actual **1440×900**, **Low graphics**, independent weather quality **High**, snowfall, daylight. Both profiles traverse the full benchmark, including its forests. They use fixed 90% tuck so the fully tucked PB can appear ahead. The rider remains unranked; a separate discarded recorder measures normal capture work without saving a result. The first 120 rendered frames and screenshots are excluded from each timed descent.

| PB ghost | Average FPS | Mean frame ms | p95 / p99 ms | Slowest-1% mean FPS |
|---|---:|---:|---:|---:|
| Off | 86.5 | 11.567 | 14.636 / 15.982 | 59.9 |
| On | 89.0 | 11.242 | 13.185 / 14.801 | 65.2 |

Both finish in **59.605409 s** with identical fixed input and no crash; that time differs from the default benchmark because tuck is 90% rather than 100%. The ghost-enabled run stays within the approximately 60 FPS Low budget in this configuration, including its p99 and slowest-1% measurements. The slightly faster second run is not evidence that the ghost improves performance: ordered runs, warmed resources and desktop pacing can differ. This is a budget check on one machine/resolution/weather setup, not a guarantee for other devices, resolutions or every race. No GPU timing or real-controller claim is made.

The final native harness measured about **2.45 µs per snapshot lookup** across 10,000 queries. Ghost meshes have no shadows, GI, collision, particles or audio. Recording is bounded to ten minutes; playback uses saved transforms rather than re-simulating physics. The capture harness's transient FPS labels include synchronous setup/testing and are not the performance measurements above.

Raw full-descent data is `artifacts/competitive_profile.json`. Reproduce with `./godotw --script tests/competitive_suite.gd -- --profile-full-competition`. See [COMPETITIVE_LOOP.md](COMPETITIVE_LOOP.md) for the data contract, controls, migration and remaining limitations. The complete generate/discover/create/compete/share product loop still depends on the future general playable-mountain milestone; these competitive features work now on the benchmark and locally created laboratory races.

## Physics-driven articulated skier — 2026-09-06

Model v5 and replay format v2 now drive the whole-body pose from independent ski
supports and a reduced articulated COM/inertia balance solver. Crashes use the
fifteen-body Jolt skeleton. The local export has closed pole grips and independent
clothing/helmet/lens controls. All **304 checks across eight suites pass**;
`artifacts/advanced_rider/validation.json` indexes the exact evidence. The additional
150 km/h crash run also passes its nine checks.

The full Low/snowfall descent on M4/Metal at 1440×900 measured ~120 FPS mean,
93.2 FPS slowest-1% mean, p95 8.54 ms and p99 8.71 ms. It finished in 57.495 s
at 142.59 km/h peak with no crash. This is the tested resolution, not a general
claim for every display size or device. GPU timing was unavailable.

See [the model, validation and deliberate limits](SKIER_PHYSICS.md), and
`artifacts/advanced_rider/skier_physics_preview.mp4` for the rendered motion/grip/
crash preview. The 4 m terrain/contact approximation, fixed lateral ski stance,
crash self-collision exclusion and retained equipment are documented there.

## Turning anatomy, knee tracking and lag — model v6

2026-09-06. All **359 checks across ten suites pass**, including 32 turning
anatomy checks and 20 attachment checks. Full steering, high speed, reversals,
cross-slope travel and extreme lean before crash handoff retain fixed leg
lengths, the shared pelvis and sub-millimetre boot attachment. The formerly
outward-splayed knees now track within 1 cm of each boot centerline in upright,
half-tuck and full-tuck regression poses. Native turns and both physical crash
handoffs were visually inspected; `artifacts/turn_anatomy/turns_v6.mp4` is the
updated preview. Deliberate sustained overload can still cause a real fall.

The changed balance/contact behavior uses physics model v6; older model times
and ghosts are not compared. Test/lab runs remain unranked, and competitive
checks confirm the user's legacy and current benchmark files are untouched.
`artifacts/turn_anatomy/validation.json` contains source hashes, suite results,
knee comparison measurements and the full performance reports. The background
CPU process diagnosis and reduced-model limitations are documented in
[SKIER_PHYSICS.md](SKIER_PHYSICS.md#validation--model-v6).

The final full-descent measurements use Apple M4 / macOS / Godot 4.7.2 /
Forward+ Metal, **1440×900 actual pixels**, snowfall with High weather quality
(1,700 particles), and no screenshot capture. The first 120 frames are excluded.

| Graphics | Average FPS | Mean ms | p95 / p99 ms | Slowest-1% mean FPS |
|---|---:|---:|---:|---:|
| Low | 115.1 | 8.691 | 12.419 / 13.472 | 65.2 |
| Balanced | 91.6 | 10.913 | 14.918 / 15.681 | 57.6 |

Both runs finish in 57.4876 s at 142.578 km/h peak with no crash or airtime.
Low meets the approximately 60 FPS target in this configuration, including its
slowest-1% average. Balanced has occasional slower frames and is not held to the
Low target. GPU timing is unavailable; these sequential desktop measurements
are not a controlled attribution of frame-time changes to one code edit.
Raw reports are `artifacts/weather_benchmark_turn_anatomy_low.json` and
`artifacts/weather_benchmark_turn_anatomy_balanced.json`.

## Handling and balance — model v7

The model-v7 handling change passes 56 physics, 72 runtime, 84 handling,
32 turning-anatomy, 19 articulated-motion, 51 race and 64 competitive checks.
Logs and measurements are in `artifacts/handling/`.

The new handling suite covers both directions at 30, 60, 90, 120, 150 and
200 km/h: four-second held turns, release and repeated reversals. It also checks
that a sustained reversal changes actual travel direction, cross-slope turns,
and two-second turns from 120 km/h at z=250, 500 and 900 m on the real mountain.
Every case stays recoverable. Runtime screen-direction fixtures now begin with
velocity aligned to the skis, isolating input response from the speed lab’s
pre-existing cross-slope slip. A 30° skid at 100 km/h loses about 7.7 km/h more
than aligned gliding after one second, while a sustained broadside slide still
loses an edge. A 12° error is forgiving at 200 km/h; a 20° error still costs
balance. Initial speeds evolve naturally in all these fixtures.

The straight tucked benchmark finishes in approximately 57.470 s, peaks at
142.7 km/h and stays in contact. Engine/model/tuning compatibility and benchmark
identity now separate older results and ghosts. Tests use isolated records.

The native Low-quality Metal playtest captures held turns and reversals in both
directions from 120 km/h on the mountain. All four fixtures remain unranked and
complete without a crash. Twelve captures are in `artifacts/handling/visual/`;
inspection covers bank, knee alignment, equipment attachment and the return
through an upright stance. These scripted captures do not establish subjective
controller feel or a full-descent MacBook FPS result.


## Tighter high-speed turns — model v9

2026-09-06, Godot 4.7.2. The target bank blends from 48.7° at 30 km/h to
56.1° at 60 km/h, with the existing balance response and physical support limits.
The eight headless suites pass **686 checks**: 56 physics, 72 runtime,
84 handling, 219 high-speed balance, 108 harder-turn comparisons/recovery,
32 turning anatomy, 51 race and 64 competitive. Evidence and source hashes
are in `artifacts/high_speed_turns/validation.json`.

The new `tests/high_speed_turns_suite.gd` compares the final tuning against the
model-v8 bank limit on a 25° plane. From 120/160/200 km/h, upright two-second
turn radii fall from 103/143/182 m to 80/112/143 m (21–22% tighter). Entry
speeds evolve freely; after two seconds, the new and previous exit speeds differ
by less than 1 km/h. Four-second turns redirect travel about 25% farther and
cost another 3.6–4.7 km/h. Both directions, initially tucked turns, release and
reversal after a two-second committed turn remain recoverable. Existing suites
retain gentle analogue corrections, repeated keyboard taps, actual terrain,
passive energy, obstacle/landing failures and cuff/attachment checks.

The native Low-quality Metal harness completes six two-second hard turns on
actual laboratory snow from 120/160/200 km/h, in both directions. All six remain
unranked and finish without a crash, with minimum final balance above 0.98.
Twelve captures in `artifacts/high_speed_turns/visual/` cover the one- and
two-second poses; inspected captures show bank, connected knees/boots and skis.
These scripted captures do not establish subjective controller feel or a
full-descent hardware frame-rate result. Terrain can carry actual body roll
past its target limit. Hard turns still cost momentum and obstacles still crash.

Benchmark identity is `laboratory-v3-physics-v9-default`; custom race identities
and ghost compatibility also include model 9. Older records are kept separate.
The straight tucked benchmark retains its approximately 57.506 s reference.

## Player-generated mountains — 2026-09-06

The bounded `alpine-drainage-v1` generator, seed/name/library controls, compact mountain files and generated race references are implemented. The original laboratory's 56 physics checks and 72 runtime checks pass; the laboratory descent reproduces the pre-change time and trajectory. Race and competitive regressions pass 51 and 64 checks. The six-seed generator suite passes 83 checks, including physical spawn behavior, triangle agreement, connectivity, frozen fingerprints and file/race round trips. The native library suite passes 21 checks and captures actual UI, file dialogs, terrain and scene reloads without writing personal bests.

A full generated eastern descent at Low / 1440×900 / snowfall, Apple M4 / Metal, averages 8.334 ms (~120 FPS), with 9.674/10.524 ms p95/p99 and 85.7 FPS for the slowest-1% mean. It finishes without crashing in 126.042 simulation seconds using test-only ordinary steering/braking input and a fixed initial heading. The western exploratory pilot still hits a rock; route planning and player assessment across seeds remain necessary. These measurements support the Low target only for the tested route, speed, device and configuration. See [MOUNTAINS.md](MOUNTAINS.md) and `artifacts/mountain_generation/` for contract, commands, reports, visual evidence and limitations.


## Faster generated mountains — drainage v2, 2026-09-06

The v2 generator shortens the entry, raises sustained face pitch to a nominal 33–37°, adds broad rolls/compressions and a wide optional snow lip, and clusters hazards around shoulders and rock bands. Six seeds provide 1,107–1,205 m of vertical and reach 78–85 km/h after ten seconds of ordinary tuck input. The exact v1 implementation remains available for existing mountains and races; new bare seeds select v2 and copied seeds include their version. No ski solver, gravity, drag or equipment tuning changed.

On example seed 849205174, the test pilot completes both bowl entries at 151.25 / 154.20 km/h peak in 62.0 / 63.6 s. The west attempt stays grounded; the east logs 0.87 s airtime and lands without a crash. These runs use ordinary steering and 0.75 tuck, with no braking or speed cap. On v1 the same pilot reaches about 42 km/h after ten seconds, versus 78–80 on v2; those v1 runs eventually hit hazards, so their elapsed time is not a valid completion-time comparison. Expert drops still require speed and balance control, and not every exploratory unbraked seed attempt succeeds.

The screenshot-free eastern descent at Low / 1440×900 actual pixels / snowfall with High weather, Apple M4 / Metal / Godot 4.7.2, averages **8.333 ms (120.0 FPS)**, **9.842 / 10.909 ms p95 / p99**, and **84.0 FPS slowest-1% mean**, after 120 warmup frames. The previously open game was temporarily suspended for isolation and resumed afterward. Separate inspected native captures include terrain, the library and file dialog, high-speed skiing and the jump. Capture-run FPS includes another game rendering concurrently and does not describe isolated performance.

Checks pass: **96 generator, 25 library (headless and native), 56 physics, 72 runtime, 51 race, 64 competitive, 6 scenery**. Terrain and obstacle budgets remain unchanged in size, while the example uses 156 collidable obstacles. Old generation/race identity and personal bests are preserved. Reports are in `artifacts/mountain_generation_v2/`; commands and limitations are in [MOUNTAINS.md](MOUNTAINS.md#steeper-v2-validation--2026-09-06).


## Jump/contact model v10 and drainage v3 — 2026-09-06

`tests/physics_suite.gd` passes 56 checks; `tests/runtime_suite.gd` passes 72.
`tests/jump_suite.gd` passes 90 checks, including all 42 real-solver feature
trials: six default-seed features at 90/130 km/h entry, plus the same six on
seeds 0, 1, 42, 12981 and 2147483647 at 110 km/h. Every tested approach produces
natural airtime and lands without a crash. This finite sweep does not establish
safety for arbitrary headings, speeds or seeds. The 22 m feature on the example
seed gives about 3.05–3.25 seconds of continuous flight before a sloped landing.

The existing high-speed balance matrix passes 219 checks, ski attachment 20,
skier motion 19, race lifecycle 51, generated mountain contracts 100, and mountain
library/lifecycle 27. The latter verifies that free skiing continues beyond the
old 1,740 m basin and finishes at 3,480 m, scene reloads preserve settings, v1
mountains reconstruct unchanged, and personal best files remain untouched. The
generator suite pins both archived v2 and new v3 physical fingerprints and checks
that the new grid has four times the old area. Decorative mountain checks pass.

The full descent pilot reaches the enlarged basin from both entry biases without
crashing, using ordinary test-only steering/tuck intent. It does not change the
solver's positions, velocities or collisions after initialization. Default-seed
peak speeds remain about 158–161 km/h. These routes are evidence of a playable
end-to-end descent, not a claim of optimal racing lines or universal seed quality.

Reproduce with `./godotw --headless --script tests/jump_suite.gd`,
`./godotw --headless --script tests/mountain_speed_playtest.gd -- --both-routes`,
and `./godotw --script tests/jump_playtest.gd`. New numerical reports and native
captures live under `artifacts/jump_upgrade/`. The native harness uses real
120 Hz steps, captures multiple flight poses, Space hops, physical cliffs and the
mountain survey, and keeps the session ineligible for PBs. The bounded terrain
remains a heightfield: steep faces have no overhangs. Construction remains
synchronous; no streaming or alternate terrain renderer was added.


All six final native feature runs and the Space hop land without crashes. The
captured flight poses and survey were inspected at 1440 × 900. An initial Low /
Clear / Apple M4 / Metal capture run measured 10.26 ms mean, 10.13 ms p95 and
16.95 ms p99, before the final contact-footprint and feature-position refinements.
That earlier report is preserved as `performance_initial.json`.

**Final-build FPS verification remains pending with an unlocked Mac.** The final
capture and screenshot-free runs contained repeated approximately 1-second frame
stalls; Computer Use confirmed the Mac was locked and could not foreground the
game. Their means must not be reported as a valid Low gameplay benchmark. No
system lock, power or security settings were changed. Re-run
`./godotw --always-on-top --script tests/jump_playtest.gd -- --timing-only` while
the Mac is unlocked. This fixture measures six real jump approaches/landings with
the HUD hidden, warmup excluded, and no screenshots during timing; it writes
`artifacts/jump_upgrade/performance.json`. Other weather/resolution conditions
and sustained full-descent performance still require their own measurements.


## Full summit mountains — generator v4, 2026-09-06

New seeds construct a **6,144 × 6,144 m** physical mountain at 4 m spacing: 2,362,369 vertices, 4,718,592 base triangles and 576 chunks. The six-seed sweep verifies the highest vertex is the free-ski spawn, all eight initial compass directions launch with the real solver, and downhill connectivity reaches the base in all octants. Vertical is approximately 2,001–2,122 m. V1–v3 terrain and race recipes remain reconstructable from their archived implementations.

Free skiing waits at the summit for A/D/left-stick heading selection, then W/Enter/right-trigger chooses a nearby rim with zero velocity. No movement force or line attraction is added. Completion/progress are radial; authored races use their own finish. The library runs data generation/reconstruction in a worker thread, and the renderer uses edge-preserving distant LOD indices over unchanged authoritative triangles. The race survey, zoom and snow picking cover all quadrants. Tests confirm input staging, north-face progress, all-side completion, remote picking, file/name/version round trips, reloads and PB preservation.

All eight example compass entries reach the base using ordinary test steering/tuck and braking for the lower forest. The south-entry native run finishes in **117.308 s**, peaks at **163.50 km/h**, and logs **0.68 s airtime** without crashing. Fully unbraked exploratory south/south-west attempts hit the same tree; the final test pilot brakes above 100 km/h in the lower forest. This pilot is not shipped assistance and does not cap player speed.

The final isolated native run on **Apple M4 / Godot 4.7.2 / Metal, Low, 1440×900 actual pixels, snowfall / High weather** averages **119.9 FPS (8.340 ms)**, **9.396 / 10.624 ms p95 / p99**, and **82.5 FPS slowest-1% mean**. It excludes 120 warmup frames and contains 14,065 measured frames, with no screenshots during timing. The completed-descent image is captured afterward. This supports the Low target for the measured configuration. A startup-overlap measurement is archived separately and not used for this conclusion.

Passes: **56 summit, 37 library, 100 archived-generator, 56 physics, 72 runtime, 51 race, 64 competitive and 6 scenery checks**, plus the retained jump suite. Inspected native PNGs show summit selection, whole mountain, library, opposite faces and completed descent. The implementation remains one bounded radial landform family with synchronous world-mesh loading; it does not certify every seed, line, platform or subjective handling preference. See [MOUNTAINS.md](MOUNTAINS.md) and `artifacts/summit_mountain/` for contracts and evidence.

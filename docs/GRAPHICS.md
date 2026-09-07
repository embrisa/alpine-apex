# Graphics and generated mountains

The [golden sunlight update](GOLDEN_SUNLIGHT.md) warms the existing noon sun, coordinates filmic exposure and surface response, and adds High-only nearby shadowed shafts plus restrained highlight glow. It preserves the noon direction, terrain and PC defaults. Its fresh acceptance evidence is reported separately from the earlier PC environment measurements below.

The PC graphics upgrade adds selective 4K snow, rock and bark, nine rebuilt conifers, six angular rocks, directional impostors and persistent rendering controls. Technical Showcase v7 uses the new treatment on a versioned south face; shared assets and lighting apply throughout the game. The earlier [scenery library](SCENERY.md) remains available, with spruce/fir/pine and rock selections now mapped to the PC assets. Ski physics remains an independent 120 Hz solver. Graphics preferences do not change record eligibility or physics identity. See [implementation and acceptance](PC_ENVIRONMENT_IMPLEMENTATION.md) for final captures, measurements and limitations.

## Performance policy

As of 2026-09-07, target **Ryzen 5 5600X / RX 9070 / 16 GB RAM**, **3840x2160 output** and **90-120 FPS**. Aim for steady-state p95 <= 11.1 ms and p99 <= 16.7 ms. Demanding sections may favor fidelity. The MacBook requirement is removed; older measurements below are historical evidence. The ski simulation remains independent at 120 Hz.

**High is recommended:** 75% FSR2 (2880x1620 internal at 4K output), 120 FPS cap, SSAO and restrained SSIL, SDFGI initially off. Native rendering and exact two-thirds scale (2560x1440 internal) are available. No dynamic resolution is used. FSR2 supplies temporal antialiasing, so additional MSAA/TAA are disabled in that mode; native uses 2x MSAA. The HUD remains at output resolution. See [Godot resolution scaling](https://docs.godotengine.org/en/stable/tutorials/3d/resolution_scaling.html).

Visual Settings persists display mode, upscaler, render scale, frame cap, quality and the advanced terrain GI override in `user://graphics_v1.cfg`. Restart and mountain changes preserve them; they never enter recipes, physics tuning, replay identity or ranked eligibility. Automated/script runs use isolated defaults and never write this preference file. Windows benchmarks use an exact-size borderless/fullscreen window and verify the rendered image dimensions, fixing the earlier 3856x2176 result for a 3840x2160 request.

Run `./scripts/benchmark_pc.ps1 -Label v7_high_clear -Side -1 -Weather clear` on Windows. It performs a screenshot-free complete descent after warmup, records actual output pixels and internal dimensions calculated from the viewport's active scale, CPU/GPU timings, frame percentiles, slowest-1% FPS, draw calls, engine video memory and process/system RAM. Generation/import costs are reported separately. Existing applications remain untouched and background presence is sampled. The user removed the WoW requirement for the golden sunlight comparison; earlier measurements with WoW running are historical, different workload conditions.

Equivalent game arguments are `--display-mode=fullscreen|windowed`, `--upscaler=fsr2|native`, `--render-scale=0.75`, `--fps-limit=0|90|120|144`, `--terrain-gi=off|on`, `--graphics-quality=low|balanced|high` and benchmark `--benchmark-resolution=3840x2160`. Quote the user-argument separator in PowerShell: `./godotw.ps1 --script tests/technical_showcase_playtest.gd '--' --views --benchmark-label=review`.

## Terrain architecture

`scripts/world/mountain_data.gd` produces an 8.192 km square landscape from a scenery seed. It constructs ridges, saddles and drainage-like gullies, then exports a float32 height image and an RGBA environment image: snow coverage, rock exposure, vegetation suitability and wind exposure. This is a procedural landform model, not a hydraulic erosion simulation. A 32 m construction grid supplies the surrounding mountains; resampling it to the 4 m renderer grid does not create additional geological detail.

All 99,009 laboratory vertices are copied exactly into the height image. A 64 m decorative apron blends its perimeter. The selected physical surface (the original `TestSlope` or `alpine-drainage-v1` generated basin) remains the authority for simulation, ski contact and obstacle collisions. The generated mountains outside that area are scenery and cannot be skied yet.

The data descriptor records generator version, seed, extent, cell size, engine version and SHA-256 checksums of heights and environment masks. `--mountain-seed=638201943` changes scenery independently of the benchmark. Reproducing these checksums on other platforms still requires verification; future sharing must retain generator/dependency versions and account for user edits.

The built-in chunk renderer is the sole terrain path. Terrain3D and its addon, adapter, custom clipmap shader and integration suite were removed on 2026-09-06: the bounded-course comparison did not establish a benefit worth maintaining a second renderer. Historical benchmark results remain in `VALIDATION.md` and `artifacts/`. The Godot MCP toolkit and plugin/autoload configuration are preserved.

The laboratory renders the authoritative 4 m triangles directly; the decorative backdrop uses the same mountain data at a coarser spacing. No clipmap exclusion mask or moving replacement patch remains. Terrain materials retain world-coordinate snow/rock shading and the shared cloud-light field. Only laboratory terrain casts directional shadows; decorative mountains can contribute to SDFGI without expanding the sun's shadow-map caster budget.

### Surface variation

`assets/graphics/terrain_sampling.gdshaderinc` blends three independently offset, rotated and scaled patches on a triangular lattice. Snow has a limited rotation range to retain a wind-shaped appearance; rock can rotate through a full circle. All color, roughness, occlusion and normal samples share each patch's coordinates and blend weights. Sampled normal slopes are transformed back into the surface plane. Explicit texture gradients preserve mipmaps and anisotropic filtering across patch boundaries, and cubic blend weights soften the joins without averaging away most of the texture contrast.

Warped fields add irregular snow drifts, broad stone tint variation and broken snow/rock transitions. Stone is desaturated and tinted charcoal/slate. Additional rock exposure blends in 64–320 m outside the laboratory perimeter, exposing more mountain faces while retaining snow on gentler shoulders and the course. Elevation contributes to the broad field so cliffs do not inherit vertical stripes from horizontal-only noise. These fields are fixed in world metres and do not animate or restart at terrain chunk boundaries. The shared shader covers the ski slope, decorative mountains, boulders, the terrain renderer and all three graphics presets. These material fields reuse the existing CC0 maps and alone do not change heights or collision. The generator v3 snow relief and model v4 contact changes described below separately change terrain, handling and benchmark identity.

Blending costs extra texture reads. Negligible triplanar projections are removed before renormalization; normals fade out over 35–180 m and roughness/occlusion detail fades over 100–180 m. Fully exposed rock skips snow sampling, and random patch directions use normalization instead of trigonometry. Snow normal and ORM maps use ordinary mip filtering to bound grazing-angle sampling cost; albedo and rock maps retain anisotropy. This softens fine snow relief in the distance while retaining the broader drift variation. The underlying landscape is still a coarse decorative heightfield, and the limited tree and boulder mesh variants can still recur. This change reduces surface texture repetition rather than adding new landforms or asset silhouettes.

### Snow relief, crystals and imprints

Laboratory generator v3 now sculpts the actual snow heightfield with warped wind ridges, smaller scallops and uneven mounds. Heights are shared by rendered vertices, collision and obstacle placement, and copied into decorative mountain generator v2. The existing terrain mesh budget is retained. Main drift amplitude is 1.15 m, with smaller 0.18 m scallops and a seeded mound field. Longitudinal variation is gentler than cross-slope relief to retain useful racing contact.

The snow material adds stronger scanned relief and shallow wind ripples in the lighting normal, fading over 12–65 m. World-anchored crystal facets reflect the actual sun/view angle. Footprint filtering removes subpixel grains; there is no animated noise or emissive glitter. The shared directional-light function applies geometry shadows and cloud transmission to the crystal response and disables it below the sun horizon. `snow_sparkle_strength` controls highlight strength. The terrain renderer and all graphics presets use the same shader.

`presentation/snow_tracks.gd` replaces isolated flat stamps with continuous paired ribbons. The fixed 800-instance MultiMesh uses a 64-triangle cross-section per ribbon, and four corner heights conform it to the contact surface. Compressed centers have different roughness, shallow optical recesses and broken, physically raised snow lips. The shader's detail is anchored in world coordinates, avoiding a repeating stamp pattern. The track center remains just above the sculpted terrain; these are visual grooves, not excavated collision geometry. Tight turns can overlap impressions, and a wrapped ring can remove nearby older marks when revisiting an area. Visibility fades before typical distant ring replacement.

Powder puffs and smaller grains share the original 380-particle allocation across four emitters. They use different gravity and drag, take intensity from the ski solver, and receive the world's sun/cloud lighting. No CPU particle simulation, terrain queries per particle, or new texture assets are required. Physics model v4 separately adds the loose-snow resistance described in `ARCHITECTURE.md`.

Run `./godotw --script tests/snow_playtest.gd`. Captures under `artifacts/snow_upgrade/` include carving, braking powder, close grooves, all three qualities, first person, sun-facing crystal on/off pairs night, and a low-angle plain-material view that exposes the actual geometry. The native graphics suite checks uploaded imprint corner heights; the headless dummy renderer cannot read back that MultiMesh data.

## Assets and editable sources

Current PC environment assets:

| Asset | Runtime detail | Editable source |
|---|---|---|
| Spruce, fir and pine | Three silhouettes each; 16,580-28,004 near / 6,821-11,659 mid triangles; one surface | `art_source/blender/pc_environment/pc_environment.blend` |
| Directional conifer impostors | Eight views per tree, two triangles, 4096x512 atlas and 2048x256 derivative | Same Blender source and `scripts/art/build_pc_environment.py` |
| Fractured rocks | Two buttresses, two ledges, two boulders fitted to the existing obstacle envelope | Same Blender source |
| Scanned snow, rock and bark | CC0 4K High maps; existing 2K/1K derivatives; compression and mipmaps | `art_source/pc_texture_sources.json` |

Dimensions, material masks, LODs and hashes are recorded in `art_source/pc_environment_manifest.json`. The PC ledger is separate from earlier allowances: **0 of 1500 credits spent**, first batch ceiling 300. No PC asset purchase or generation was required.

Retained assets and earlier authoring history:

| Asset | Runtime detail | Editable source |
|---|---|---|
| Skier | 36,950 body triangles, 24 bones | `art_source/blender/skier_v7.blend` |
| Equipment | 5,171 generated boot triangles + 992 for skis, bindings and poles; complete rider 43,113 | `art_source/blender/skier_v7.blend`, `art_source/blender/alpine_library.blend` |
| Spruce | Three crown derivatives; approximately 18k / 6.5k triangles near/mid; baked far cards | `art_source/blender/spruce_library.blend` |
| Far spruce | Three albedo silhouettes, two triangles per tree | `art_source/blender/spruce_impostor_bake.blend` |
| Expanded trees | Ten additional families, four shapes each; 6–14k near / 1.8–5k mid / two-triangle far cards | `art_source/blender/<family>_family.blend` |
| Expanded rocks | Six fractured families × four shapes, plus two rounded erratics | `art_source/blender/<family>_family.blend`, `round_boulders.blend` |
| Original boulders / scrub | Three retained earlier rocks and two small cutout plants | `art_source/blender/alpine_library.blend` |
| Earlier authored ridges / trees | Retained for reuse and comparison | `art_source/blender/alpine_library.blend` |

The 10.5 m spruce source is centered on its trunk and fitted within the existing trunk footprint. Existing obstacle scales, rotations and positions are consumed unchanged. Regional MultiMeshes share meshes and materials. Spruce needles are modeled clusters; scrub and distant trees use alpha-cutout foliage. Nearby crowns have small shader motion that stops on pause. The far cards use albedo-only bakes so weather, cloud shading and fog remain dynamic.

The active [Meshy 7 skier](SKIER.md) replaces the earlier selected Meshy candidate with cleaner clothing, helmet, goggles and separate textured boots. Its 24-bone skeleton retains simulation-driven skiing poses, with a straighter tuck and damped arm/pole follow-through. The old model and source remain available. First person hides the body while retaining ski equipment. Physics is independent of this visual model. Generated fingers have an approximate pole grip; extreme crash poses and cloth deformation remain refinement areas.

Raw and optimized renders and generated GLBs are retained under `art_source/meshy/`; editable scenes and round-trip checks live under `art_source/blender/`. Runtime exports live in `assets/graphics/`. Eleven additional standalone GLBs with embedded textures are in `art_source/reusable/`: three boulders, two scrub variants and six near/mid spruce models. Their manifest records hashes, dimensions, materials, triangles and successful reimports. The runtime skier and equipment GLBs are already self-contained. Godot adds dynamic snow/exposure shading to those base PBR materials.

`spruce_qa.json` includes an earlier mesh-based far LOD; `impostor_qa.json` and the final runtime manifest supersede that far geometry with two-triangle cards. Blender sources contain packed images for portability, verified in `packed_sources.json`. `art_source/.gdignore` and `artifacts/.gdignore` keep authoring files and QA captures out of engine asset imports.

The original graphics upgrade spent **125 credits**, with **875 credits remaining in the authorized allowance**. All nine original operations completed successfully. Their task IDs, prompts and costs are in `art_source/meshy/credit_ledger.json`. The later Meshy 7 skier spent **40 of a separate authorized 1,000-credit allowance**; its ledger is `art_source/meshy/skier_v7/credit_ledger.json`.

Snow 02, Rock Face 03 and Brown Bark 02 textures come from Poly Haven under CC0. Download URLs and checksums are recorded in `art_source/texture_sources.json`. Meshy source textures and generated task history are retained separately. No Fab or SpeedTree assets were purchased or incorporated.

## Quality settings

Use **Visual settings → Graphics quality**, or `--graphics-quality=low|balanced|high`. Weather-effects quality is independent. Profiles currently last for the application session and survive restart.

| Setting | Low | Balanced | High |
|---|---:|---:|---:|
| Snow, rock, bark texture size | 1K | 2K | 4K |
| Other environment texture size | 1K | 2K | 2K |
| Near tree transition | 40 m | 70 m | 95 m |
| Far-card transition | 135 m | 220 m | 280 m |
| Tree visibility end | 700 m | 1,000 m | 1,300 m |
| Scrub distance | 45 m | 85 m | 130 m |
| Scrub density | 45% | 100% | 100% |
| Directional shadow range | 100 m | 170 m | 220 m |
| Sky contribution to ambient | 42% | 42% | 42% |
| Contact SSAO | Off | On | On |
| Local indirect lighting (SSIL) | Off | Off | On |
| Terrain indirect lighting (SDFGI) | Optional, default off | Optional, default off | Optional, default off |
| Nearby volumetric sun shafts | Off | Off | 120 m, shadowed, daylight/cloud gated |
| HDR highlight glow | Off | On, daylight gated | On, daylight gated |

Tree batches cover 128 m regions. PC conifers use a 20 m opaque dither transition around each region centre; legacy families use 12 m hysteresis. Transition distances therefore describe batch bounds, not an exact per-tree radius. Some LOD popping remains. PC far cards blend eight directional atlas views and lose three-dimensional parallax. Neither decorative quality nor visibility changes obstacle collision. Snow tracks use a fixed 800-instance ring; spray and precipitation remain bounded.

## Ambient and contact lighting — first increment

The world blends a 42% sky contribution with the existing weather/daylight ambient fill. This gives lighting some dependence on surface orientation while retaining readable shade and night snow. The existing sun/moon cascaded shadows, tone mapping and fog remain in use. Sky lighting uses the existing radiance map and its inexpensive cloud-free cubemap branch; it is an artistic outdoor approximation, not terrain-aware bounced GI.

Balanced (Medium) and High enable restrained SSAO with a 0.65 m radius, 1.2 intensity/power and 0.35 detail. It affects indirect lighting only (`ssao_light_affect = 0`) and does not additionally multiply the material AO channel. Low disables SSAO. `graphics_quality.gd` owns the contact-shading switch, and `alpine_world.gd` applies it on startup and live quality changes. Graphics and weather quality remain independent. These environment controls follow the [Godot Environment API](https://docs.godotengine.org/en/stable/classes/class_environment.html).

The first increment did not enable SSIL; the second increment below adds it to High. The third increment below adds SDFGI; SSR and hardware RT remain disabled. Evaluate those separately after this foundation; reflective surfaces and terrain-aware GI need their own visual and performance comparisons. SSAO remains a screen-space approximation and can miss off-screen occluders or small details. The native inspection showed a subtle change, not a dramatic transformation.

Run `./godotw --script tests/ambient_lighting_playtest.gd` for matched before/after environment captures in all graphics tiers, clear/snowfall chase and first-person views, Balanced dawn/dusk/night, and successive frames of a moving snowfall descent. The harness changes only presentation settings for comparison, advances gameplay manually, and remains unranked. Outputs are in `artifacts/ambient_lighting/`; see [VALIDATION.md](VALIDATION.md#ambient-and-contact-lighting-first-increment) for the measured Low budget and limitations.

## Local indirect lighting — second increment

High adds SSIL for nearby indirect-light detail, with a 2 m radius, 0.55 intensity, 0.9 sharpness and normal rejection of 1.0. Low and Balanced keep it off. The existing `graphics_quality.gd` resource owns `indirect_lighting`; the world applies it alongside SSAO on startup and live tier changes. Existing sky fill, direct lights, SSAO, materials and weather values stay fixed for this comparison. No new lights, probes or geometry are added.

The effect is deliberately restrained. SSIL uses visible screen information, so it cannot provide mountain-scale bounce, off-screen light transport or terrain-aware skylight occlusion. Normal rejection limits leaking through surfaces; a short radius limits broad shading artifacts. The implementation follows [Godot's SSIL guidance](https://docs.godotengine.org/en/stable/tutorials/3d/environment_and_post_processing.html#screen-space-indirect-lighting-ssil), which describes SSIL as a complement to full GI. Screenshots are insufficient to rule out every temporal artifact during fast camera changes.

Run `./godotw --script tests/ssil_lighting_playtest.gd` for SSIL-only on/off views, including clear/snowfall, chase/first person, twilight/night and a nearby rock. Static pairs settle for 30 render frames; moving captures have no extra settling frames. The harness verifies High-to-Low/Balanced changes disable SSIL and keeps runs unranked. Captures and metadata are in `artifacts/ssil_lighting/`.

For a controlled full-descent comparison, run the following with `off`, then `on`, using distinct labels:

```sh
./godotw --script tests/ssil_lighting_playtest.gd -- --autoplay --benchmark-no-captures --benchmark-resolution=2560x1440 --graphics-quality=high --weather=clear --ssil-benchmark=off --benchmark-label=ssil_high_off
```

The benchmark report records actual SSAO/SSIL enablement, SSIL radius and intensity in its `lighting` field. The SSIL override exists only in the test harness. See [validation results](VALIDATION.md#local-indirect-lighting-second-increment) for measured cost and visual limitations.

## Terrain indirect lighting — third increment

The optional advanced terrain GI control enables SDFGI on the fixed terrain meshes: four cascades, 1 m minimum cells, 100% vertical scale, 0.8 energy, 0.2 bounce feedback, sky reading and occlusion enabled. The GI buffer uses half resolution. These choices bound cascade work and avoid excessive feedback from bright snow. The independent terrain GI override is initially off and remains unchanged when switching graphics quality. Sun and moon use dynamic GI bake mode so daylight and weather changes update their indirect contribution.

The laboratory and decorative mountain meshes contribute static geometry. Fixed rock batches are marked static. The animated rider/equipment, changing track ribbons and wind-driven vegetation receive GI without being baked into it. Consequently, this pass does not claim accurate forest-canopy indirect occlusion or dynamic rider occlusion. SSAO and SSIL retain their nearby-detail roles. Decorative mountains still do not cast directional shadow maps.

SDFGI is a camera-following approximation, not hardware RT. Cascade transitions and convergence may be visible during rapid movement, teleporting or changing the time of day. The existing cloud transmission runs in custom direct-light shading; SDFGI follows light energy/color and geometry, but does not reproduce the moving cloud-shadow projection in its bounce. Coarse terrain, thin surfaces, half-resolution edges and excluded vegetation limit accuracy. See [Godot's SDFGI guidance](https://docs.godotengine.org/en/stable/tutorials/3d/global_illumination/using_sdfgi.html).

Run `./godotw --script tests/sdfgi_lighting_playtest.gd` for GI-only off/on comparisons. Static captures settle for 90 rendered frames; moving samples do not add settling frames and include the first frames after the camera reset. The harness checks quality switching and unranked eligibility. It also accepts `--sdfgi-benchmark=off|on` with the same autoplay flags as the SSIL harness. Outputs are in `artifacts/sdfgi_lighting/`; benchmark metadata records SDFGI enablement, cascade count and cell size.

## Rebuilding art

Use a Python environment with Pillow and Blender on PATH. The source files must already be present; rebuilding derivatives does not submit Meshy jobs or spend credits.

```sh
python3 scripts/art/prepare_textures.py
blender --background --python scripts/art/build_alpine_assets.py
blender --background --python scripts/art/prepare_skier_v7.py
blender --background --python scripts/art/prepare_spruce.py
blender --background --python scripts/art/bake_spruce_impostors.py
python3 scripts/art/prepare_spruce_textures.py
blender --background --python scripts/art/export_reusable_library.py
./godotw --headless --editor --import
python3 scripts/art/configure_imports.py
./godotw --headless --editor --import
```

Run the spruce and impostor steps after the base library builder, which retains earlier procedural spruce variants. `configure_imports.py` enables mipmaps/VRAM compression and disables automatic GLB LOD generation in favor of the authored levels. It does not edit addon imports.

## Validation and remaining limits

Run the physics, runtime, graphics and mountain suites. Visual checks use `tests/presentation_playtest.gd`, its `--weather-matrix`, `tests/lighting_playtest.gd` and `tests/graphics_playtest.gd`.

For profiling, use an unranked, screenshot-free descent:

```sh
./godotw -- --autoplay --benchmark-no-captures --benchmark-resolution=2560x1440 --graphics-quality=balanced --weather=clear --benchmark-label=balanced_1440p
```

For matched surface inspections, run `./godotw --script tests/terrain_material_playtest.gd -- --terrain-label=after`. The harness saves chase, first-person, snow, cliff and vista views for Low/Balanced/High, plus successive rendered frames during a 120 km/h descent, under `artifacts/terrain_variation/`. Runs remain unranked. Use distinct labels to preserve before/after captures.

The autoplay benchmark reads actual rendered pixel dimensions once before the run, excludes the first 120 render frames, and records frame distributions, slowest-1% mean FPS, draw calls, reported video memory, graphics/backend settings and mountain checksums. GPU timing may be unavailable on Metal; the report explicitly marks that field unavailable. Measurements are full lab descents, not a comprehensive input-latency or hardware certification.

The final measured results and visual findings are in [VALIDATION.md](VALIDATION.md). The evidence index is `artifacts/graphics_validation.json`; matching camera comparisons are `artifacts/graphics_before_after.png`. `scripts/art/build_graphics_report.py` reconstructs the historical 2026-09-05 report, including archived Terrain3D comparisons; it is not a current acceptance report. New lighting results are documented separately below in `VALIDATION.md`.

The current PC target is defined in the [performance policy](#performance-policy); historical MacBook measurements do not establish PC performance. The [final Windows RX 9070 measurements](PC_ENVIRONMENT_IMPLEMENTATION.md#performance-acceptance) establish results only for their stated workload and settings. Other devices and shipping platform exports require direct validation.

The landscape is allocated at startup, with no streaming or background generation. Bounded playable generated basins, mountain libraries, race sharing and local PB ghosts are implemented. Cross-platform replay validation remains future work. See [MOUNTAINS.md](MOUNTAINS.md).


## Articulated rider — model v5

Normal skiing now interpolates the whole-body joint poses and the two ski
transforms produced by the 120 Hz support/balance solver. Snow spray and track
history respect each ski's independent support; an airborne ski leaves no new
imprint. Crashes use fifteen Jolt physical bodies with nearby collider shapes
built from the existing terrain meshes and solver obstacle envelopes.

The finished skier/equipment is 42,063 base triangles. Clothing, helmet, lens,
skin and gloves have separate material surfaces. The Visual Settings panel
contains independent clothing/helmet/lens tint, roughness and metallic controls;
these persist separately from handling settings and never mark physics modified.

Measured Low/snowfall on Apple M4, Metal, 1440×900: mean 8.33 ms (~120 FPS),
p95 8.54 ms, p99 8.71 ms, slowest-1% mean 93.2 FPS. Weather quality was High
(1,700 weather particles); the complete unranked run finished without crashing.
This supports the approximately 60 FPS Low target at that tested resolution.
See [rider validation and limits](SKIER_PHYSICS.md#original-model-v5-validation).

## Turning correction — model v6

The knees, pelvis and shin orientation now follow the boot cuff constraints;
the normal pose solve exits early when both legs already satisfy them. The
separate ski-contact simulation remains at 120 Hz. A runaway orphaned MCP
process consuming one CPU core was also stopped during the lag investigation.
The toolkit, project configuration and graphics presets were preserved.

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

See [turning anatomy and validation](SKIER_PHYSICS.md#turning-anatomy--model-v6)
and `artifacts/turn_anatomy/validation.json` for regression evidence.


## Drainage v2 at racing speed

The steeper physical generator retains the existing grid, terrain chunks and renderer. On Apple M4 / Godot 4.7.2 / Metal, Low at 1440×900 actual pixels with snowfall / High weather, the completed eastern descent on seed 849205174 reaches 154.20 km/h and records 120.0 FPS average, 9.842/10.909 ms p95/p99, and 84.0 FPS slowest-1% mean. Measurement excludes 120 warmup frames and screenshot capture; the other open game was temporarily suspended and resumed afterward. This supports the Low target for the tested high-speed descent. See [mountain validation](MOUNTAINS.md#steeper-v2-validation--2026-09-06) and `artifacts/mountain_generation_v2/descent_v2_849205174_native.json`.


## Larger physical basin — drainage v3

New mountains expand to 1,536 × 4,096 m at the original 4 m resolution, with
786,432 physical triangles in 384 chunks. The built-in mesh renderer remains
the sole terrain path; bounds, exact decorative collar copying and 4 m edge
stitching follow the active surface. World rendering data built in about 4.1 s
in the final native fixture; generation and scene construction are synchronous.

Multiple final flight poses, Space hops and the mountain survey were rendered
and inspected. See `artifacts/jump_upgrade/` and the v10/v3 section of
`VALIDATION.md`. The initial M4 Low capture run averaged 10.26 ms/frame, but the
final-build foreground FPS check is pending: the Mac was locked during subsequent
measurements. Those throttled runs do not certify the approximately 60 FPS target.


## Full summit terrain — v4

The v4 physical mountain spans 6.144 km square at 4 m spacing. Its 576 chunks retain 4,718,592 authoritative base triangles. Distant LOD index buffers coarsen interiors while preserving every original boundary segment; nearby skiing and crash trimeshes use the original physical mesh. The scenery origin and shader mask mapping are centred around this mountain. The laboratory and archived mountain geometry remain unchanged.

An isolated complete south-face descent, including lower forests and snowfall, reaches 163.50 km/h on Apple M4 / Godot 4.7.2 / Metal. Low at **1440×900 actual pixels**, snowfall / High weather, records **119.9 FPS average**, **8.340 ms mean**, **9.396/10.624 ms p95/p99**, and **82.5 FPS slowest-1% mean**. The 14,065 measured frames exclude 120 warmup frames and contain no screenshot capture. The base image is taken afterward. This supports the approximately 60 FPS target for this route/configuration. Source data and limits are in `artifacts/summit_mountain/descent_v4_849205174_native.json` and [MOUNTAINS.md](MOUNTAINS.md).


## Technical Showcase

The current v6 south face retains the same 4,718,592 base terrain triangles and
LOD indices. Its localized 4 m rock/snow mask is enabled only on showcase terrain
materials. Dense stands retain existing tree LODs and regional MultiMeshes, with
restricted family palettes. Graphics quality never changes physical placement.

The archived v5 full Low / Snowfall descent at 1440×900 on Apple M4 measured
8.450 ms mean and 10.256/11.498 ms p95/p99. That earlier face was rejected as too
smooth; these measurements do **not** establish v6 performance. Current native
measurements and visual evidence are stored in `artifacts/technical_showcase_v6/`.
See [mountain validation](MOUNTAINS.md#technical-showcase--fixed-south-face-v6).

The complete native western descent in **Low**, **Snowfall / High weather**,
**Godot 4.7.2 / Metal / Apple M4**, at **1440 × 900 actual pixels**, finishes in
372.042 s without a crash. Across **44,167 measured frames**, mean frame time is
**8.423 ms (118.7 FPS)**, with **9.769 / 11.083 ms p95 / p99** and **12.806 ms
slowest-1% mean**. The first-person forest section contains 8,846 frames: **8.737
ms mean**, **10.933 / 13.277 ms p95 / p99**, and **14.263 ms slowest-1% mean
(70.1 FPS)**. The run is isolated and foreground; it excludes 120 warmup frames
and screenshot capture. These measurements support the approximately-60-FPS Low
target for this configuration and route, including the dense forest.

World mesh construction takes 4.453 s. Reported peak video memory is about 882
MiB. Isolated solver steps average 0.291 ms, with 0.491 ms p99; this excludes
presentation and collision preparation. The report and its exact physical
fingerprints are in `artifacts/technical_showcase_v6/native_-1_snowfall.json`.
Clear and snowfall survey/chase/first-person captures are in the same directory.
Player evaluation of repeated attempts remains open; none of these metrics
claims that the revised face is fun.

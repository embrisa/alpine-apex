# Graphics and generated mountains

Current player settings use ten numbered presets: 1 Low, 4 Balanced, 7 High
(recommended), 10 Ultra. [Preset budgets and consumer contracts](GRAPHICS_PRESETS.md)
and the [interface inventory](../presentation/INTERFACE_OVERHAUL.md) define advanced controls,
Custom/reset behavior and separate graphics/display stores.
[Native performance evidence](../presentation/INTERFACE_PERFORMANCE.md) distinguishes steady
rendering, application cost, generated frames and human acceptance.

[Softer snow](../world/SOFT_SNOW.md) keeps the scanned textures and broad drifts while
reducing grain/ripple contrast, with a modest increase in sun sheen and highlight
glow. It retains terrain-shape shading, crystal density and the existing presets.

[Snow readability](../world/SNOW_READABILITY.md) reduces broad clear-day glare while
retaining crystal sparkle, and adds bounded cool shading in actual terrain
hollows. The shared terrain, powder and track treatment is presentation only.

[FidelityFX integration](FIDELITYFX.md) adds native FSR 4.1/3.1 upscaling and
FSR 3 frame generation through the custom Windows DirectX 12 engine.
Auto selects the best supported provider; the stock editor/runtime retains FSR2.
See that page for installation, rendered evidence and hardware coverage.

[Dreamlike snow](../world/DREAMLIKE_SNOW.md) adds denser two-scale crystals, a snow-only
sun sheen and stronger HDR highlight glow through the existing quality presets.
Validate its appearance in motion and measure its cost on the current mountain.

[Technical woodland v13](../world/ALPINE_V13.md) expands solid tree and mineral coverage
over the unchanged v12 support surface. Distant tree batches cover larger regions;
detailed geometry and shadows are prepared locally around the camera. Its loading and dense-forest acceptance limits are documented on that page.

[Off-map scenery v3](../world/OFFMAP_V3.md) adds batched background conifers and rocks,
snowfields, canopy variation and distant valley fog to the connected apron and
panorama through one shared authored asset. Loading adapts the short connector;
it does not generate another background. Unused square render corners are trimmed
to an irregular perimeter beyond the unchanged 2,850 m return zone. Base terrain
submission falls from 4,718,592 to 3,610,880 triangles; heights and physical identity
are preserved. Scenery identity is 3. Current validation and timings are recorded there.

The [alpine wilderness backdrop](../world/WILDERNESS.md) adds three distant ridge/valley
bands and a shared summit-return zone. Additional geometry budgets are
19,200 / 37,632 / 74,240 triangles for Low / Balanced / High, with 24 batches,
no collision, shadows or GI contribution, and a 32 km far plane.

The [golden sunlight update](../world/GOLDEN_SUNLIGHT.md) warms the existing noon sun, coordinates filmic exposure and surface response, and adds High-only nearby shadowed shafts plus restrained highlight glow. It preserves the noon direction, terrain and PC defaults. Use current native views and timing to validate lighting changes.

The PC graphics upgrade adds selective 4K snow, rock and bark, nine rebuilt conifers, six angular rocks, directional impostors and persistent rendering controls. The [v11 environment](../world/GEOLOGY_V11.md) adds terrain-fitted mineral formations and extends the showcase landforms, exposure, forests and powder across every face of every new mountain; shared assets and lighting apply throughout the game. The earlier [scenery library](../world/SCENERY.md) remains available, with spruce/fir/pine and rock selections now mapped to the PC assets. Ski physics remains an independent 120 Hz solver. Graphics preferences do not change record eligibility or physics identity. See [validation](VALIDATION.md) for required checks and remaining acceptance.

## Performance policy

Follow [the Godot engine strategy](ENGINE_STRATEGY.md) when improving terrain,
scenery or rendering. Profile preparation, CPU submission and GPU work separately;
use batching, native components or focused engine changes where they address a
measured cost. Improve the existing production terrain path while preserving
physical authority. Document quality tradeoffs separately from optimizations at
matched settings. A full replacement runtime is outside the current roadmap.

As of 2026-09-07, target **Ryzen 5 5600X / RX 9070 / 16 GB RAM**, **3840x2160 output** and **90-120 FPS**. Aim for steady-state p95 <= 11.1 ms and p99 <= 16.7 ms. Demanding sections may favor fidelity. The MacBook requirement is removed. The ski simulation remains independent at 120 Hz.

**High is recommended:** Auto FSR at 75% scale (2880x1620 internal at 4K output), 120 rendered FPS cap, frame generation initially off, SSAO and restrained SSIL, SDFGI initially off. Auto uses FSR 4.1 on supported Radeon hardware, FSR 3.1 on other supported GPUs, and FSR2 in the stock engine. Native rendering and exact two-thirds scale (2560x1440 internal) are available. No dynamic resolution is used. Temporal upscaling supplies antialiasing, so additional MSAA/TAA are disabled; native uses 2x MSAA unless frame generation requires the temporal path at 100% scale. The HUD remains at output resolution. Generated presentation frames do not count toward the rendered 90-120 FPS target. See [Godot resolution scaling](https://docs.godotengine.org/en/stable/tutorials/3d/resolution_scaling.html).

Visual Settings persists display mode, upscaler, frame generation, render scale, frame cap, quality and the advanced terrain GI override in `user://graphics_v1.cfg`. Restart and mountain changes preserve them; they never enter recipes, physics tuning, replay identity or ranked eligibility. Automated/script runs use isolated defaults and never write this preference file. Windows benchmarks use an exact-size borderless/fullscreen window and verify the rendered image dimensions, fixing the earlier 3856x2176 result for a 3840x2160 request.

The Windows `scripts/benchmark_pc.ps1` default is v14 and uses the same validated engine resolver as `godotw.ps1`. Its production workload reuses a successful, source-validated ordinary-input trace through the complete gameplay loop, including the chase camera, HUD, audio, collision preparation and effects. Explicit `-Upscaler`, `-TerrainGI`, `-FrameGeneration`, `-FrameCap`, `-ProfileFrameCosts` and `-Repetitions` options keep the measured settings reviewable without writing preferences. Use the guarded runner and generate a current trace first; see [FPS optimization](FPS_OPTIMIZATION.md) for commands and limitations. Actual output pixels, active internal dimensions, CPU/GPU timings, frame percentiles, slowest-1% FPS, draw calls, upload volume and RAM/VRAM are reported. Loading, shader warmup and captures are outside the measured intervals. Existing applications remain untouched and background presence is sampled. Explicit older versions retain their own comparison workloads.

Equivalent game arguments are `--display-mode=fullscreen|windowed`, `--upscaler=auto|fsr4|fsr3|fsr2|native`, `--frame-generation=on|off`, `--render-scale=0.75`, `--fps-limit=0|90|120|144`, `--terrain-gi=off|on`, `--graphics-quality=low|balanced|high` and benchmark `--benchmark-resolution=3840x2160`. Quote the user-argument separator in PowerShell: `./godotw.ps1 --script tests/technical_showcase_playtest.gd '--' --views --benchmark-label=review`.

## Terrain architecture

`scripts/world/mountain_data.gd` produces an 8.192 km square landscape from a scenery seed. It constructs ridges, saddles and drainage-like gullies, then exports a float32 height image and an RGBA environment image: snow coverage, rock exposure, vegetation suitability and wind exposure. This is a procedural landform model, not a hydraulic erosion simulation. A 32 m construction grid supplies the surrounding mountains; resampling it to the 4 m renderer grid does not create additional geological detail.

All 99,009 laboratory vertices are copied exactly into the height image. A 64 m decorative apron blends its perimeter. The selected physical surface (the original `TestSlope` or `alpine-drainage-v1` generated basin) remains the authority for simulation, ski contact and obstacle collisions. The generated mountains outside that area are scenery and cannot be skied yet.

The data descriptor records generator version, seed, extent, cell size, engine version and SHA-256 checksums of heights and environment masks. `--mountain-seed=638201943` changes scenery independently of the benchmark. Reproducing these checksums on other platforms still requires verification; future sharing must retain generator/dependency versions and account for user edits.

The built-in chunk renderer is the sole terrain path. Terrain3D and its addon, adapter, custom clipmap shader and integration suite were removed on 2026-09-06: the bounded-course comparison did not establish a benefit worth maintaining a second renderer. Historical benchmark results remain in `VALIDATION.md` and `artifacts/`. The Godot MCP toolkit and plugin/autoload configuration are preserved.

The laboratory renders the authoritative 4 m triangles directly; the decorative backdrop uses the same mountain data at a coarser spacing. High's [local powder surface](../world/POWDER_VOLUME.md) replaces a bounded 32 m rectangle with fine visual relief over those same support triangles. Terrain materials retain world-coordinate snow/rock shading and the shared cloud-light field. Physical terrain and the local patch cast directional shadows; decorative mountains can contribute to SDFGI without expanding the sun's shadow-map caster budget.

### Surface variation

`assets/graphics/terrain_sampling.gdshaderinc` blends three independently offset, rotated and scaled patches on a triangular lattice. Snow has a limited rotation range to retain a wind-shaped appearance; rock can rotate through a full circle. All color, roughness, occlusion and normal samples share each patch's coordinates and blend weights. Sampled normal slopes are transformed back into the surface plane. Explicit texture gradients preserve mipmaps and anisotropic filtering across patch boundaries, and cubic blend weights soften the joins without averaging away most of the texture contrast.

Warped fields add irregular snow drifts, broad stone tint variation and broken snow/rock transitions. Stone is desaturated and tinted charcoal/slate. Additional rock exposure blends in 64–320 m outside the laboratory perimeter, exposing more mountain faces while retaining snow on gentler shoulders and the course. Elevation contributes to the broad field so cliffs do not inherit vertical stripes from horizontal-only noise. These fields are fixed in world metres and do not animate or restart at terrain chunk boundaries. The shared shader covers the ski slope, decorative mountains, boulders, the terrain renderer and all three graphics presets. These material fields reuse the existing CC0 maps and alone do not change heights or collision. The generator v3 snow relief and model v4 contact changes described below separately change terrain, handling and benchmark identity.

Blending costs extra texture reads. Negligible triplanar projections are removed before renormalization; normals fade out over 35–180 m and roughness/occlusion detail fades over 100–180 m. Fully exposed rock skips snow sampling, and random patch directions use normalization instead of trigonometry. Snow normal and ORM maps use ordinary mip filtering to bound grazing-angle sampling cost; albedo and rock maps retain anisotropy. This softens fine snow relief in the distance while retaining the broader drift variation. The underlying landscape is still a coarse decorative heightfield, and the limited tree and boulder mesh variants can still recur. This change reduces surface texture repetition rather than adding new landforms or asset silhouettes.

### Snow relief, crystals and imprints

Archived Technical Showcase v8 carries the laboratory-scale physical ridges, scallops
and mounds across its snow face. They are baked into the same 4 m contact grid
after gully shaping, with protected cliffs and jump transitions. The shared snow
shader, mesh vertex budget and 120 Hz solver are retained. See
[v8 implementation and acceptance](../world/SNOW.md); the laboratory and archived
showcase versions keep their original terrain.

Laboratory generator v3 now sculpts the actual snow heightfield with warped wind ridges, smaller scallops and uneven mounds. Heights are shared by rendered vertices, collision and obstacle placement, and copied into decorative mountain generator v2. The existing terrain mesh budget is retained. Main drift amplitude is 1.15 m, with smaller 0.18 m scallops and a seeded mound field. Longitudinal variation is gentler than cross-slope relief to retain useful racing contact.

The snow material adds stronger scanned relief and shallow wind ripples in the lighting normal, fading over 12–65 m. World-anchored crystal facets reflect the actual sun/view angle. Footprint filtering removes subpixel grains; there is no animated noise or emissive glitter. The shared directional-light function applies geometry shadows and cloud transmission to the crystal response and disables it below the sun horizon. `snow_sparkle_strength` controls highlight strength. The terrain renderer and all graphics presets use the same shader.

`presentation/snow_tracks.gd` uses continuous paired ribbons with a bounded 800 / 1,600 / 4,096 segment ring for Low / Balanced / High. Independent ski load, slip and penetration drive width, roughness, compression and displaced lips. One immutable height texture makes ribbon vertices follow the exact 4 m contact triangles. Raised lips are geometry; Balanced/High groove recesses use analytical parallax and surface normals. The collision surface remains unchanged. Quality changes preserve the newest history through CPU mirrors, without GPU readback. See [reactive snow](../world/SNOW.md) for budgets, approximations and validation.

Powder, ballistic grains and fine mist use six GPU emitters, capped at 320 / 736 / 1,536 active particles. A shared per-ski response makes clean high-speed gliding restrained and loaded deep skids dramatic. Airborne snow follows the same weather wind used by precipitation and spindrift. Camera and depth fades preserve route visibility. Physics model v4's existing loose-snow resistance, retained by model v12, is unchanged. The current crystal implementation shares world-locked, independently oriented facets with disturbed tracks; Low disables glints.

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
| Skier | 35,900 body triangles, 24 bones | `art_source/blender/skier_v7.blend` |
| Equipment | 5,171 boot triangles + 48,000 for the detailed ski/binding/pole pairs; complete rider 89,071. [Current evidence](../presentation/EQUIPMENT.md) | `art_source/blender/equipment_v1_*.blend`; original equipment retained in `alpine_library.blend` |
| Spruce | Three crown derivatives; approximately 18k / 6.5k triangles near/mid; baked far cards | `art_source/blender/spruce_library.blend` |
| Far spruce | Three albedo silhouettes, two triangles per tree | `art_source/blender/spruce_impostor_bake.blend` |
| Expanded trees | Ten additional families, four shapes each; 6–14k near / 1.8–5k mid / two-triangle far cards | `art_source/blender/<family>_family.blend` |
| Expanded rocks | Six fractured families × four shapes, plus two rounded erratics | `art_source/blender/<family>_family.blend`, `round_boulders.blend` |
| Original boulders / scrub | Three retained earlier rocks and two small cutout plants | `art_source/blender/alpine_library.blend` |
| Earlier authored ridges / trees | Retained for reuse and comparison | `art_source/blender/alpine_library.blend` |

The 10.5 m spruce source is centered on its trunk and fitted within the existing trunk footprint. Existing obstacle scales, rotations and positions are consumed unchanged. Regional MultiMeshes share meshes and materials. Spruce needles are modeled clusters; scrub and distant trees use alpha-cutout foliage. Nearby crowns have small shader motion that stops on pause. The far cards use albedo-only bakes so weather, cloud shading and fog remain dynamic.

The active [Meshy 7 skier](../presentation/SKIER.md) replaces the earlier selected Meshy candidate with cleaner clothing, helmet, goggles and separate textured boots. Its 24-bone skeleton retains simulation-driven skiing poses, with a straighter tuck and damped arm/pole follow-through. The old model and source remain available. First person hides the body while retaining ski equipment. Physics is independent of this visual model. Generated fingers have an approximate pole grip; extreme crash poses and cloth deformation remain refinement areas.

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

Balanced (Medium) and High enable restrained SSAO with a 0.65 m radius, 1.2 intensity/power and 0.35 detail. A modest direct-light influence (`ssao_light_affect = 0.20`) keeps nearby contacts visible in sunlight. The local Forward+ renderer requires `ssao_ao_channel_affect = 1.0` to enable that influence; it takes the minimum of material and screen-space AO rather than multiplying them. Low disables SSAO. `graphics_quality.gd` owns the contact-shading switch, and `alpine_world.gd` applies it on startup and live quality changes. Graphics and weather quality remain independent. See [snow readability](../world/SNOW_READABILITY.md) and the [Godot Environment API](https://docs.godotengine.org/en/stable/classes/class_environment.html).

The first increment did not enable SSIL; the second increment below adds it to High. The third increment below adds SDFGI; SSR and hardware RT remain disabled. Evaluate those separately after this foundation; reflective surfaces and terrain-aware GI need their own visual and performance comparisons. SSAO remains a screen-space approximation and can miss off-screen occluders or small details. The native inspection showed a subtle change, not a dramatic transformation.

Run `./godotw --script tests/ambient_lighting_playtest.gd` for matched before/after environment captures in all graphics tiers, clear/snowfall chase and first-person views, Balanced dawn/dusk/night, and successive frames of a moving snowfall descent. The harness changes only presentation settings for comparison, advances gameplay manually, and remains unranked. Outputs are in `artifacts/ambient_lighting/`; see [VALIDATION.md](VALIDATION.md#full-mountain-and-rendered-checks) for the measured Low budget and limitations.

## Local indirect lighting — second increment

High adds SSIL for nearby indirect-light detail, with a 2 m radius, 0.55 intensity, 0.9 sharpness and normal rejection of 1.0. Low and Balanced keep it off. The existing `graphics_quality.gd` resource owns `indirect_lighting`; the world applies it alongside SSAO on startup and live tier changes. Existing sky fill, direct lights, SSAO, materials and weather values stay fixed for this comparison. No new lights, probes or geometry are added.

The effect is deliberately restrained. SSIL uses visible screen information, so it cannot provide mountain-scale bounce, off-screen light transport or terrain-aware skylight occlusion. Normal rejection limits leaking through surfaces; a short radius limits broad shading artifacts. The implementation follows [Godot's SSIL guidance](https://docs.godotengine.org/en/stable/tutorials/3d/environment_and_post_processing.html#screen-space-indirect-lighting-ssil), which describes SSIL as a complement to full GI. Screenshots are insufficient to rule out every temporal artifact during fast camera changes.

Run `./godotw --script tests/ssil_lighting_playtest.gd` for SSIL-only on/off views, including clear/snowfall, chase/first person, twilight/night and a nearby rock. Static pairs settle for 30 render frames; moving captures have no extra settling frames. The harness verifies High-to-Low/Balanced changes disable SSIL and keeps runs unranked. Captures and metadata are in `artifacts/ssil_lighting/`.

For a controlled full-descent comparison, run the following with `off`, then `on`, using distinct labels:

```sh
./godotw --script tests/ssil_lighting_playtest.gd -- --autoplay --benchmark-no-captures --benchmark-resolution=2560x1440 --graphics-quality=high --weather=clear --ssil-benchmark=off --benchmark-label=ssil_high_off
```

The benchmark report records actual SSAO/SSIL enablement, SSIL radius and intensity in its `lighting` field. The SSIL override exists only in the test harness. See [validation results](VALIDATION.md#full-mountain-and-rendered-checks) for measured cost and visual limitations.

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

[Validation](VALIDATION.md) defines current checks and remaining acceptance.
Use current v14 production-loop measurements for the PC target; historical lab
results and deleted before/after captures do not establish current performance.
Generation runs on an owned worker, while world scene construction remains a
separate loading cost. Streaming and cross-platform replay validation are future
work. See [mountain loading](../gameplay/MOUNTAINS.md).

## Powder volume and local geometric compression

Showcase v9 adds 32 physical powder banks and a deeper loose layer. Snow crowns
on suitable rocks also appear on existing mountains. High replaces a bounded
32 m square with a fixed 6.25 cm mesh and GPU impressions; Low/Balanced retain
cheaper track ribbons. The original terrain is clipped inside the patch so it
cannot cover recessed grooves. See [implementation, budgets, captures and measured
acceptance](../world/POWDER_VOLUME.md). The 120 Hz solver receives no visual feedback.

## Mineral scenery v11

The active mountain now uses the v3 mineral library through compressed runtime derivatives and regional mesh batches. High retains source-resolution normals; quality never changes solid placement. [Geology v11](../world/GEOLOGY_V11.md) describes placement, collision, imports and measured validation. Existing PC resolution and frame-time targets remain in force.

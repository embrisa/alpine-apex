# Alpine tree collection

Revision 3 rebuilds the **12 living spruce, fir and pine variants** with curved branch sprays, baked needle textures, rich greens and moderate upper-branch snow. The collection retains 24 trees in six groups. Bare birches, dead snags and broken crowns retain their existing geometry and textures. Tree population, species selection, horizontal placement, collision envelopes and maximum visibility remain unchanged.

The review revision removes the visibly attached crown stub. Broken stems are clipped through their existing mesh, their cut boundary is fractured, and exposed wood joins that same boundary. Whole twig tubes are pruned from dead trees instead of deleting individual faces. Source curves have more steps and smoother, thinner limbs. Duplicate foliage attachment sites are filtered before building the smaller needle sprays. Winter birches use forked sources; the dense conifer-shaped birch preset was removed.

| Group | Variants | Character |

|---|---:|---|

| Alpine spruce | 4 | Narrow crowns, drooping lower limbs, radial needles |

| Silver fir | 4 | Layered branches and flatter needle arrangements |

| Mountain pine | 4 | Wider open crowns, longer shoots and irregular stems |

| Winter birch | 4 | Bare forked crowns, pale marked trunks and dark outer twigs |

| Dead snags | 4 | Exposed branch networks and weathered bark |

| Broken crowns | 4 | Shortened crowns, missing limbs and jagged exposed wood |

The supplied spruce and birch presets provide the woody source geometry. Seeds, shape settings, height, material masks, physics proxies and export hashes are recorded per asset in `assets/graphics/trees/manifest.json`. These are game-art variants inspired by alpine trees, not botanical specimens.

## Browse and reuse

```powershell

./scripts/play_tree_gallery.ps1

```

The standalone gallery is `scenes/art/tree_gallery.tscn`. Keys **1–6** select a family; **A** shows all trees. Drag to orbit, scroll to zoom, **Left/Right** inspect individual variants, **F** switches between close and group views, **L** cycles near/mid/far detail, **S** toggles near/mid snow, **W** toggles wind, and **Space** demonstrates branch response in the family view. Broken-tree close views focus on the fracture. The previews share a display height for comparison; labels show the exported asset's actual height. The gallery creates no race session or personal best.

- `assets/graphics/trees/models/`: 72 visible near/middle/far GLBs plus 12 dedicated living-conifer shadow GLBs, for **84 exports**. Godot's post-import script supplies the production tree shader when a GLB is dragged into a scene.

- `assets/graphics/trees/textures/`: one eight-direction atlas per tree, at 4096×512 and 2048×256. Far cards include baked snow; the gallery snow toggle applies to the near/mid geometry.

- `art_source/blender/tree_collection/`: individual editable sources and six packed family `.blend` libraries. Family libraries are marked for Blender's Asset Browser and include a catalog file.

GLBs carry UVs, vertex masks and the existing twelve branch tags in one surface. The Godot shader assigns the shared foliage textures to alpha-.7 vertices; wood and snow retain separate masks in that same surface. The packed Blender sources include authoring materials. Other engines must assign the corresponding textures and cutout material rather than relying on the GLB placeholder. Godot supplies dynamic weather lighting, restrained transmission, bark detail, wind and contact deformation.

Needle source meshes bake to padded PNGs. Color is decoded to linear space for mip filtering and encoded once when writing DDS; the color regression test prevents double sRGB conversion. Coverage correction uses the .5 scissor threshold independently in each atlas tile before BC7 compression. The two High atlases occupy about 10.7 MiB on the GPU; Balanced uses 2.7 MiB and Low 0.7 MiB. Alpha scissor follows [Godot foliage guidance](https://docs.godotengine.org/en/stable/tutorials/3d/standard_material_3d.html#transparency).

## In the mountain

The new collection supplies the existing tree selections. Technical Showcase retains its coherent conifer stands, with roughly one in seven tree selections replaced by a bare birch, dead snag or broken crown. Only one extra bare family is selected per region to limit batch fragmentation.

The exported assets span different actual sizes. Mountain presentation rescales each to the existing 10.5 m tree envelope before applying the original obstacle scale. This preserves obstacle positions, radii, yaw, terrain fingerprints and replay identity. Broadleaf branches and broken tops still use the game's approximate solid-trunk collider; there are no new branch colliders or ski forces.

The existing 120 Hz spring system handles at most four nearby trees / 48 canopy regions. All six families can react; dead wood is stiffer. This is one-way canopy motion, with the skier passing impulses to branches. Trees do not topple or break dynamically. Pause and restart keep their existing behavior.

Tree placement now samples the bottom vertices of both woody LODs against the actual terrain triangles. The visual trunk moves down just far enough to put the entire foot at least 9 cm below the snow. It stays upright and retains its horizontal position. The near, mid, far and shadow meshes and the interactive branch anchor all use the same adjusted transform. This changes presentation only; the original obstacle records and collision envelopes remain intact.

Small asymmetric snow drifts meet the base of trees and snow-capped rocks. They follow the sampled terrain, rise by 6–24 cm depending on existing loose-snow depth, and sink their skirts into the ground. Edge normals blend into the terrain's normals and the material shares its textures, exposure mask and cloud lighting. These static details create no ski contact or extra obstacle. Bare ground and slopes steeper than approximately 50 degrees receive no added deposit. The existing rock-top caps are separate.

Contact snow costs 264 triangles per asset and shares one draw batch per occupied 64 m cell, with no shadow pass or per-frame mesh update. Low/Balanced/High draw it to 65/90/115 m. The local ski-track surface remains independent; these small base drifts do not deform when skied over.

One surface per mesh and MultiMesh batching are retained. Living near meshes now use 21,172–21,316 triangles, middle meshes 5,912–5,966, and dedicated shadows 1,440–1,456, including wood and snow. Dead trees remain 2.5–4.4k triangles and broken trees 0.8–1.9k at near detail. Far trees remain two triangles. The shared needle cutouts replace the previous 131–135k-triangle living crowns.

Collection LOD distances are bounded by the existing quality profile: Low uses 25/90 m, Balanced 40/120 m, and High 55/150 m, with complementary 10 m dither transitions. The far draw distance remains the profile setting. Dedicated static living-tree shadows extend to 35/60/85 m and use a geometry-only shader. Bare-tree shadows retain their existing middle mesh. They deliberately omit the small interactive/wind bends. This avoids evaluating full branch rotations and foliage lighting again for every shadow-map vertex.

In the dense production forest, near/middle thresholds remain 6/34 m (Low), 10/48 m (Balanced) and 12/64 m (High), with 5 m complementary transitions and unchanged 20/26/32 m shadow distances. Living-tree detail uses distance to each transformed crown sphere, including tree scale. Far visibility and shadow cutoffs continue to use trunk distance. Batch bounds contain the rebuilt crowns, rotated distant cards and conservative branch motion. Ordinary conifer batches also select detail per crown; only streamed batches use the residency texture. The existing three-region-per-frame uploads, 128 m preload radius, 192 m retention radius, packed placements and four-tree response budget remain. There are no new per-tree Nodes or continuous transform uploads.

The manifest records crown centers/radii, original normalization bounds, shadow paths and hashes, foliage texture references and a build identity covering the authoring scripts, purchased source, Blender version and packed textures. Scenery-cache dependencies include the actual meshes, texture resources, imports and forest shaders. Old automatic density derivatives and their generator have been retired from active paths; frozen copies remain with the before/after validation evidence. Engine/source cache rejection remains mandatory.

The larger variety exceeded the engine's default shader-instance allocation during a native world build. `rendering/limits/global_shader_variables/buffer_size` is now 262144 so batched LOD parameters can be allocated through world transitions. See the [Godot setting reference](https://docs.godotengine.org/en/4.6/classes/class_projectsettings.html#class-projectsettings-property-rendering-limits-global-shader-variables-buffer-size). Plugin and autoload configuration is unchanged.

## Rebuild and validate

```powershell

# Guarded serial authoring, packing, import and Blender roundtrip.

./scripts/art/rebuild_foliage.ps1 -BakeNeedles -Resume

# Or rebuild a single living candidate using the existing atlas:

./scripts/art/rebuild_foliage.ps1 -Asset forest_spruce_01

./scripts/run_guarded.ps1 -FilePath pwsh -Arguments @('-NoProfile','-File','godotw.ps1','--headless','--script','tests/density_lod_suite.gd') -Label foliage_assets

./scripts/run_guarded.ps1 -FilePath pwsh -Arguments @('-NoProfile','-File','godotw.ps1','--script','tests/foliage_playtest.gd','--','--gallery','--label=gallery','--graphics-quality=high','--upscaler=auto','--render-scale=0.75') -Label foliage_gallery

```

`-Resume` checks authoring identity and exported geometry hashes. Import is serial because scene post-import material assignment can request texture imports; the post-import hook keeps shared materials/textures resident for the batch. All plugin/autoload configuration is preserved. Purchased source SHA-256 remains `59faf6ce55457f8535a3575ec4e815c0f7ccb47b95f2eb76bf5da5fad62b030f`.

Current evidence lives under `artifacts/foliage_v3`. `spruce_proof` shows near/middle/far crowns, needles, backlighting and camera-orbit/wind frames. `pilot_final` uses 441 spruce instances through production Scenery/DensityForest batches, with three repetitions of normal rendering, shadows disabled and distant cards only. Additional opaque controls separate geometry, texture/normal shading and cutout costs. Opaque controls change occlusion: their differences include early-depth and overdraw effects and cannot be treated as additive pure shader timings.

The first rejected pilot retained only 5.4% atlas needle coverage and looked thin. Source needle coverage increased to 19.1%; a subsequent color check caught and fixed double sRGB conversion. The accepted spruce stand reduced median GPU time across three samples from 9.780 to 6.289 ms; mean-frame-time medians changed from 10.208 to 6.724 ms. This is the representative-tree gate, not the full-mountain FPS result.

Full-descent validation uses `artifacts/foliage_v3/descent_input.json`, a current model-28/v15 Standard face-3 ordinary-input trace: seed 849205174, 35,669 ticks, 297.241667 simulated seconds. The historical `artifacts/fps_optimization/descent_input.json` is stale for this comparison. Three frozen before runs and matched clear/snowfall first-person/chase views preceded production changes. Those initial runs collected averages and tail times but lacked per-frame median FPS. The collector now writes raw samples after measurement and computes the actual frame p50. Three supplemental before runs use the frozen reference project and the identical reporting extension. Source receipts differ from the original only for the collector and an editor-only import setting.

```powershell

./scripts/run_guarded.ps1 -FilePath pwsh -Arguments @('-NoProfile','-File','scripts/benchmark_pc.ps1','-Label','foliage_v3_after','-Version','15','-InputTrace','artifacts/foliage_v3/descent_input.json','-Upscaler','auto','-TerrainGI','off','-FrameGeneration','off','-FrameCap','0','-Repetitions','3','-ProfileFrameCosts') -Label foliage_v3_after -TimeoutSeconds 2400 -CollectGpuMemory

```

Use identical High/3840×2160/.75 Auto FSR settings and unchanged lighting for comparison. Check the runtime engine hash, exact trace completion, camera settings, source-stability receipt, p95/p99, CPU/GPU costs, draw calls and memory. Follow with a 120 FPS capped check. Automated correctness, rendered inspection, performance and skiing acceptance are reported separately; automated input playback does not establish a human controller playtest.

## Validation, 11 September 2026

The adjacent three-run comparison uses actual 3840×2160 output, High, Auto FSR 4.1.1 at 75%, frame generation off, SDFGI off, uncapped, unchanged camera/daylight and the same custom runtime. The table aggregates each statistic by its median across three runs.

| Measurement | Frozen reference | Updated foliage | Change |
|---|---:|---:|---:|
| Forest median rendered FPS | 118.434 | 120.409 | +1.67% |
| Forest average rendered FPS | 110.625 | 113.822 | +2.89% |
| Forest p95 frame time | 14.082 ms | 13.485 ms | −4.24% |
| Forest p99 frame time | 16.372 ms | 16.376 ms | +0.02% |
| Forest GPU mean | 7.271 ms | 7.014 ms | −3.53% |
| Whole-descent median rendered FPS | 113.649 | 114.692 | +0.92% |
| Whole-descent average rendered FPS | 104.332 | 106.027 | +1.62% |
| Whole-descent p95 / p99 | 14.876 / 17.084 ms | 14.697 / 17.008 ms | −1.20% / −0.44% |

**The requested 15% forest median FPS improvement was not achieved.** The median gain is within the 3% measurement tolerance. All no-regression checks passed; the strong 35.7% dense-stand GPU saving is a separate result. Peak engine video memory fell by about 200 MiB. The rebuilt crowns and conservative coverage increased forest draw calls from 566.6 to 606.1 on average.

The initial baseline was slower than the supplemental reference despite matching identities/settings; the cause is not established. Acceptance uses the adjacent, faster reference rather than inflating the gain against that earlier set. All measured descents reproduce the exact solver state with no runtime source changes or competing Godot processes recorded.

A separate diagnostic hid all tree draw batches while preserving physics, placement, residency and other renderers. It reached 123.487 forest median FPS, only 4.27% above the reference. This supports substantial non-tree cost on this camera path. It is one pass and changes occlusion, so it is not a strict mathematical upper bound. It does not change production coverage or count toward acceptance. Further full-descent work should profile non-tree GPU passes and the existing animation/pose/simulation CPU scopes; reducing foliage triangles alone cannot establish the remaining gain.

Current correctness checks passed: asset/mip/crown/swept bounds 348; collection 565; dynamics 20; grounding 384 headless plus 384 native; graphics 28 plus PC graphics 14; physics 56; runtime 188; packed forest preparation 2,111; spatial forest 34; v15 cache contracts 80; corrupted scenery rejection 4. Blender independently verified all 84 exports. Preservation auditing confirms unchanged core sources, tree IDs, branch data and the bare-family GLB/atlas bytes.

A separate complete descent with the normal 120 FPS cap reproduced the same solver outcome. Forest median/average rendered FPS was 118.948/109.922, with p95/p99 frame times of 13.648/16.031 ms. Whole-descent median/average was 116.659/105.232 FPS. This verifies capped operation; slower frames remain below the cap.

Native visual inspection covers all six families, needle closeups, both LOD transitions, first-person/chase movement, wind, contact recovery, daylight, backlighting and snowfall. Extreme inside-crown crossings still expose planar sprays. A 12–55 cm camera fade was rejected because it produced ghosted edges and exposed snow caps; the measured production shader was restored byte for byte. Original frames and both accepted and rejected experiment captures remain in the evidence folder. Screenshot readback affects their HUD FPS and is excluded from performance claims.

The fresh validation export at `builds/foliage-v3-validation/AlpineApex.exe` passed its PCK dependency audit and actual loading checks for all 84 meshes and six foliage texture levels. Retired density derivatives are absent. An isolated native launch accepted the bundled physical/scenery caches, reached the menu in 65.257 seconds, and moved downhill 13.038 m. Cache reconstruction took 2.715 seconds and scene construction 36.593 seconds; these are distinct loading costs. That functional smoke check used 1280×720 with a 60 FPS cap and does not replace the 4K performance comparison. Existing friend builds and player preferences were preserved.

Original frames, motion clips, raw frame distributions, CPU/GPU scopes, draw calls, memory, receipts, reproduction commands and separate acceptance categories are collected in `artifacts/foliage_v3/RESULTS.md` and `artifacts/foliage_v3/review.html`. A human controller playtest and final artistic acceptance remain separate from automated ordinary-input playback.

## Palette follow-up to the 11 September review

The user found the foliage "too lime light green at a distance". `AlpineAssets.NEEDLE_COLOR_GRADE` now applies a shared linear RGB multiplier of `(0.62, 0.72, 0.88)` to the living needle sprays and green portions of their distant atlases. This deepens and cools the evergreen palette consistently across detail levels. The far shader isolates green chroma so baked white snow and brown wood retain their colors; bare-family materials retain the neutral multiplier. Geometry, texture fetches, coverage, wind and draw distances are unchanged.

Native matched 4K captures are under `artifacts/foliage_v3/color_correction`; open its `review.html` for wide, eye-level, distant and backlit comparisons plus species/detail previews. Collection checks 565 and graphics checks 28 passed again. The export dependency receipt was regenerated. Earlier full-descent measurements and the `foliage-v3-validation` executable preserve the previous palette; this color adjustment makes no new performance claim. Restart a running development game to see it.

Reproduce with `./scripts/run_guarded.ps1 -FilePath pwsh -Arguments @('-NoProfile','-File','godotw.ps1','--script','tests/foliage_color_playtest.gd','--fixed-fps','60','--','--label=color_correction','--graphics-quality=high','--upscaler=auto','--render-scale=0.75') -Label foliage_color_review -TimeoutSeconds 300`.

## Forest visibility aid

**Settings → Camera → Forest visibility** provides two independent controls. **Opening size** ranges from 20–100%, defaulting to 88%. **100% is full-screen mode with no border or corner masking**; lower values retain a soft boundary. **Aid reach** controls forward distance, defaulting to 60%; 0% turns the aid off without changing the saved size. Both settings save with local camera preferences, apply immediately when riding in first-person and chase views, and reset with the other camera settings. They do not steer, choose a route, alter collision, or change replay/record eligibility.

The shared `FoliageSight` controller follows a tightly clamped projection of the rider's short look-ahead point. Its rounded rectangular opening spans the selected percentage of both screen dimensions below 100%. At the default 88%, the fully clear core covers about 53% of the screen for nearby canopy, with a short feather beyond it; the outer 5% of every screen edge stays untouched. At 100%, the shader bypasses the screen mask entirely, including the corners. Reach and activation still apply in full-screen mode. The reach includes the camera boom plus 8–18 m ahead, capped at 28 m from the camera. Activation and recentering settle smoothly; leaving skiing restores the canopy, and teleporting discards the old opening. Reduced motion does not disable this navigation aid: it has no pulsing, camera shake or animated random noise.

Needles and their branch snow share a cutout mask, preserving solid woody geometry and distant forest coverage. The far shader applies the aid only to living-conifer materials, for consistent temporary residency fallback. Shadow passes and the static shadow proxies retain full coverage. A stationary screen pattern is shared across overlapping sprays so layers cannot fill the opening back in; it is separate from the complementary LOD threshold. The feather was narrowed after the first native prototype looked too grainy. Fine stippling is still possible at the feathered boundary, particularly with temporal upscaling.

Implementation stays within shared materials: two cached uniform vectors update a bounded receiver list, with no per-tree Nodes, tree transform uploads, added texture reads, screen postprocessing pass, or solver changes. New resources participate in scenery-cache dependencies and export source identity. Shader coordinates and shadow-pass behavior follow the [Godot spatial shader reference](https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/spatial_shader.html).

Native stand captures and movement for the broad opening are under `artifacts/foliage_v3/sight_wide`; the earlier narrow opening remains under `sight_final`, and the first wider-feather prototype under `sight_prototype`. The main-game fixture `tests/foliage_sight_world_playtest.gd` selects the densest sampled section of the current model-28/v15 ordinary-input trace and compares aid off/on in both riding cameras and clear/snowfall weather under `sight_world_wide`. It also captures the camera settings control. These readback-heavy captures establish no new FPS result; the original overnight performance measurements predate this aid. Human skiing/navigation acceptance remains for the user's playtest.

Validation of the broad opening, 11 September:

- **Automated correctness:** 48 visibility, 817 camera, 191 runtime, 56 physics, 28 graphics and 565 tree-collection checks pass (1,705 total). Aid-off/on pairs in all eight native main-game cases finish at identical positions and velocities, with no crashes and no eligible records. Export dependency identity is refreshed; the earlier standalone export has not been rebuilt for this aid.
- **Rendered inspection:** native 3840×2160 High / 75% Auto FSR captures show the larger opening in first-person and chase views, daylight/backlighting, close branch crossings, turning and wind. The main-game clear/snowfall views mostly face open snow; the dense production stand is the stronger obstruction comparison. Solid trunks and woody branches remain visible. The short feather can still show fine stippling under FSR. Settings scrolling and the 60% control are captured successfully.
- **Performance:** no new isolated timing comparison is claimed for the aid. These captures include readback overhead and may coexist with the user's game. The original foliage performance results above remain separate.
- **Skiing acceptance:** automated ordinary-input samples passed; the user's controller/navigation assessment of the enlarged opening remains pending. Matched images, motion clips and receipts are in `artifacts/foliage_v3/sight_review/review.html`.

Independent size and full-screen follow-up, 11 September:

- **1,098 automated checks passed:** 59 visibility, 817 camera, 194 runtime and 28 graphics. Visibility checks cover size/reach independence, shared material propagation, bounds and separate preference persistence. Runtime checks cover menu signals, restart and reset. Native settings review checks keyboard and gamepad events and applies the selected size in both riding cameras, without writing personal preferences.
- Rendered comparisons at 20%, 50%, 88% and 100% size use identical production stands and 60% reach. Both riding views confirm the full-screen endpoint removes the border and corners while retaining woody geometry. The default remains the enlarged 88% view. Captures and receipts are under `artifacts/foliage_v3/sight_sizes/review.html`; settings screenshots are under `sight_size_settings`.
- These functional checks ran with the guard's `AllowConcurrent` option alongside an import in a separate checkout. No new performance result or physical-controller skiing acceptance is claimed. The export dependency receipt was refreshed.

Reproduction (run engine workloads serially):

```powershell
./scripts/run_guarded.ps1 -FilePath pwsh -Arguments @('-NoProfile','-File','godotw.ps1','--headless','--script','tests/foliage_sight_suite.gd') -Label foliage_sight_contract -TimeoutSeconds 180
./scripts/run_guarded.ps1 -FilePath pwsh -Arguments @('-NoProfile','-File','godotw.ps1','--script','tests/foliage_sight_playtest.gd','--fixed-fps','60','--','--label=sight_wide','--graphics-quality=high','--upscaler=auto','--render-scale=0.75') -Label foliage_sight_wide -TimeoutSeconds 300
./scripts/run_guarded.ps1 -FilePath pwsh -Arguments @('-NoProfile','-File','godotw.ps1','--script','tests/foliage_sight_world_playtest.gd','--fixed-fps','60','--','--graphics-quality=high','--upscaler=auto','--render-scale=0.75') -Label foliage_sight_world_wide -TimeoutSeconds 900
./artifacts/foliage_v3/validate_sight.ps1
python artifacts/foliage_v3/package_sight.py
```

For the size controls, run `tests/foliage_sight_suite.gd`, `tests/camera_suite.gd`, `tests/runtime_suite.gd` and `tests/graphics_suite.gd` with the headless guard commands above. Native reproductions:

```powershell
./scripts/run_guarded.ps1 -FilePath pwsh -Arguments @('-NoProfile','-File','godotw.ps1','--script','tests/foliage_sight_playtest.gd','--fixed-fps','60','--','--label=sight_sizes','--size-review','--graphics-quality=high','--upscaler=auto','--render-scale=0.75') -Label foliage_sight_sizes -TimeoutSeconds 180
./scripts/run_guarded.ps1 -FilePath pwsh -Arguments @('-NoProfile','-File','godotw.ps1','--script','tests/foliage_sight_settings_playtest.gd','--fixed-fps','60','--','--graphics-quality=high','--upscaler=auto','--render-scale=0.75') -Label foliage_sight_size_settings -TimeoutSeconds 180
```

## Historical validation, 7 September 2026

- Blender independently reimported all **72 exports** with matching triangles, dimensions, material counts, vertex colors and branch UV tags. All six family libraries were repacked from their latest sources.

- Godot asset suite: **565 checks passed**, including continuous LOD boundaries at all three quality levels, trunk collision envelopes, and a regression check that the broken crown's exposed wood shares the trunk's vertices.

- Spring dynamics **20/20**, graphics **28/28**, runtime **93/93**, and ski physics **56/56** passed. The physics laboratory descent remains 57.5058 s with peak speed 142.7046 km/h.

- Rendered gallery: all six families, the collection overview, foliage/birch/dead closeups, and each of the four fractures inspected at 1920×1080 with 4× MSAA. A clipping defect that left two upper limbs floating was found and removed before the final gallery capture.

- Native contact probe: **0.05226 rad** peak spring response, **6.61e-10 rad** after recovery, and **12,470 changed sampled pixels** with a fixed camera and hidden probe. This uses the real MultiMesh shader path. Wind frames were also captured. The single-tree 1080p test measured mean/p95/p99 frame times of **8.326/8.460/9.252 ms**; it does not establish full-forest performance.

- Grounding suite: **384 checks passed** both headless and native. Root seating covers all 24 assets at 0/20/40 degree slopes, two obstacle scales and rotated trunks. Maximum visual burial was **0.6162 m**. The native run also reads back the actual near/mid/far/shadow MultiMesh transforms and compares them to the branch anchor; the dummy headless renderer cannot verify that readback.

- Native before/after slope views and tree/rock contact closeups are under `artifacts/trees_v2/grounding`. The 35-degree example includes curved terrain and uses the same interpolated vertex normals as the mountain. The final small 1920×1080 lab measured frame mean/p95/p99 **8.333/8.350/8.379 ms**, GPU **1.358/1.508/1.554 ms**, CPU render **0.204/0.322/0.344 ms**, and 602.6 MiB video memory. It uses production assets and writes no player records; it is not a full-forest benchmark.

- Final forest benchmark: `artifacts/pc_environment/trees_v2_grounded_final`, Technical Showcase v9 / seed 849205174, left route z=1900–2450, clear weather. Actual output **3840×2160**, High / **2880×1620 internal** / 75% FSR2 / 120 FPS cap / SDFGI off, D3D12 on RX 9070. The unranked 99.425-second section completed without a crash and with unchanged terrain/obstacle fingerprints. No source files changed during this run, no other Godot processes appeared in the workload samples, and stderr was empty.

- That final forest run averaged **94.72 FPS**. Frame mean/p95/p99 were **10.558/14.383/16.832 ms**, GPU **9.664/12.855/15.880 ms**, CPU render **0.727/1.062/1.425 ms**, and physics **389/513/618 microseconds**. Draw calls averaged 237; peak video memory was **2975 MiB**, sampled process working set **985 MiB**, and private memory **3993 MiB**. The 90–120 FPS target is met on average, with slower frames below 90; this does not certify every mountain, route, weather or camera mode.

Visual style and skiing feel remain subject to the user's review. The tests establish geometry integrity, renderer operation and the one-way branch response; they do not establish dynamic tree fracture, felling or per-branch collision.


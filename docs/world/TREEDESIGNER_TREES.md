# TreeDesigner spruce trees

Three locally generated snowy spruce variants replace the existing spruce visual family. Fir, pine and other families continue to use their existing assets. Trees have textured bark, fine needle cutouts, rounded snow cushions, ambient wind and contact-driven canopy springs. No purchase or subscription is required to run the exported game assets.

## Source and generation

The purchased `TreeDesigner + 400 trees/TreeDesigner.blend` is read only and excluded from Godot importing. Its SHA-256 is `59faf6ce55457f8535a3575ec4e815c0f7ccb47b95f2eb76bf5da5fad62b030f`. The build appends only `SpruceTree_LowPoly.001`, evaluates seeds 103, 271 and 619, then creates game derivatives. The original library and an already-open Blender session are preserved.

The build was evaluated and exported with Blender 5.2.1 LTS. It uses that version's Geometry Nodes input API. Generated models, UVs, vertex masks, surface counts and dimensions are independently checked by reimporting each GLB. Exact settings and asset hashes are in `art_source/treedesigner_manifest.json`; branch proxies are in `assets/graphics/treedesigner_branches.json`.

| Variant | Near triangles | Mid triangles | Far triangles |
|---|---:|---:|---:|
| Spruce 1 | 19,770 | 12,675 | 2 |
| Spruce 2 | 18,462 | 11,921 | 2 |
| Spruce 3 | 20,762 | 13,865 | 2 |

Each mesh has one surface. The approximately 10.5 m trees retain placement scale and existing trunk collision. Mid geometry simplifies branches while preserving foliage positions. Far meshes use matching eight-direction, albedo-only atlases, with 4096x512 and 2048x256 texture sizes. Existing High transitions remain 95/280 m with a 20 m dither interval. Mid meshes provide stable shadow proxies. The fine needle mask reuses the project's authored `spruce_needles.png`; bark uses the existing project texture library.

`art_source/blender/treedesigner/spruce_derivatives.blend` contains packed, evaluated derivative meshes. It does not require the original Geometry Nodes generator to view or export them. The purchased source pack remains local; this document does not grant redistribution rights to that pack.

From the project root in PowerShell:

```powershell
& 'C:\Program Files\Blender Foundation\Blender 5.2\blender.exe' --background --factory-startup --disable-autoexec --python-exit-code 1 --python scripts/art/build_treedesigner.py
./godotw.ps1 --headless --editor --import
python scripts/art/configure_treedesigner_imports.py
./godotw.ps1 --headless --editor --import
```

Run authoring and import commands sequentially. The import configurator only changes `td_*` assets.

## Physics scope

`scripts/core/tree_dynamics.gd` integrates damped angular springs at 120 Hz. Each tree has 12 canopy regions. A spatial grid activates at most four nearby trees (48 regions); the forest continues using MultiMesh batches instead of a physics body or Node for every branch. Swept contacts avoid missing a branch between samples. Deflection is capped at 0.32 radians, damped back to rest, frozen on pause and cleared on restart or teleport.

`scripts/presentation/tree_motion.gd` uploads spring angles to the instanced shader. Branches respond to the skier passing through the canopy. This is a one-way visual response: branches do not push the skier, break, fall or shed snow. Trunks keep the existing solid collision approximation. Ski forces, terrain generation, obstacle positions, mountain fingerprints and record identities are unchanged by this work.

## Validation

```powershell
./godotw.ps1 --headless --script tests/tree_dynamics_suite.gd
./godotw.ps1 --headless --script tests/treedesigner_asset_suite.gd
./godotw.ps1 --headless --script tests/physics_suite.gd
./godotw.ps1 --headless --script tests/runtime_suite.gd
./godotw.ps1 --headless --script tests/graphics_suite.gd
./godotw.ps1 --script tests/treedesigner_playtest.gd
./scripts/benchmark_pc.ps1 -Label treedesigner_high_forest -Side -1 -Weather clear -Version 9 -StartZ 1900 -EndZ 2450
```

Automated results: tree dynamics 20/20, asset checks 43/43, ski physics 56/56, runtime 93/93 and graphics 28/28. The dynamics checks include energy decay, swept contact, pause/reset and 30/60/144/240 FPS schedules.

The native render lab captures all three LODs, close foliage, ambient wind, a moving contact probe and recovery. It uses the real forest's MultiMesh rendering path and checks image changes with the probe hidden. Reports and PNGs are under `artifacts/treedesigner/native/`. Its 1080p closeup timing is separate from the 4K forest benchmark. These runs are unranked and do not write personal bests.

Final native rendering passed on the RX 9070 at 1920x1080. The 5 m/s probe produced a peak spring deflection of 0.0484 radians (2.77 degrees), with 21,266 sampled pixels changing in the fixed-camera comparison after hiding the probe. The canopy settled below 0.000001 radians after six seconds. Near/mid/far galleries, detailed needles, contact deformation and recovery were visually inspected. The closeup's frame p95/p99 were 8.59/8.79 ms; these are not forest performance figures.

The v9 forest section from z=1900 to z=2450 completed without a crash in 99.425 simulated seconds. The final mountain screenshot was inspected and shows the new spruces among the existing firs and pines. Hardware: Ryzen 5 5600X, RX 9070 and 16 GB RAM. Actual output was 3840x2160; High used 2880x1620 internally through 75% FSR2, a 120 FPS cap and SDFGI off.

| Forest measurement | Mean | p95 | p99 |
|---|---:|---:|---:|
| Frame time | 9.81 ms (101.91 FPS) | 15.25 ms | 20.84 ms |
| Render CPU | 1.30 ms | 2.89 ms | 4.14 ms |
| Render GPU | 8.41 ms | 12.17 ms | 14.62 ms |
| Ski physics step | 617 us | 1,079 us | 2,230 us |

Peak Godot-reported video allocation was 2.40 GiB and the sampled engine working set peaked at 944 MiB. System free memory reached 2.71 GiB. These timings are **provisional**, not acceptance of the sustained 90-120 FPS target: concurrent skier and mineral art previews rendered during the run. Concurrent mineral authoring also changed three unrelated source/manifest files. The benchmark recorded those hashes and process samples; tree runtime files stayed unchanged. No claim is made about the incremental GPU cost of the new trees without an isolated before/after comparison.

Evidence: `artifacts/pc_environment/treedesigner_high_forest/native_-1_clear.json`, `system.json`, `concurrent_render_sample.json`, `stdout.log`, `stderr.log` and `finish_-1_clear.png`. The run remained unranked; terrain and obstacle hashes match the v9 benchmark generated by the concurrently active project work.

Human skiing acceptance remains unverified; automated contacts establish implementation behavior, not how brushing past a tree feels during play.

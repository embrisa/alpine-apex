# Mountain geology v11

Current default generation is [v13 / seed 849205174](ALPINE_V13.md). It retains
the mineral-fitting and collision contracts described here. Explicit older
recipes retain their original reconstruction. The v11 change replaces old rock cylinders with
solid mineral formations while retaining the 4 m skiing surface and 120 Hz solver.

## Distribution and fitting

All 120 base meshes in the v3 library are eligible. A seed selects a natural
subset: cliffs along existing scarps, embedded large crags along geological ribs,
debris fans below their source, and sparse rounded deposits lower down. Upper
north-facing pockets receive glacier pieces and a connected ice/snow exposure
patch. Moss and optional grass appear sparsely on lower exposed stones.

The default release has **2,142 placements**: 10 cliffs, 5 huge embedded boulders,
16 large formations, 553 medium rocks and 1,558 small stones, using 69 assets. Counts are generated,
not quotas. The six faces have 316, 314, 364, 425, 342 and 381 placements.
Fractured and sedimentary pieces form fallen debris fans. Small upright outcrop
and cliff modules appear only as deeply buried extensions on exposed source
shoulders. This keeps every library family eligible without filling talus with
miniature standing walls.

The offline catalog samples the actual underside at up to 2 m spacing, with
additional boundary samples. Large foundations can raise the supporting terrain
through a smooth 16 m kernel, bounded to 8 m and combined by maximum rather than
addition. Final snow sculpting is followed by a second seating check. Cliff
modules bury substantial backs and foundations; loose small and medium stones
align to their supporting slope. Placements that disappear or cannot fit safely
are rejected. There is no terrain flattening to a rectangular asset pedestal.
Glacier footing includes the underside of elevated lobes, and an irregular apron
connects each parent formation to its sheltered drainage without individual snow
collars around the fragments.

Summit entries, drainage floors, snow ramps, drop approaches and landings remain
clear. Trees, huts and race gates reject occupied mineral footprints. These
clearance rules describe terrain access; they exert no force on the rider.

## Physical and rendering contracts

`mountain_geology.gd` owns immutable placement records and a spatial collision
index. The catalog contains IDs, metre bounds, underside samples, convex pieces,
separating axes, source hashes and render paths. Continuous SAT sweeps the same
upright 0.7 x 1.6 x 0.7 m rider envelope used for props against the convex pieces,
including edge axes. The field returns the earliest tree or mineral impact;
the existing flavor adapter adds hut and gate contacts. Jolt uses the identical
convex points and placement transforms within its nearby crash-collision window.
Each formation also has a hierarchy over its convex pieces so distant and buried
pieces can be rejected before the separating-axis sweep. Detailed projection
spans are cached on first use; unqueried pieces add no projection work at startup.
The runtime catalog is a compressed, source-validated shared Resource; it avoids
parsing the large preparation JSON for every field. Nearby Jolt formations attach
their shared shapes directly to one body, without a scene Node per convex piece.

Godot provides the initial decomposition. Large, huge and cliff proxies receive
an offline [CoACD](https://github.com/SarahWeiii/CoACD) refinement in metres from
disposable simplified geometry. Authored connected components remain separate,
including intersecting lobes; merging them before decomposition can close visible
openings. `tests/geology_proxy_audit.py` compares sampled free space with the
original GLB triangles, using the union of the source components for occupancy.
It tests the complete rider box with face and edge separating axes. Any correction
subtracts only a box wholly contained in a source-verified empty sphere; the
source triangles are never altered. This is a sampled opening audit, not a proof
of microscopic surface equivalence or every possible traversal.

These proxies approximate rough stone; they do not reproduce every surface grain.
Rocks are obstacles, not an additional ski-support surface. Every placed stone
in this release is solid, including the small stones. There are no loose dynamic
rocks, changing terrain, granular sediment physics or new friction laws.

Race survey rays reject rocks in front of snow. The chase camera retracts before
mineral obstructions. The mountain preview shows formation footprints and ice.
Cached placements and proxy identity contribute to the obstacle fingerprint;
foundation edits contribute to the height fingerprint. The portable recipe schema
is unchanged, and v11 uses a separate disposable bake cache.

`mineral_scenery.gd` groups shared meshes into 128 m regions, or 256 m for huge
formations. Mesh LODs retain the authored near geometry. All quality levels keep
the same solid placements and collision. Grass draws only nearby, with lower
detail on Balanced and none on Low. Source GLBs and materials remain intact;
runtime meshes contain no embedded source-material references.

Runtime textures use VRAM compression and mipmaps. High retains the source 2K/4K
normal maps, Balanced uses half-size maps and Low quarter-size maps. Unique
albedo/roughness bakes, metre-scale detail, world-up snow and vegetation share the
game's sun/cloud lighting. A shallow shading transition samples the exact terrain
triangles at rock feet; it does not move geometry or alter skiing contact.

## Reproduction

Build or repair the additive runtime library using the existing imported v3 pack:

```powershell
./scripts/art/prepare_geology_runtime.ps1
# Rebuild quality derivatives after a texture-bake change:
./scripts/art/prepare_geology_runtime.ps1 -RebuildTextures
```

This uses a separate background Blender process and a scoped Godot import project.
It does not open/save the user's Blender scene, import unrelated source folders,
replace the main UID cache or modify addon/plugin settings. No paid generation
or network asset service is used.

Run validation workloads **sequentially** through `scripts/run_guarded.ps1` on the
16 GB PC. The runner owns its process tree, prevents overlap with an exclusive
lock, and leaves existing applications open. GPU memory sampling is opt-in with
`-CollectGpuMemory`; GPU allocation totals are informational by default
(`-MaximumGpuMB 0`), while an explicit positive limit remains available for
diagnostics. The runner also stops on engine errors, timeout or a fresh Windows
graphics-failure event.
The offline source audit and collision refinement default to one worker.

```powershell
$engine = (Get-ChildItem "$env:LOCALAPPDATA/Microsoft/WinGet/Packages/GodotEngine.GodotEngine_*/Godot*_console.exe" | Sort-Object LastWriteTime -Descending | Select-Object -First 1).FullName
./scripts/run_guarded.ps1 -FilePath $engine -Arguments @('--path',$PWD.Path,'--headless','--script','tests/geology_jolt_suite.gd') -Label geology_jolt_suite
# Library correctness: staged world loading, Low from startup, dummy renderer.
./scripts/run_guarded.ps1 -FilePath $engine -Arguments @('--path',$PWD.Path,'--headless','--rendering-driver','dummy','--max-fps','30','--script','tests/mountain_library_suite.gd','--','--ui-staged-loading','--graphics-quality=low') -Label mountain_library_suite -TimeoutSeconds 600
# Full-world smoke: 1920x1080, 30 FPS, about 20 seconds after loading.
./scripts/run_guarded.ps1 -FilePath $engine -Arguments @('--path',$PWD.Path,'--max-fps','30','--script','tests/massif_playtest.gd','--','--smoke','--ui-staged-loading','--benchmark-resolution=1920x1080','--benchmark-label=geology_v11_smoke') -Label geology_smoke -TimeoutSeconds 240 -CollectGpuMemory
# Inspect one face per invocation before attempting a full capture tour.
./scripts/run_guarded.ps1 -FilePath $engine -Arguments @('--path',$PWD.Path,'--max-fps','30','--script','tests/massif_playtest.gd','--','--views','--view-face=0','--ui-staged-loading','--benchmark-resolution=1920x1080','--benchmark-label=geology_v11_face_0') -Label geology_face_0 -TimeoutSeconds 240 -CollectGpuMemory
```

The commands below identify the individual fixtures, not a batch to launch. Wrap
engine runs with the guard. Native inspection runs cap rendering at 30 FPS; the
independent ski simulation stays at 120 Hz. Captures can be split by `--view-face`
with a unique output label; a one-face run does not prove all-face inspection.

Runs remain sequential and leave existing applications untouched. Hardware
measurements record their actual process and render timings separately from
automated correctness checks.

If other tasks are editing the project, `./scripts/snapshot_geology_benchmark.ps1`
creates a frozen copy of lightweight code under `.tools/geology_benchmarks`.
Assets, imported resources and the output folder are shared through junctions;
the original Blender libraries are not duplicated. Pass its returned path as
`-ProjectRoot` to `scripts/benchmark_pc.ps1`. The benchmark records the root and
hashes scripts, fixtures, scenes, configuration and asset metadata before/after.
Later UI changes are outside that frozen build's performance evidence.

```powershell
./godotw.ps1 --headless --script tests/geology_asset_suite.gd
./godotw.ps1 --headless --script tests/geology_collision_suite.gd
./godotw.ps1 --headless --script tests/geology_jolt_suite.gd
./godotw.ps1 --headless --script tests/geology_generation_suite.gd
./godotw.ps1 --headless --script tests/geology_contract_suite.gd
./godotw.ps1 --headless --script tests/geology_descent_suite.gd
./godotw.ps1 --headless --script tests/physics_suite.gd
./godotw.ps1 --headless --script tests/runtime_suite.gd
./godotw.ps1 --headless --script tests/massif_contract_suite.gd
./godotw.ps1 --headless --script tests/race_suite.gd
./godotw.ps1 --headless --script tests/flavor_integration_suite.gd
./godotw.ps1 --headless --script tests/mountain_library_suite.gd
./godotw.ps1 --headless --script tests/massif_v10_suite.gd
./godotw.ps1 --script tests/geology_seating_playtest.gd
./godotw.ps1 --script tests/massif_playtest.gd '--' --views --ui-staged-loading --version=11 --benchmark-resolution=1920x1080 --benchmark-label=geology_v11_release_views --graphics-quality=high --upscaler=fsr2 --render-scale=0.75 --fps-limit=30 --terrain-gi=off
./scripts/benchmark_pc.ps1 -Label geology_v11_high_clear -Version 11 -Face 0 -Weather clear
./scripts/benchmark_pc.ps1 -Label geology_v11_high_snowfall -Version 11 -Face 3 -Weather snowfall
python scripts/report_geology_v11.py
```

The seating/contract/descent fixtures use the default-field artifact written by
the generation suite. Test runs remain unranked. Asset, placement, contact and
contract reports live under `artifacts/geology_v11`; native full-world captures
and hardware benchmark reports live under `artifacts/pc_environment`.

Automated checks, rendered inspection, measured hardware performance and user
skiing acceptance are separate. The generated report (`artifacts/geology_v11/REPORT.md`)
includes missing, stale and interrupted runs instead of treating earlier output as
acceptance. It hashes its inputs and streams one catalog asset at a time; it does
not rebuild geometry or initialize a renderer.

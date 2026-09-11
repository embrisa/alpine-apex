# Rock terrain — physics model v14

Rock shortcuts trade distance against speed, steering authority and impact
reserve. The existing reserve bar is the single wear meter; rock exhaustion
uses the normal crash/ragdoll path with reason `IMPACT LIMIT / ROCK WEAR`.

## Contact and tuning

Each ski independently classifies rock coverage at 50%. Its normal support load
weights the combined rock response, so a snow/rock straddle costs approximately
half as much as both skis on rock. The custom solver remains Node-independent
and runs at 120 Hz; no animation force or racing-line attraction was added.

| Default | Rock response |
|---|---|
| Reserve wear | 4 percentage points/s at full rock support, reaching zero in 25 s |
| Low speed | Smooth onset from 0.5 to 3 m/s; stationary contact does not wear |
| Recovery | None while supported by rock; normal snow recovery after 1.25 s |
| Steering response | 70% of snow yaw response |
| Lateral grip/control budget | 60% of snow |
| Dry sliding friction | 0.11 times normal acceleration, plus 0.45 m/s² |
| Dry sliding slip resistance | 0.35 times normal acceleration times sideways fraction |
| Loose-snow depth, penetration, ploughing | Zero on a rock ski |

Resistance remains passive and cannot reverse velocity. Actual loss depends on
slope, speed, tuck, support load and duration. A brief crossing costs a few
reserve points; prolonged riding or entering with depleted reserve risks a fall.
Airborne riders incur neither rock wear nor rock grip. Abrasion has a separate
timer from discrete impact grouping so repeated collisions still cost reserve.

## Shared material and effects

`HeightfieldSurface` derives a fixed R8 coverage map from its 4 m height grid
and existing feature exposure. Slope exposure uses normal-up thresholds 0.66
and 0.90; feature red/alpha preserve exposed formations and clean-snow channels.
Values are quantized before bilinear interpolation. The node-free query produces
the identical result before the image is built. Runtime prop adapters forward it.

Terrain, track fragments and High's powder replacement consume this same map,
with no material mipmaps or dependence on LOD, weather, camera or loose relief.
Inside playable terrain, this replaces the old appearance-only noisy blend at
the snow/rock boundary. Decorative terrain retains its existing shading.
Heights, obstacles, generator versions and immutable cached mountains are unchanged.
Physics model v14 changes benchmark/race/replay compatibility automatically.

Rock skis suppress all contact powder, grains, mist, ribbon stamps and active
powder imprints. Ribbon history breaks on entry, swept tails check material, and
the fragment mask clips wide/old ribbons at the exact rock boundary. Local
powder height also goes to zero on rock. Existing snow trails may finish fading
behind the rider. Ambient snowfall remains weather presentation.

Two GPU spark emitters use short-lived warm streaks, with a combined maximum of
64/128/192 particles at Low/Balanced/High. They have no particle collisions,
shadows, dynamic lights or CPU particle loops. Speed and load control emission;
air, stopped contact, pause and crashes stop new sparks. Snow sliding audio fades
out on rock, with the scrape layer providing contact sound. HUD names rock,
shows reserve percentage and directs the rider back to snow while wearing down.

## Validation

Run separately in PowerShell:

```powershell
./godotw.ps1 --headless --script tests/rock_terrain_suite.gd
./godotw.ps1 --headless --script tests/physics_suite.gd
./godotw.ps1 --headless --script tests/runtime_suite.gd
./godotw.ps1 --headless --script tests/impact_recovery_suite.gd
./godotw.ps1 --headless --script tests/handling_upgrade_suite.gd
./godotw.ps1 --headless --script tests/snow_response_suite.gd
./godotw.ps1 --headless --script tests/powder_volume_suite.gd
./godotw.ps1 --script tests/rock_terrain_playtest.gd '--' --version=11 --views --benchmark-label=rock_terrain --benchmark-resolution=3840x2160
```

Automated comparison: five seconds on an identical 0.46-gradient slope at an
initial 25 m/s gives 103.50 km/h on rock versus 116.60 on snow, with 80% reserve.
A one-second 0.6 steering input changes velocity heading by 3.99° on rock versus
5.23° on snow. Continuous supported rock travel exhausts the full bar at 25 s.
These controlled measurements are tuning evidence, not human skiing acceptance.

Final automated result: 373 checks passed across rock contact (32), physics (56),
runtime (120), impact recovery (45), handling (76), snow response (31), and the
explicit archived powder fixture (13). `artifacts/rock_terrain/validation.json`
records the suite totals, report locations and final source hashes.

The archived v9 powder pilot previously crossed exposed rock without cost. With
material hazards enabled, its left route now exhausts reserve near z=518 m.
`powder_volume_suite.gd` therefore explicitly wraps its two archived routes in
snow-only contact while retaining the real heightfield, loose depth and obstacle
collisions. This preserves a powder-handling regression; it does not certify
those old pilot routes under model v14. Rock behavior is tested separately in
`rock_terrain_suite.gd` and the actual v11 rendered material-contact pass.

The rendered test uses actual v11 terrain and one second of real ski simulation
per surface. It then freezes the completed contact for a bounded VFX inspection
and stationary performance probe; screenshot time is excluded. Its low-reserve
capture explicitly sets the bar to 15% to inspect the HUD. Outputs go under
`artifacts/pc_environment/rock_terrain`; core metrics go under
`artifacts/rock_terrain`. This is unranked and never writes personal bests.

Human acceptance remains open: judge shortcut costs, steerability, spark strength
and transition readability while skiing. A stationary effects probe cannot
establish full-descent 4K/90–120 FPS performance.

Native inspection on RX 9070 / D3D12 verified 3840×2160 output, High at 75% FSR2
(2880×1620 internal). Both material cases survived the one-second physical pass;
rock recorded zero tracks and zero powder/grain/mist response. The GPU coverage
texture matched the CPU image byte-for-byte. Captures show warm sparks and the
97%/15% rock reserve warnings, with no snow marks on the rock face.

| Stationary effect case, 240 frames | Mean frame | p95 | p99 | GPU mean | Render CPU mean |
|---|---:|---:|---:|---:|---:|
| Snow | 8.333 ms | 8.469 ms | 8.582 ms | 6.079 ms | 1.071 ms |
| Rock | 8.334 ms | 8.442 ms | 8.645 ms | 6.690 ms | 0.977 ms |

The raw v11 material map is 2,362,369 bytes. The complete rendered test reported
5.50 GB video allocations and 578 MB Godot static allocations (not total process
working set). These scenes have different viewpoints, so their timing difference
is not an isolated measurement of spark overhead. The captures retain the HUD's
earlier FPS text; the table comes from the subsequent capture-free frame probe.

# Alpine Apex

A Godot 4.7.2 downhill ski-racing game built around responsive, custom 120 Hz ski physics, open mountain routes, and quick retries.

Open `project.godot` in Godot and press **F5**, or run `./godotw.ps1` on Windows.

For a new checkout, follow [private collaboration setup](docs/COLLABORATION.md)
to fetch Git LFS assets, install the matching Windows engine, and build/play.

## Play

The game starts on **Default Mountain, seed 849205174 / v15, Standard richness**. **Drop In** stages you at the summit for free skiing. Choose a direction with A/D or the left stick, then drop with W, Enter, left-stick forward or Cross/A. Choose Light, Standard, Rich, Extreme or independent Custom generation settings in the mountain library. Explore six mountain faces across a 6.144 km square support surface with roughly 2 km of vertical. [Soft snow](docs/PLANTED_SNOW.md) adds depth-dependent contact, localized waves and banks, and physical snow mounds around most tree bases.

Use **Mountains / Create & Library** to generate, name, save or share mountains. Use **Create / Shared Races** to place start and finish gates, race your route and share its code. Eligible finishes save a local personal best and ghost. The laboratory is an explicit test fixture.

| Action | Keyboard / mouse | Standard gamepad |
|---|---|---|
| Steer | A/D or left/right | Left stick |
| Tuck / brake | W / S or up/down | Left stick forward / L2 (LT) |
| Prepare and hop | Hold Space, then release | Hold R2 (RT), then release |
| Airborne pitch adjustment | W/S or up/down after centering | Left stick forward/back after centering |
| Airborne spin / flip | Q/E / I/K | Left shoulder + left stick |
| Grab | Shift | West button |
| Restart | R | North button |
| Chase / first person | C | Right shoulder |
| Look / recenter | Mouse / middle mouse | Right stick / stick click |
| Pause | Escape | Start / Options |
| Telemetry | F3 | Back / Share |
| Physics workbench | F2 | Keyboard |
| Race library / run records | F4 / F6 | Menus |
| Ghost / mute / hide HUD | G / M / H | Menus / keyboard |

Tuck reduces drag; it is not a throttle. Steering, skidding and braking trade speed for control. Jumping happens on release and does not charge a larger impulse. Rough contacts spend impact reserve; smooth supported skiing restores it. The solver versions handling changes and uses **replay format v5**. See [ski physics](docs/SKIER_PHYSICS.md), [jump controls](docs/JUMP_CONTROL.md) and [impact recovery](docs/IMPACT_RECOVERY.md).

Camera, interface, graphics and audio settings are available in the menus. Ordinary menus show the live mountain; photographs are used during loading. See [camera settings](docs/CAMERA.md) and [interface navigation](docs/INTERFACE.md).

Holding forward tucks automatically; sustained steering opens the stance, and returning forward resumes tuck. In the air, center the left stick once, then forward/back performs continuous flips without L1, at about 1.7 seconds per flip. L1 plus left stick remains available for flips and fast spins; release brakes rotation. Keyboard W/S or up/down retains pitch adjustment up to 50 degrees. See [arcade air control](docs/ARCADE_AIR_V27.md). Controller vibration is limited to brief impacts and faint, spaced rock taps. The workbench Vibration control scales these pulses, including zero to disable them. See [controller feedback](docs/CONTROLLER_FEEDBACK.md).

**Menu → Tools → Animation Workshop** opens the isolated clip editor. Pose the skier with the mouse, adjust correction curves, add frame comments, and export a review package for Astra. Workshop edits remain previews. See [Animation Workshop](docs/ANIMATION_WORKSHOP.md).

## Graphics

The target PC is Ryzen 5 5600X / RX 9070 / 16 GB at **3840×2160 output and 90–120 rendered FPS**. Recommended **High** uses Auto FSR at 75%, a 120 rendered FPS cap and optional SDFGI initially off. The [custom FidelityFX runtime](docs/FIDELITYFX.md) supplies FSR 4.1/3.1 upscaling and optional FSR 3 frame generation; stock Godot uses FSR2. Frame generation initially stays off. Low/Balanced/High remain available. The independent ski solver stays at 120 Hz.

This is a target, not a measured performance guarantee. The dense forests and complete-mountain frame-time acceptance still need work. See [graphics policy](docs/GRAPHICS.md#performance-policy), [current terrain](docs/PLANTED_SNOW.md) and [validation gates](docs/VALIDATION.md).

## Development

```powershell
./godotw.ps1 --headless --script tests/physics_suite.gd
./godotw.ps1 --headless --script tests/runtime_suite.gd
./godotw.ps1 --headless --script tests/arcade_carving_suite.gd
```

Run engine workloads sequentially. Quote `'--'` before game arguments in PowerShell. Set `GODOT_BIN` to select an engine. The `./godotw` shell wrapper is also available on macOS/Linux.

For full-mountain tests, reuse the validated [default v15 recipe cache](docs/GENERATION_V15.md). Explicit v14/v13 comparisons retain their own caches. Headless checks, rendered inspection, performance measurements and player acceptance are separate. [Validation](docs/VALIDATION.md) explains the runners and required checks.

| Directory | Purpose |
|---|---|
| `scripts/`, `config/`, `scenes/` | Game code, tuning and scenes |
| `assets/` | Runtime assets |
| `art_source/` | Editable masters and source/provenance data |
| `tests/`, `tests/fixtures/` | Reusable tests and regression references |
| `docs/` | Current design, contracts and maintenance instructions |
| `artifacts/` | Ignored, disposable validation output |
| `addons/` | Preserved Godot MCP toolkit |
| `.tools/`, `.godot/` | Local tools and Godot import/editor caches |

Preview or clear generated test output with:

```powershell
./scripts/clean_artifacts.ps1 -WhatIf
./scripts/clean_artifacts.ps1
```

The command clears reports, captures, comparison videos and temporary project copies. See [artifact lifecycle](artifacts/README.md). Start with the [documentation index](docs/README.md), [architecture](docs/ARCHITECTURE.md), [development priorities](docs/ROADMAP.md) and [contribution guidance](AGENTS.md).

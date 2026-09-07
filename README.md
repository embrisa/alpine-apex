# Alpine Apex

A native **Godot 4.7.2** downhill ski-racing prototype. The first playable slice proves a narrow loop: point downhill, build speed, choose how much control to buy with momentum, and restart immediately.

Open `project.godot` in Godot and press **F5**. The main scene is `main.tscn`. Your existing Godot MCP add-on and project settings are preserved.

## Play

Choose **Drop in** for the timed benchmark or **Free ski** to practice. The test face is approximately 1.55 km long with 600 m of descent. Yellow markers indicate the benchmark corridor; only the finish gate is mandatory. The surrounding mountains are a visual backdrop outside the bounded skiable laboratory.

Choose **Generate / Saved Mountains** to make a random mountain or enter a seed such as `849205174`. New v4 mountains span **6.144 × 6.144 km**, with about **2 km of vertical** and skiing on every side. Name/save/load mountains, copy versioned seeds, or import/export compact `.apexmountain` files. **Ski This Mountain** places you at the highest summit: **A/D** selects a direction; **W or Enter** drops in. Restart to try another face. Existing v1–v3 mountains retain their original shapes. See [mountain generation and sharing](docs/MOUNTAINS.md).

| Action | Keyboard | Standard gamepad / PlayStation |
|---|---|---|
| Steer / set edges | A / D or left / right | Left stick, analog |
| Tuck / reduce air drag | W or up | R2 |
| Brake | S or down | L2 |
| Jump / hop (hold, then release) | Space | South face button / A / × |
| Instant restart | R | North face button / △ |
| Chase / first-person camera | C | R1 |
| Motion effects on/off | V | Keyboard |
| Pause | Escape | Options / Start |
| Telemetry + arrows | F3 | Share / Back |
| Physics workbench | F2 | Keyboard for now |
| Create / saved / shared races | F4 | Keyboard and mouse to author |
| Personal-best ghost on/off | G | Keyboard for now |
| Personal best / split times / run history | F6 | Menu button |
| Mute | M | Keyboard for now |
| Hide instruments | H | Keyboard for now |

Steering rotates the skis; momentum follows through grip. **Tuck is not a throttle.** Holding a turn at high speed creates slip and dissipates speed. Braking trades acceleration for control. A hop removes snow contact; it is not a free boost. Loose snow adds pressure-dependent resistance: fast aligned skis plane more, while skidding and braking plough through it. Sculpted wind ridges and mounds break up the snow surface, while continuous ski grooves, powder spray and sunlit crystals make contact visible. The highest speeds require restraint with the steering input. Hard steering opens the tuck; holding tuck through a turn sacrifices edging leverage. Skidding costs speed, but steering errors and body lean no longer cause balance deaths.

Skis release naturally as snow falls away at a crest or cliff. In flight they retain takeoff pitch, and the rider flexes their knees. **Hold Space or the south controller button to prepare; release to hop.** Holding longer gives the same small hop. A release at the last supported moment works at a ledge; a release shortly before landing is remembered for 75 ms. Land along the slope to reduce impact. The **IMPACT RESERVE** bar drops with rough landings and collisions. It refills gradually after 1.25 seconds of smooth contact; reaching zero causes an impact fall. Soft hops do not drain it. [Impact bar, forgiveness and validation](docs/IMPACT_RECOVERY.md).

Hard turns now build a deeper supported bank at speed, giving approximately **21–22% tighter established turns** in the 120–200 km/h entry tests. Release steering to recover alignment, or countersteer to transfer weight into the next turn. [Handling measurements and limits](docs/SKIER_PHYSICS.md#tighter-high-speed-turns--model-v9).

The v11 turn-transfer improvement is retained: opposite grip starts about **14% sooner at 120 km/h** in the measured reversal fixture. Model v12 replaces balance deaths with impact reserve and supported pose recovery; earlier model records remain separate. [Current model](docs/IMPACT_RECOVERY.md) · [Turn measurements](docs/HANDLING_UPGRADE.md).

The workbench exposes the main physics values and **30 / 60 / 90 / 120 / 150 / 165 / 200 km/h** entry-speed buttons. Modified-physics and speed-lab runs are excluded from personal bests. **Restore defaults & restart** restores standard handling and retries the current descent. Further equipment and camera parameters live in `config/ski_default.tres` and its `SkiTuning` resource script.

Finish a ranked race to record your **personal-best ghost**, then press **R / △** to chase it on the next attempt. **G** toggles the cyan ghost; **F6 / Personal Best / Run History** shows cumulative approach splits and the last 20 completed eligible runs. Splits compare against the PB at the start of the attempt and never require checkpoints. A faster finish celebrates the new PB; unranked runs cannot replace it. [Competitive loop and replay compatibility](docs/COMPETITIVE_LOOP.md).

Choose **Create / Shared Races** from any main menu, or press **F4**, to author directly in the world. Place start and finish on the snow, name and save the race, then **Race it**. Pan with WASD/arrows and zoom with the mouse wheel. **Copy to share** exports a portable text code containing both mountain and race; another player can paste it into **Import race code**. No checkpoints are required, and the finish accepts arrival from any direction. See [race creation, sharing and limitations](docs/RACES.md).

Choose **Visual settings** on the title or pause menu for Clear, Cloudy, Snowfall, or Rain. **Automatic weather** holds conditions for three minutes and blends over twenty seconds, with cloudy interludes between precipitation types. Weather settings last for the application session; a restart retains the weather and its progression. Pausing freezes progression.

The same panel offers **Dawn / Day / Dusk / Night** and an optional **Cycle slowly** toggle. A full cycle takes twenty minutes of active skiing; it pauses with the game and survives restarts. Day is the default, with cycling off. Sun direction, warmth, brightness, sky, and ambient light follow the selected time and weather. Night uses cool moonlight. Moving clouds shade the skier and snow, while nearby terrain, trees, and the skier cast directional shadows.

**High** supports up to 2,000 weather particles; **Low** halves the allocation. **Off** removes added weather effects and cloud shadows, using the original procedural sky at the selected time of day. V also removes arcade speed streaks and exaggerated flake/drop stretching; M mutes rain and wind. The physics and benchmark are the same in every weather and time preset. There is no accumulation, wet-surface grip, or physical crosswind.

## What exists

- Renderer-independent 120 Hz ski simulation: slope gravity, heading, lateral grip, edge response, skidding, surface friction, quadratic air drag, braking, curvature-dependent contact, hopping, landing impulses, balance, and swept obstacle collisions.
- Keyboard and standard gamepad action bindings, analog stick/triggers, adjustable vibration, focus-loss pause, and immediate restart.
- A seeded **test slope**, chunked terrain, instanced trees and rocks, a skinned skier, generated alpine backdrop, readable chase cameras, bounded snow spray/tracks, and layered wind/ski/edge audio. First person, contact-driven camera compression and restrained peripheral blur strengthen the sense of travel; V disables motion effects.
- Moving cloud cover and sun halo, blended weather lighting/fog, camera-relative snow and rain, ground spindrift, rain audio, and peripheral arcade streaks that build from 60 to 200 km/h.
- Shared cloud shadows on snow and the skier, selectable daylight and moonlight, and an optional slow day/night cycle.
- Telemetry and world arrows, live tuning, a timed benchmark with sub-tick finish interpolation, and locally persisted best time / recent-run data.
- In-world start/finish race creation, a persistent local library, portable copy/paste sharing that restores both mountain seeds, and per-race personal bests with direction-independent swept finish timing.
- Bounded 120 Hz input / 30 Hz snapshot recording, a lightweight PB ghost, three route-independent split comparisons, visible run history, legacy-record migration and one-key retries.

This includes the physics and graphics foundation, a first bounded mountain generator, race creation and the local competitive loop. The skier uses a generated, optimized rig with modeled equipment, while shared assets and seeded terrain data supply the scenery. The authored laboratory and a full summit-mountain generator are playable. Named mountain libraries, seed sharing, compact mountain files, open-route race creation and text-code sharing are implemented. More mountain families, streaming, optional checkpoints and online competition remain future work. Local PB ghosts and the competitive retry loop are implemented.

## Graphics and mountains

**Technical Showcase** now selects v7, seed `849205174`: angular ridges and cliff bands, sheltered snow and varied forest descent choices. Shared graphics include 4K snow/rock/bark maps, nine rebuilt conifers with directional impostors and six fractured rocks. **High is recommended** for the Ryzen 5 5600X / RX 9070 / 16 GB PC: 4K output, 75% FSR2, 120 FPS cap and optional SDFGI initially off. Low/Balanced/High remain available. Visual settings persist display mode, upscaler, scale and frame cap. The target is 90-120 FPS; the MacBook requirement is removed. See [measured acceptance and captures](docs/PC_ENVIRONMENT_IMPLEMENTATION.md) and [graphics performance policy](docs/GRAPHICS.md#performance-policy).

The built-in terrain mesh renderer is the sole terrain path. Terrain3D was removed after the local comparison found no demonstrated benefit worth its integration complexity. `--mountain-seed=638201943` still changes the decorative mountain landscape without changing the benchmark. The decorative surroundings remain outside the bounded playable surface. `--generated-seed=849205174` opens a generated mountain; the main-menu library provides seed entry and persistence.

See [graphics architecture, editable sources, rebuild commands and limitations](docs/GRAPHICS.md). The PC environment uses Blender and free sources, spending **0 / 1,500 authorized Meshy credits**. Earlier graphics and skier credit ledgers remain separate.

## Run and test from a terminal

On Windows, `./godotw.ps1` starts the game using the installed Godot console executable; `./scripts/test_pc_environment.ps1` runs the PC regression suites and `./scripts/benchmark_pc.ps1` measures a full showcase descent. Quote `'--'` before game arguments in PowerShell. On macOS/Linux, `./godotw` finds Godot on PATH, in `/Applications`, or in the ignored `.tools` folder. Set `GODOT_BIN` to choose another installation.

```sh
./godotw --headless --script tests/physics_suite.gd
./godotw --headless --script tests/jump_suite.gd
./godotw --script tests/jump_playtest.gd
./godotw --headless --script tests/runtime_suite.gd
./godotw --headless --script tests/high_speed_turns_suite.gd
./godotw --script tests/high_speed_turns_playtest.gd -- --graphics-quality=low
./godotw --headless --script tests/race_suite.gd
./godotw --headless --script tests/competitive_suite.gd
./godotw --script tests/competitive_suite.gd
./godotw --script tests/race_suite.gd
./godotw --headless --script tests/graphics_suite.gd
./godotw --headless --script tests/mountain_suite.gd
./godotw --headless --script tests/generated_mountain_suite.gd
./godotw --script tests/mountain_library_suite.gd
./godotw -- --autoplay
./godotw -- --autoplay --first-person
./godotw --script tests/presentation_playtest.gd
./godotw --script tests/presentation_playtest.gd -- --weather-matrix
./godotw --script tests/lighting_playtest.gd
./godotw -- --autoplay --weather=snowfall --weather-quality=high --benchmark-label=snowfall
```

Add `--benchmark-no-captures --benchmark-resolution=2560x1440` for profiling without screenshots. Actual render dimensions are checked before timing.

Autoplay ignores live keyboard/gamepad controls for repeatability, performs an unranked tucked descent, writes screenshots, and saves a rendered frame-time report. Weather benchmark labels write separate `artifacts/weather_benchmark_<label>.json` reports. The weather matrix writes `weather_presentation_results.json` and 35 native captures, including both cameras, quality levels, transitions, motion toggles and reset behavior. `--weather-auto` enables automatic weather at launch.

Use `--time-of-day=dawn|day|dusk|night` to select lighting at launch and `--time-cycle` to enable its automatic cycle. The native lighting harness checks both cameras across weather/time combinations, cloud shade on the skier and ground, twilight, sun/moon shadows, and moving precipitation at night. `--cloud-shadows-off` is a profiling switch that disables cloud attenuation while retaining the same sky and geometry.

The presentation playtest captures both views from lab entry speeds, plus turning, braking, airtime, landing and the workbench. Run it on a graphical desktop. JSON results are in `artifacts/`; screenshots and logs are ignored by Git. A clean checkout may first need `./godotw --headless --editor --import --quit` to build Godot's import/class cache.

Model v4 on laboratory generator v3 makes speed build progressively: **41 km/h after 10 s**, **90 after about 22 s**, and **143 km/h peak** on the default tucked descent (57.431 s). A sustained synthetic 55° pitch can still exceed **200 km/h**; there is no speed cap. The start is gentler, air resistance is stronger, and lost-edge risk follows sideways recovery distance. Benchmark identity is versioned so earlier times are not compared to the new handling.

The speed dial distinguishes maneuvering (0–30), ordinary skiing (30–60), fast (60–90), racing (90–120), elite downhill (120–150), extreme racing (150–165), extreme terrain (165–200), and exceptional speed (200+ km/h).

**54 physics, 72 runtime, 51 race-authoring and 64 competitive checks pass.** Native captures verify the PB ghost, split/history views and new-best feedback. In a full snowfall descent at Low / 1440×900 on Apple M4, the ghost-enabled run averages **89 FPS**, with **14.8 ms p99** and **65 FPS slowest-1%**. See `docs/VALIDATION.md` for the current rendered frame-time measurement and limitations. These are development-build observations, not minimum hardware guarantees.

Godot's standard SDL-backed controller bindings cover PlayStation and other conventional gamepads, but **physical DualShock/DualSense hardware was not available for validation**. Windows/Linux runs and packaged exports also remain untested. The project can be opened on those platforms with Godot; no platform binaries are claimed here.

Architecture and physics tradeoffs are documented in `docs/ARCHITECTURE.md`. The next development gates are in `docs/ROADMAP.md`.

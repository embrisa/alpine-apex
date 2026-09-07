# Alpine Apex project guidance

Alpine Apex is a high-speed, physics-driven downhill racing game. Physics, response, frame rate and racing depth precede graphics and secondary systems. Do not replace the explicit ski model with animation-driven movement or add a predefined racing-line attractor.

- Graphics performance policy: target the user's Ryzen 5 5600X / RX 9070 / 16 GB PC at 3840x2160 output and 90-120 FPS. High is recommended: 75% FSR2, 120 FPS cap, optional SDFGI initially off. Retain Low/Balanced/High identifiers. The MacBook requirement is removed. The independent ski simulation remains 120 Hz. Measure actual pixels, p95/p99, CPU/GPU timings and memory; see `docs/GRAPHICS.md`.
- Work incrementally. Explain gameplay purpose, proposed architecture and material risks before major systems. Implement the smallest useful version and measure it.
- Read `docs/ARCHITECTURE.md` before changing simulation/contact. Keep the solver independent of Nodes and render frames. Use metres, seconds and radians; label debug units accurately.
- For physics/input/session changes, run `tests/physics_suite.gd` and `tests/runtime_suite.gd` using `./godotw --headless --script ...`. For camera/render/effects changes, inspect a rendered playtest. Do not claim headless tests verify visual feel or device hardware.
- Preserve the user's Godot MCP toolkit in `addons/` and project plugin/autoload configuration. The ignored `.tools` folder contains a local engine, not game source.
- The built-in mesh terrain renderer is the sole terrain path. Terrain3D was removed after it failed to establish a useful benefit; keep generated mountain data independent of the renderer.
- Keep test/lab runs out of personal bests. Version changes that alter benchmark identity, generation or replay compatibility.
- Future snowboard support belongs in a separate movement/equipment model over shared rider input and terrain contracts.
- Preserve v1-v6 terrain fingerprints. Technical Showcase selects v7 with seed 849205174; ordinary random mountains stay on v4. Terrain/contact/tracks/survey/crash geometry share the authoritative 4 m surface. Document automated, rendered, performance and user skiing acceptance separately.

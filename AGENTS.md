# Alpine Apex project guidance

Alpine Apex is a high-speed, physics-driven downhill racing game. Physics, response, frame rate and racing depth precede graphics and secondary systems. Do not replace the explicit ski model with animation-driven movement or add a predefined racing-line attractor.

- Graphics performance policy: target a steady approximately 60 FPS (~16.7 ms/frame) on the user's MacBook at Low graphics quality. Medium (currently named Balanced) and High have no MacBook FPS requirement and may prioritize visual quality. This supersedes the earlier blanket MacBook 120 FPS target; it does not change the independent 120 Hz ski simulation. See `docs/GRAPHICS.md` for measurement guidance.
- Work incrementally. Explain gameplay purpose, proposed architecture and material risks before major systems. Implement the smallest useful version and measure it.
- Read `docs/ARCHITECTURE.md` before changing simulation/contact. Keep the solver independent of Nodes and render frames. Use metres, seconds and radians; label debug units accurately.
- For physics/input/session changes, run `tests/physics_suite.gd` and `tests/runtime_suite.gd` using `./godotw --headless --script ...`. For camera/render/effects changes, inspect a rendered playtest. Do not claim headless tests verify visual feel or device hardware.
- Preserve the user's Godot MCP toolkit in `addons/` and project plugin/autoload configuration. The ignored `.tools` folder contains a local engine, not game source.
- The built-in mesh terrain renderer is the sole terrain path. Terrain3D was removed after it failed to establish a useful benefit; keep generated mountain data independent of the renderer.
- Keep test/lab runs out of personal bests. Version changes that alter benchmark identity, generation or replay compatibility.
- Future snowboard support belongs in a separate movement/equipment model over shared rider input and terrain contracts.
- Document limitations plainly. Current scenery is a bounded laboratory; procedural mountain creation, player-authored race sharing and ghosts are future milestones.


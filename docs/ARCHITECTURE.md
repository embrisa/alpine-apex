# Architecture

## Current identity

Source baseline inspected on 2026-09-11; numeric identities are independent.
Their declarations, not an old report title, determine compatibility.

| Identity | Current value | Source |
|---|---|---|
| Default mountain | Seed 849205174, generator 15, Standard | [startup](../scripts/main.gd), [definition](../scripts/world/mountain_definition.gd), [settings](../scripts/world/generation_settings.gd) |
| Ski physics | Model 28, 120 Hz | [simulation](../scripts/core/ski_simulation.gd), [project settings](../project.godot) |
| Replay | Format 5, eight tick-input fields | [replay](../scripts/racing/run_replay.gd) |
| Race | Schema 4 | [race definition](../scripts/racing/race_definition.gd) |
| Mountain file | Schema 2 | [mountain definition](../scripts/world/mountain_definition.gd) |
| Engine bundle | Godot 4.7.2 editor + validated custom DX12 runtime | [toolchain manifest](../tools/windows/toolchain.json), [development](DEVELOPMENT.md) |

Drop In stages summit free skiing; timed play uses custom races. The laboratory
is an explicit fixture. Generation produces six faces over a 6,144 m square
support surface. Presentation settings do not change the physical recipe.

## Ownership

Paths below are under `scripts/`.

| Owner | Contract |
|---|---|
| `core/rider_input.gd`, `core/input_router.gd` | Equipment-neutral intent and device/action sampling; main gates ownership during UI/lifecycle transitions |
| `core/ski_simulation.gd`, `ski_contact.gd`, `rider_body.gd`, `ski_tuning.gd` | Completed fixed-tick translation, two ski contacts, pressure/edge/slip, body mass/COM, support and rotation; no Nodes or render-frame timing |
| `world/heightfield_surface.gd` | Authoritative triangulated support, normals/material queries and obstacle contract |
| `world/mountain_definition.gd`, `generation_settings.gd`, `generation_job.gd` | Canonical physical recipe, deterministic jobs and immutable preparation inputs |
| `world/mountain_cache_v15.gd`, `mountain_preparation.gd` | Validated physical/scenery preparation; main thread owns publication and GPU submission |
| `world/alpine_world.gd`, `presentation/*` | Render meshes, pose, camera, tracks, particles, weather and audio derived from state |
| `presentation/skier_pose_writer.gd` | Single final skeleton writer; composed pose can seed a crash but cannot modify skiing forces or replay state |
| `presentation/skier_ragdoll.gd`, `world/crash_collision.gd` | Crash-only Jolt skeleton, equipment and nearby exact terrain/obstacle collision |
| `core/run_session.gd` | Clock, finish/splits, eligibility, frozen PB reference, recorder lifecycle |
| `racing/race_definition.gd`, `race_store.gd`, `competitive_record.gd`, `run_replay.gd` | Portable definitions, validation, local stores, compatible snapshot ghosts |
| `racing/race_workshop.gd`, `ui/mountain_library.gd` | Survey/endpoint authoring and mountain generation/library flows |
| `ui/hud.gd`, `main.gd` | UI intent dispatch; scene/session lifecycle, fixed-step dispatch and presentation interpolation |

See [Physics](PHYSICS.md), [World](WORLD.md), [Racing](RACING.md) and
[Animation](ANIMATION.md) for subsystem contracts.

## Authority and timing

Terrain rendering, support/contact, survey picking, tracks, geology seating and
crash collision use the same 4 m triangulation, diagonal and barycentric surface.
Snow depth is physical generated data; nearby powder geometry and track history
are cosmetic. There is no camera-dependent support surface or second terrain
renderer. The removed Terrain3D path established no useful benefit.

Godot dispatches 120 Hz physics with accumulated OS input disabled. Main retains
previous/current completed states; translation, support rotation, body targets
and both skis share the same explicit interpolation fraction. Inactive sessions
hold completed state; resume clears presentation/contact history without advancing
the solver. Catch-up is bounded at 24 steps. Interpolation can add one solver tick
(about 8.33 ms); render cadence does not change the time step.

Mass/COM and ski forces belong to physics. Pose fitting, camera motion, sound,
weather appearance and visual tracks cannot feed back into them. Crashes transfer
the final composed pose and momentum to fifteen Jolt bodies; Jolt is not the
normal skiing solver. The project uses 32 velocity and 12 position iterations
for crash joints.

Tests establish repeatability for identical tick inputs under several render
schedules. Cross-platform bitwise determinism is not promised. PB ghosts
interpolate recorded snapshots; they do not run a trusted second simulation.
Clock and finish timing belong to the session, including within-tick crossings.

## Engine strategy

Godot remains the long-term engine/editor. Use measured, local improvements:
packed data and algorithms, caches, bounded jobs, substantial C++ kernels,
supported server/buffer APIs, or narrow engine patches. Choose the smallest
effective intervention for the measured cost; neither blanket C++ conversion
nor an engine-abstraction layer is a roadmap requirement.

Existing examples are native wind/SFX and the custom FidelityFX renderer.
V15 already implements packed populations, indexed placement, deterministic jobs
and separate physical/scenery caches. Future work must account for those paths
instead of proposing them again as missing foundations.

Recheck remaining costs at their owners: main-thread mineral/forest submission,
asset-identity reads, serial geology/seating, dense-area visibility/shadows and
shader work. Move immutable preparation off-thread; scene mutation and GPU uploads
remain on supported engine paths. Include conversion, synchronization, memory and
packaging costs when evaluating native work. Follow [performance evidence](VALIDATION.md#performance-method).

## Direction and pending work

Current acceptance still needs full-mountain skiing, six-face/multiple-seed route
coverage, complete-descent frame times, continuous presentation comfort, listening,
controller hardware feedback and ordinary racing usefulness. [Validation](VALIDATION.md)
links the existing tasks; evidence completion is separate from player acceptance.

Open-route racing and offline responsive solo play remain core. Future social
options and result-trust boundaries live in [Racing](RACING.md#future-competition).
Dedicated movement servers depend on demand and funding; no backend/networking
implementation is implied. Streaming, new mountain families and race rules need
scoped work. Snowboarding requires a separate movement/equipment model over the
shared rider-input, terrain and session contracts, not ski-model inheritance.

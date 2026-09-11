# Architecture and decisions

## Current contracts

[V15 generation](GENERATION_V15.md) owns canonical richness settings, packed
populations, deterministic bounded jobs and physical/scenery preparation caches.

Default Mountain is **seed 849205174 / generator v15, Standard richness**. Normal skiing is
the versioned custom solver at **120 Hz**, with **replay v5** and **race schema 4**.
Read `MODEL_VERSION` in `scripts/core/ski_simulation.gd` for the active physics identity.

- [Ski physics](SKIER_PHYSICS.md) owns two-ski support, body forces, flight and
  input. [Current carving](ARCADE_CARVING_V20.md) coordinates yaw, bank, grip and
  pressure through actual support; no root-motion or racing-line attractor.
  [Auto tuck and contact v21](TUCK_CONTACT_V21.md) retains steering authority with
  forward held and absorbs small bumps through bounded passive suspension.
  [Skid steering v22](SKID_RESPONSE_V22.md) releases sustained equipment-yaw
  suppression while preserving ordinary carving and physical support.
  [Thick snow v24](PLANTED_SNOW.md) adds load-limited embedded-ski resistance
  during turns and weight transfer. Snowy faces normally have deep cover;
  physical snow shapes and contact remain on the same 4 m surface.
- [Impact reserve](IMPACT_RECOVERY.md) absorbs clean slope-matched landings and
  groups rough contacts. Steering/body lean alone cannot cause balance deaths.
- [Full-curve motion](STEEP_MOTION_GAMEPLAY.md) reads completed physical state;
  [anatomical fitting](SKIER_ANATOMY.md) and rigid bindings remain constraints.
  The character has one final skeleton writer and no cosmetic force feedback.
- [Reviewed downhill poses](DOWNHILL_POSE_REVIEW_R2.md) refine ready stance,
  tuck and jump preparation. Model 25 narrows actual ski centers to 0.38 m;
  animation targets retain presentation-only ownership.
  [Small banks v26](SNOW_CRUSHING.md) yield beneath supported skis at speed,
  within local loose depth and a 30 cm cap; the 28 cm leg suspension is separate.
- [V14 snow](PLANTED_SNOW.md) builds on [v13 placement](ALPINE_V13.md),
  the [v12 landforms](ALPINE_V12.md) and
  [mineral fitting](GEOLOGY_V11.md). Terrain, contact, tracks, survey and crashes
  share the authoritative 4 m support surface. Local powder relief is cosmetic.
- [Arcade air v27](ARCADE_AIR_V27.md) adds bounded ordinary pitch, fast manual
  flips/spins and release braking, with recorded air-tilt intent in replay v5.
- [Grounded snow v28](GROUNDED_SNOW_V28.md) softens rebound, absorbs small banks
  from ordinary speeds and adds bounded dissipative snow retention within leg
  reach. Sharp breaks and pending jumps release; flight remains independent.
- Optional assistance must hand over gradually and preserve manual authority.
  New snowboard support requires a separate movement/equipment model.

## Scope and identity

Alpine Apex is a high-speed downhill racing game. Preserve momentum, find a better line, and control extreme velocity. The mountain serves that loop. The prototype avoids world streaming, progression and multiplayer. Player-generated summit mountains, archived drainage basins and the laboratory share the in-world open-route race authoring and text-sharing flow; general course rules and streaming remain future work.

The user-created Godot 4.7 project, Forward+ renderer, Jolt configuration, and MCP toolkit are preserved. Normal skiing uses a Node-independent, articulated support/balance solver. A crash hands its final pose and momentum to a fifteen-body Jolt ragdoll. The independent ski simulation remains at 120 Hz; Jolt uses 32 velocity and 12 position iterations for stable crash joints.

### Godot development direction

Godot remains the engine and editor. [Engine and performance strategy](ENGINE_STRATEGY.md)
guides incremental improvements to generation, loading, simulation and rendering:
efficient data and algorithms, native C++ components, lower-level engine APIs and
focused Godot patches are available when measurements justify them. The existing
native audio and FidelityFX integration are examples. A full replacement runtime
is outside the current roadmap. Keep the solver and terrain contracts explicit;
Node independence alone does not remove their current Godot type/runtime dependencies.

### Future social and competitive direction

[Future social play and competition](ONLINE_COMPETITION.md) records the design
boundaries to preserve for friend ghosts, shared challenges and eventual group
play. Keep movement local and responsive, solo play available offline, and race
rules/results independent of platform services. This is guidance for ordinary
feature work; dedicated movement servers remain a distant option contingent on
player demand and funding. Current local eligibility and snapshot ghosts do not
establish trusted online results or authoritative replay validation.

## Module boundaries

| Module | Responsibility |
|---|---|
| `core/rider_input.gd`, `input_router.gd` | Equipment-neutral intent: steer, tuck, brake, hop. Godot logical actions abstract hardware. |
| `core/ski_tuning.gd`, `config/ski_default.tres` | Tunable SI-unit physics and presentation values. |
| `core/ski_simulation.gd`, `ski_contact.gd`, `rider_body.gd` | Two unilateral ski contacts, root translation, articulated mass properties, pressure-limited balance, IK joints and hand springs at 120 Hz. No Nodes or rendering. |
| `presentation/skier_ragdoll.gd`, `world/crash_collision.gd` | Crash-only physical skeleton, equipment attachment, nearby exact terrain triangles and obstacle envelopes. |
| `world/heightfield_surface.gd`, `test_slope.gd`, `generated_mountain.gd` | Shared triangulated contact surface and obstacle index; unchanged laboratory fixture and separately versioned seeded drainage-basin generator. |
| `world/mountain_definition.gd`, `mountain_store.gd`, `ui/mountain_library.gd`, `mountain_preview.gd` | Versioned mountain recipe, fingerprints, atomic local saves, seed/file sharing and physical-terrain survey UI. |
| `world/alpine_world.gd` | Terrain and scenery meshes, atmosphere, visual course markers. |
| `presentation/*` | Pose, camera, particles, tracks, sound and debug arrows derived from simulation state. |
| `core/run_session.gd` | Benchmark/custom-race clock, within-tick finish/split intersection, eligibility, frozen PB reference and recorder lifecycle. |
| `racing/run_replay.gd`, `competitive_record.gd` | Bounded input/pose capture, snapshot interpolation, compatible atomic PB/ghost/history persistence and legacy migration. |
| `racing/race_definition.gd`, `race_store.gd` | Versioned mountain/race contract, validation, canonical identity and local library persistence. |
| `racing/race_workshop.gd` | In-world survey camera, snow picking, endpoint authoring, library/import/share UI and markers. |
| `ui/hud.gd` | Start/pause/finish/crash views, readable instruments and workbench. |
| `main.gd` | Wiring, lifecycle, fixed-step dispatch, presentation interpolation and automated render benchmark. |

Future snowboarding can replace the movement model and equipment pose while retaining rider intent, surface, session and presentation infrastructure. It does not require ski simulation inheritance.

## Ski model and terrain contact

The Node-independent custom solver owns two ski contacts, constrained root
motion, supported body response and airborne rotation. Each ski has its own
terrain normal, load, support/release state, yaw/edge response, slip, penetration
and friction. The physical segment model determines COM and inertia; cosmetic
joint fitting does not feed back into it. See [ski physics](SKIER_PHYSICS.md).

Use metres, seconds and radians, and label diagnostic units. Gravity, drag,
passive grip and braking determine travel. Tuck reduces air drag. Input requests
turning through yaw, bank, pressure and actual normal reaction; no input or
animation directly assigns travel velocity or attracts the rider to a line.

[Jump controls](JUMP_CONTROL.md) own release-to-hop, ledge/buffer behavior and
manual airborne rotation. Prediction supplies read-only information for optional
assistance and cosmetic readiness. Help must hand over gradually while preserving
explicit control. [Impact recovery](IMPACT_RECOVERY.md) groups rough contacts and
absorbs clean slope-matched landings automatically. Rock abrasion remains its own
[material-response contract](ROCK_TERRAIN.md). Steering/lean alone do not kill balance.

### Shared support and snow

Collision heights use the same triangle diagonal and barycentric interpolation
as the rendered 4 m support grid. Normal filtering and compliant support belong
to the physical contact model. Terrain fitting, survey, tracks and crash geometry
must agree on that surface; no camera-dependent or parallel terrain authority.

Loose-snow depth is seeded physical data. Contact can use depth, penetration,
load and slip to model resistance. [Snow presentation](SNOW.md) reads completed
per-ski response, while [powder relief](POWDER_VOLUME.md) supplies cosmetic nearby
impressions. Weather, visual track history and particle motion cannot alter grip,
excavate physical terrain or create accumulated compaction.

Velocity projection onto changing contact planes is passive and may lose energy.
The model does not simulate flexible-ski pressure distribution, torsional ski
flex, weather-driven accumulation or propulsion by pumping. Validate energy,
contact duration, stability and route times when changing contact or terrain.
The laboratory is a controlled fixture; its old timing measurements and tuning
versions are not the current default mountain or model identity.

## Timing and determinism

The [athletic skier animation layer](SKIER_ANIMATION.md) consumes completed
120 Hz physics and input states into separate previous/current cosmetic targets.
Rendering interpolates those targets with the same fraction as the physical
pose, then closes limbs against rigid bindings and pole grips. Successful-hop
telemetry and existing landing contacts trigger anticipation, extension and
absorption. The composed skeleton seeds crashes but never feeds back into ski
forces, physical mass properties, or recorded PB/ghost poses.

Godot dispatches `_physics_process` at 120 Hz. The renderer interpolates the previous and current completed positions and cannot change the solver's time step. Input is sampled per physics tick; accumulated OS input is disabled. Body and hand poses interpolate the authoritative tick states; camera smoothing remains render-time presentation. Horizontal camera follow is immediate so high speed cannot make the camera recede indefinitely. Automatic camera elevation uses optional render-time damping, with added vertical lag bounded to 1.5 m in chase and 0.2 m in first person. Riding pitch depends on nominal chase framing or a fixed first-person angle, independently of terrain, vertical movement and contact transitions. Manual look remains separate, and collision clearance takes priority for position without rotating the view. See [camera settings](CAMERA.md). Maximum catch-up steps are bounded at 24; under severe overload the engine can slow simulated time rather than silently discard meaningful input history.

Godot documents the latency tradeoff of interpolation and high tick rates in [its interpolation introduction](https://docs.godotengine.org/en/stable/tutorials/physics/interpolation/physics_interpolation_introduction.html). Our interpolation introduces up to one 120 Hz tick (~8.33 ms), not a display-frame-dependent physics rate. Root translation, support rotation, body joints and both skis use one explicit render fraction. Rendered ankles share the rigid bindings, with leg IK closing the interpolated chains. Inactive sessions hold the completed tick; resume clears pose/contact history without advancing physics. See [ski attachment](SKIER_PHYSICS.md#ski-attachment-and-render-timing).

The local tests verify repeatability for identical tick inputs under 30, 60, 120, 144 and 240 FPS frame schedules. **Cross-platform bitwise deterministic replays are not promised.** Float arithmetic, engine/noise changes and input sampling time can change results. The implemented PB ghost pins engine/course/model/tuning compatibility and interpolates recorded state snapshots; it does not re-simulate the retained tick-input stream. Authoritative input validation remains future work.

Race time accumulates simulation steps, not rendered-frame time. A finish-plane intersection adds only the crossed fraction of the last tick. Millisecond formatting is backed by sub-tick interpolation, not merely additional decimal places. Pausing excludes time. The benchmark has a 72 m wide finish plane; it is not a mandatory checkpoint course.

Legacy local record schema v1 contains course identity, best time and the last 20 eligible times. Competitive schema v2 migrates these times and adds PB splits, dated results and a matching snapshot ghost in one compressed atomic document (replay format v2 includes fifteen joint positions and both ski transforms/contact states). The old `user://benchmark_v1.json` remains untouched; new benchmark data uses `user://benchmark_v1_competition_v2.apexrun`. Course identity includes generator/physics versions, and replay compatibility additionally pins engine, default tuning checksum and tick rate. Modified workbench, speed-lab and automated runs cannot replace records. This remains local, trust-based data rather than authoritative anti-tamper validation.

## In-world race authoring

Current races use schema **3** and [shared summit-return rules](WILDERNESS.md).
Generated summit free skiing and races share a 2,850 m disk. Main resolves swept
finish/exit order before record writes and owns the cancellable return lifecycle.
The survey alone draws the zone outline. New race/record libraries use v2.

The schema-v3 open-route race stores a versioned mountain reference (both physical and scenery seeds), a name, start and finish positions/headings, finite gate dimensions and prop layout version. The ski integrator remains independent. `RunSession` intersects the swept rider segment with the finish arch plane from either direction; no checkpoints or predefined racing line are required. Main compares this fraction with the shared zone exit before saving any result. The workshop pauses the rider while selecting positions on the rendered triangulated snow. Sharing uses portable JSON text, and importing another mountain rebuilds the complete world before racing. Custom PB identities include the definition, mountain, prop layout, zone rules, movement version and tuning checksum; the benchmark record stays separate. See [RACES.md](RACES.md) for lifecycle, bounds, persistence, sharing and limitations.

## Competitive loop

Each timed attempt freezes its PB time, splits and replay reference at restart. Three unbounded first-passage split planes measure approach along the start-to-finish axis; they never gate completion or constrain route choice. The recorder keeps 120 Hz inputs and 30 Hz state samples, including the precise finish sample. Only an eligible new PB promotes its completed recorder. Playback interpolates snapshots using the playerâ€™s simulation-time interval and never advances a second solver. The lightweight cyan ghost has no contacts, tracks, audio or GI contribution. Pause freezes both timelines; R resets the complete attempt. See [COMPETITIVE_LOOP.md](COMPETITIVE_LOOP.md) for limits, persistence, UI and verification.

## Rendering and performance

Target the Ryzen 5 5600X / RX 9070 / 16 GB PC at 4K output and 90-120 FPS. High starts at 75% FSR2 and a 120 FPS cap, with optional SDFGI initially off. Aim for p95 <= 11.1 ms and p99 <= 16.7 ms after warmup; demanding sections may favor fidelity. The MacBook requirement is removed, and the independent solver remains 120 Hz. Resolution and full-descent measurement guidance are defined in [GRAPHICS.md](GRAPHICS.md#performance-policy); measured results and incomplete acceptance items are in [the PC report](VALIDATION.md).

The authoritative laboratory still has 96 chunks and 196,608 triangles. Presentation adds a separately seeded 8.192 km mountain heightfield plus snow, rock, vegetation and exposure masks. The existing laboratory samples are copied exactly into that field. The built-in chunk renderer displays the authoritative laboratory triangles and a coarse backdrop from the same generated mountain data. Terrain3D and its moving replacement patch have been removed; the solver's triangle sampling remains authoritative.

Vegetation uses shared MultiMeshes in 128 m regions, 43 tree shapes across 11 families, 6â€“18k/1.8â€“6.5k-triangle near/mid meshes and matching two-triangle camera-facing far cards. Twenty-six rock shapes share the existing obstacle envelopes. One derivative per family per region bounds batch fragmentation. Cosmetic scenery version 3 uses a separate RNG; it does not alter physical obstacle generation or benchmark identity. Balanced transitions start at 70 and 220 m and end visibility at 1,000 m, with 5 m batch hysteresis. There are no per-tree Nodes or rigid bodies. Scrub uses a separate deterministic seed and remains outside the racing corridor. Quality changes affect appearance only. Asset families, rebuilds and limitations are detailed in [SCENERY.md](SCENERY.md). The complete Meshy 7 skier has 42,063 base triangles including separate equipment, a 24-bone rig and analytic limb targets driven by simulation state. Fixed-step damped hand targets and trailing poles respond to tuck, turning and terrain loads; the straighter crouch keeps pelvis and spine closely aligned. Arm motion cannot advance or steer the solver. See [SKIER.md](SKIER.md) for asset preparation, checks and limitations.

The detailed terrain/data contract, asset provenance, quality budgets and rebuild process are in [GRAPHICS.md](GRAPHICS.md). The bounded generated basin is now playable; terrain streaming is not implemented. See [MOUNTAINS.md](MOUNTAINS.md) for the generator, portable contract, physical/render agreement and limitations.

Four spray emitters share the existing 380-particle ceiling: 110 powder puffs and 80 ballistic grains per ski. Their emission and size follow speed, penetration, ploughing, slip, edge load and impact, with shared sun/cloud lighting. Pause freezes the particles. Tracks use an 800-instance ring buffer of paired, 0.70 m distance-sampled ribbons (about 280 m of paired travel). Four sampled corner heights conform each ribbon to the contact terrain; shaded grooves and irregular raised lips provide depth without excavating that terrain. Airborne intervals, inactivity and teleports break contact history; restart clears the ring. Imprints fade between 100 and 180 m from the camera. Rain retains its PCM loop. [Procedural skiing and crash audio](SKIING_AUDIO.md) reads completed per-ski state, a shared environment survey and bounded read-only Jolt contact reports; Original mode retains the ski loops. [Procedural skiing wind](WIND_DSP.md) synthesizes continuous shaped noise in a native audio callback, with head-relative airflow and an F7 comparison against the original loop; it never synthesizes samples in the GDScript frame loop. HUD telemetry updates at 10 Hz; the speed and timer instruments remain immediate. A compact arc instrument labels all eight speed bands, with a separate balance indicator. It displays the full velocity magnitude in km/h, including while airborne.

Riding cameras use independent first-/third-person profiles in presentation/camera_settings.gd, saved in camera_v2.cfg. Connected defaults to 55-75 degrees vertical FoV, 3-4.5 m chase distance, 3-3.5 m height and absolute -45/-25 degree chase/first-person aim. A configurable delayed speed curve defaults to pow(clamp(kmh/200,0,1),1.6), shared by the profile's lens, boom and tilt endpoints. Pitch is independent of terrain displacement, boom geometry, contact switches, tuck and load. Existing bounded vertical stabilization and terrain/geology clearance remain authoritative over camera position. Race/Stable and named custom presets operate independently per view; shared look and foliage preferences remain outside preset application. Camera response now belongs to presentation settings rather than the physics workbench. Main owns the single rendered camera, input capture and a separate paused preview camera using the same framing evaluator. Preview speed cannot alter the simulation, session, recording or weather; lifecycle transitions restore the retained riding view at actual speed. V selects resting framing and disables optional motion while preserving tilt, stabilization and free look. Ordinary menu, summit, crash and survey framing remain independent. Audio uses separate wind, running-ski and edge-scrape layers, with contact/landing/edge-load mixing. Haptic output is bounded and cleared on pause/exit, but requires hardware assessment. See [camera controls, tuning, and validation](CAMERA.md).

The first ambient-lighting increment mixes 25% sky contribution with the weather ambient fill. Balanced/High enable contact-scale SSAO; Low keeps it disabled. The second increment adds short-range SSIL to High only; Low and Balanced keep SSIL disabled. High also enables four-cascade SDFGI over fixed terrain and rocks, using a half-resolution GI buffer. Rider, tracks and wind-driven vegetation receive GI without contributing stale moving geometry. Low and Balanced keep SDFGI disabled. The existing graphics resource owns that presentation switch, applied by the world on startup and quality changes. See [GRAPHICS.md](GRAPHICS.md#ambient-and-contact-lighting--first-increment) for settings and limitations.

### Weather presentation

`presentation/weather_controller.gd` owns the four configurable resources in `config/weather/`, the 180-second hold / 20-second blend cycle, and one shared `WeatherState`. The cycle is clear â†’ cloudy â†’ snowfall â†’ cloudy â†’ rain â†’ cloudy. The controller uses presentation time, advances the cycle only while skiing, and retains progression across restart. Title ambience animates without advancing the automatic cycle. Disabling automatic mode holds the current blend; explicitly selecting a preset begins a fresh hold. Selection and quality are application-session settings.

Main supplies presentation state and camera movement. The world consumes lighting, cloud, and fog values; weather effects consume wind and precipitation; the existing audio mixer consumes gust/rain values; the HUD displays actual weather. Weather never enters `SkiSimulation`, gameplay input sampling, terrain generation, timing, record eligibility, or course identity. The autoplay harness now uses only fixed tuck input and ignores gameplay hotkeys, preventing live keyboard/controller activity from contaminating benchmark comparisons. No benchmark version bump is needed for this cosmetic addition.

The sky computes three simple noise octaves in a half-resolution pass. A cheap cloud-free cubemap branch keeps realtime radiance work bounded; Godot Forward+ fixes realtime radiance at 256. Cloud offsets integrate wind displacement in world metres, preventing jumps during gusts or preset transitions. Off uses the original procedural sky and clear atmosphere at the selected time, and disables cloud attenuation.

`presentation/cloud_lighting.gd` owns a per-world registry shared by snow, skier, tracks, rocks, trees, markers, and the sky. `cloud_field.gdshaderinc` projects sky rays and direct-light receiver rays onto the same horizontal cloud layer at world Y = max(2,400 m, summit height + 1,200 m). The same wind offset and coverage drive both projections, so moving clouds shade the player and terrain together. `cloud_light.gdshaderinc` applies that transmission to directional light only, retaining Godot's object-shadow attenuation and ambient fill. Opaque surface shaders use Burley diffuse and GGX specular; they continue to cast geometry shadows. Nearby terrain now casts shadows as well as receiving them. This follows Godot's [custom spatial light processing](https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/spatial_shader.html#light-built-ins); the shared cloud field adds no lights or shadow-map passes.

`presentation/daylight_cycle.gd` applies an artistic winter sun orbit after weather blending. Dawn, Day, Dusk and Night select 06:30, 12:00, 17:30 and 00:00. The optional cycle takes 1,200 seconds of active skiing, independently of automatic weather, and retains its hour through restart. Both clocks stop on title/pause/finish. Noon preserves the original 24-degree solar elevation; dawn/dusk warm and weaken the sun. A separate moon light fades in at night. Their active ranges do not overlap, keeping one directional shadow map active. Weather modifies direct-light strength and tint, while sky, clouds, ambient fill and fog blend through twilight. Main supplies camera/lifecycle state; the HUD exposes selection and cycle controls and displays the current time band. This does not use wall-clock time or change solver state.

Cloud transmission is sampled per mesh vertex and interpolated across surfaces. Terrain vertices are spaced four metres apart, fine enough for the broad cloud patches; the sky retains its half-resolution noise pass. This removes repeated cloud-noise work from every surface pixel while keeping object-shadow attenuation and material response per pixel. The surface projection uses the active upper-hemisphere direction (sun by day, moon at night). Additional directional lights would need their own projection contract. Coarse distant decorative meshes approximate cloud edges more loosely than the player and local terrain.

Two GPU precipitation fields allocate 600 snow particles and 900 rain particles on High, with two 100-particle ground emitters: 1,700 total, below the 2,000-particle ceiling even across transitions. Low allocates half as many (850, below its 1,000 ceiling). The snow allocation was reduced during lighting profiling. Precipitation uses translation-only local volumes, world wind/fall velocity minus actual camera translation velocity exactly once, periodic wrapping, and retained particle data across emission lifetimes. New volumes fill immediately. Teleports, camera changes, restarts, and quality changes reset presentation history. Ground emitters sample terrain twice per render update; no CPU per-particle terrain queries, physics collision, or particle Nodes are created.

Snow and rain retain depth testing and fade near the camera, at the volume boundary, and through the central route region. Arcade streaks share the existing peripheral shader and render below the HUD. Camera motion intensity drives bounded stretching, beginning at 60 km/h and approaching full intensity at 200 km/h. Inactive gameplay removes speed accents immediately. V also disables the new streaks and exaggerated precipitation stretching; M fades every audio layer to silence. Rain uses a precomputed mono PCM loop generated by `scripts/tools/generate_rain_audio.py` rather than frame-loop synthesis.

Weather remains an artistic approximation: no precipitation collision/splashes, accumulation, wet materials/grip, physically occluded wind, or physical wind forces. Clouds use one projected layer rather than volumetric geometry. Their shadow projection clamps near the horizon while direct light fades. Distant decorative mountains receive lighting but do not cast geometry shadows; local directional shadows are bounded to 220 m. The sun/moon orbit does not model latitude, seasons, dates or lunar phases. Headless tests cannot establish subjective audio mix, visual feel, or device performance.

Large transparent particles, long-range vegetation shadows and terrain expansion are the main rendering risks. Interactive world construction now uses background data preparation and yields between main-thread terrain batches, with a modal loading view. Individual asset/shader, backdrop and scenery operations can still block drawing. Existing script suites retain synchronous construction unless `--ui-staged-loading` is selected. Terrain streaming and asynchronous mesh upload remain future work. See [interface and loading](INTERFACE.md) for the boundaries and measured evidence.

Godot's [controller documentation](https://docs.godotengine.org/en/stable/tutorials/inputs/controllers_gamepads_joysticks.html) describes the SDL-backed standard input model. PlayStation names appear only in user-facing guidance; simulation input is controller-model independent. Trigger/stick mapping is tested at the action layer. Physical devices, trigger calibration and vibration still need hardware playtests.

Left-stick forward now requests analog tuck; R2/RT holds jump preparation and
releases one hop. A separate completed-tick observer drives finite impact
vibration and faint, spaced rock taps independently of audio mute. The existing
auto-tuck solver, input recording layout and physics identity are retained.
See [controller input and feedback](CONTROLLER_FEEDBACK.md).

## Player-generated mountains

**Current default: v11.** Normal startup and random/bare seeds use the [geology environment](GEOLOGY_V11.md): one authoritative 4 m grid, six seeded face descriptions, immutable parallel baking passes, full-mountain exposure and a disposable source-validated bake cache. The default seed is 849205174; Drop In starts summit free skiing and timed play uses custom races. Archived descriptions below document earlier generator versions.

The `alpine-drainage-v4` generator bakes a 6.144 km square mountain at 4 m spacing, with a true highest-point spawn and radial ridges/bowls on all sides. Free-ski staging lets the player choose a heading, then selects a nearby summit rim with zero initial velocity; all subsequent motion uses the unchanged ski solver. Free progress/completion is radial. The race survey and picking cover the whole field, while authored races retain their own arbitrary-direction finishes.

Archived v1â€“v3 implementations reconstruct existing mountains and races. Scene reloads preserve graphics/weather, camera-effects selection and physics modifications. Library generation/reconstruction use a worker thread with no Nodes; interactive world mesh construction yields to the loading view after each eight terrain sections. The built-in renderer keeps exact base meshes and uses edge-preserving distant LOD index buffers for v4. The laboratory remains byte-compatible with generator v3 and its existing physics model. [Full design, storage and validation contract](MOUNTAINS.md).


### Fixed technical face â€” generator v6

The opt-in Technical Showcase composes the unchanged v4 summit with a bounded
south-face landform definition. Its final 4 m heightfield and standard obstacles
remain authoritative for skiing, crash collision, tracks, survey picking and
races. A localized terrain-resolution exposure mask describes the same crags and
snow gaps to rendering and preview; it does not change friction. Seeded forest
stands use the existing spatial index and regional MultiMeshes. Only the fixed
example seed is supported, and the default generator remains v4. See
[MOUNTAINS.md](MOUNTAINS.md#terrain-and-session-boundaries).

### PC display and showcase v7

`presentation/pc_graphics_settings.gd` owns persistent display preferences separately from physics, weather and recipes. Main restores them before world construction and carries the complete snapshot through mountain reloads. Script/autoplay runs do not load or save player display preferences. Only the 3D viewport scales; UI remains at output resolution.

`world/generators/technical_showcase_v7.gd` is an independent versioned generator over the existing 4 m grid. It retains the v6 drainage/stand structure and adds faceted buttress profiles, physical ledges and sheltered snow exposure. v1-v6 implementations are unchanged. This archived release introduced v7 for Technical Showcase; the current v8 selection is described below. Ordinary generation remains v4. Shared races use the versioned mountain reference and fingerprints through the existing decoder.

### Sculpted showcase snow â€” generator v8

The archived v8 showcase uses seed 849205174. The independent v8 generator
retains v7's landforms and adds the laboratory's physical wind ridges, scallops
and mounds after drainage, before obstacle placement and final exposure. A
separate seeded snow-noise instance preserves the original landform/depth noise.
All relief weights read the pre-sculpt grid; the changed heights commit together.
Geometric snow exposure, slope and smooth feature boundaries control coverage.
The summit and authored drop approach/landing retain their earlier geometry.
The final 4 m surface remains shared by mesh, contact, tracks, survey and crashes;
there is no shader displacement or rider-dependent relief. Archived v1-v7 and
ordinary random v4 generation remain unchanged. Versioned mountain references
separate v8 races and records without a schema or solver change. See
[snow formations and acceptance](SNOW.md).

### Accumulated powder and local surface - showcase v9

Technical Showcase now selects v9 with 32 baked banks and 17-31 cm loose depth
in two powder regions. It preserves v1-v8 and uses the existing model v12 contact
and passive snow resistance. [Powder volume](POWDER_VOLUME.md) documents the
separate physical identity, shared collision surface, and bounded presentation.

High integrates a 32 m local mesh with GPU-computed signed grooves, raised lips
and small untouched crowns. An immutable height texture and exact triangle
diagonal retain the 4 m support surface. Only visual loose-layer detail is
displaced; it never writes back to contact, load or friction. The retained track
ring rebuilds nearby detail without a GPU readback. Render-only ski burial shares
the rigid boot/ankle frame and closes the articulated legs through existing IK.

### Mountain discoveries and gate collision

`world/flavor_layout.gd` creates immutable, seed-derived placement data for v10 and v11 mountains. `world/mountain_flavor.gd` seats reusable assets and their foundations, shares the cloud lighting pipeline, and announces each discovery site once per loaded mountain. `world.ski_surface` delegates terrain queries unchanged and spatially indexes frozen oriented prop boxes; the Node-independent solver still runs at 120 Hz. Godot static bodies provide the same solids to crash ragdolls. Distance detail changes presentation only. Active custom races register two arches; survey previews do not participate in collision. See [FLAVOR_INTEGRATION.md](FLAVOR_INTEGRATION.md).

### Mineral geology v11

The current generated mountain adds deterministic, terrain-fitted v3 mineral formations. The field owns frozen convex proxies and continuous rider-envelope sweeps; nearby Jolt bodies share those proxies. Ski support, tracks and survey snow picking retain the authoritative 4 m grid. Local foundation changes and mineral collision identity belong to generator v11, with an independent cache and preserved v10 reconstruction. Rendering quality affects only detail. See [geology implementation and validation](GEOLOGY_V11.md).

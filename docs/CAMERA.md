# Camera and independent look

## Live menu camera

`scripts/presentation/menu_camera.gd` is a separate render-time Camera3D over the
already loaded world. Main owns camera selection: menu, riding, or race creation
survey. Only one camera renders the world. Loading and summit return keep their
existing transition ownership; race-library browsing no longer pans the survey.

The title context alternates player shots and up to six spatially separated
landform viewpoints, cached per loaded field. Each shot lasts 24 seconds before
a 0.7-second world-only fade. Player framing uses 60-degree FOV, nominal 9 m boom,
4.5 m height and 4 degrees/second orbit, placing the skier beside the left menu.
Scenic shots drift slowly over an eight-metre arc. Bounded terrain probes and
existing geology/solid sweeps reject or retract obstructed views. Archived fields
without feature metadata use sampled summit surroundings; invalid scenic pools
keep the player view.

Pause and results remain local. Crash motion follows the existing Jolt focus
without deliberately orbiting during the fall; orbit starts when the ragdoll
freezes. Reduced interface motion holds the current camera except for necessary
moving-crash following. It disables shot changes and background fades. Panel
navigation retains the originating context and phase.

Menu presentation cannot modify rider input, terrain, physics, replay capture or
record eligibility. The player's first-person/chase selection and distance,
height, FoV, tilt and smoothing preferences remain riding settings. Menus always show the
skier. Leaving menus selects and primes the riding camera immediately, cancels
the background fade and clears pending look and weather history. Weather receives
the actual current camera plus an explicit first-person flag, including survey
and menu views; paused daylight and automatic weather progression stay held.

Validation is recorded separately under `artifacts/live_menu/` and the
`artifacts/guarded/live_menu_*` jobs. Camera checks exercise timing, fallback,
clearance, reduced motion and frame-rate independence. The real-scene playtest
checks lifecycle isolation and writes multi-resolution captures; its optional
`--menu-benchmark` measures a complete tour and local pause/crash orbits without
screenshots in the sample. Native inspection is required for framing and visual
comfort; automated checks do not establish user skiing acceptance.

```powershell
./godotw.ps1 --headless --script tests/menu_camera_suite.gd
./godotw.ps1 --headless --script tests/menu_camera_playtest.gd '--' --live-menu-lab
./godotw.ps1 --script tests/menu_camera_playtest.gd '--' --ui-staged-loading --menu-benchmark --graphics-quality=high --benchmark-resolution=3840x2160 --upscaler=fsr2 --render-scale=0.75 --fps-limit=120 --terrain-gi=off
```

## In-game settings

Open **Tools → Settings & Controls → Camera** from the title or pause menu.

| Setting | Default | Range / step |
| --- | --- | --- |
| Vertical FoV at rest, both riding views | 72° | 50–120° / 1° |
| Vertical FoV at 200 km/h and above, both riding views | 110° | 50–120° / 1° |
| Distance at rest | 3 m | 1–20 m / 0.25 m |
| Distance at 200 km/h and above | 7 m | 1–20 m / 0.25 m |
| Height at rest | 6 m | 2–20 m / 0.25 m |
| Height at 200 km/h and above | 8 m | 2–20 m / 0.25 m |
| Third-person tilt | 0° | −30 to +30° / 1° |
| First-person tilt | 0° | −30 to +30° / 1° |
| Vertical smoothing, both riding views | 50% | 0–100% / 1% |

FoV, distance and height endpoints are independent; any can decrease with speed.
Equal FoV values give a fixed lens. FoV is the vertical angle in both riding views;
wider values show more surroundings. Tilt adjusts the current framing: negative
looks down, positive looks up, and zero retains the original automatic aim.
Third-person and first-person tilt are independent of each other.

Changes save automatically in `user://camera_v1.cfg` and apply to riding without
restarting. The settings menu retains its own camera; resume skiing to see the
chosen framing. **Reset camera settings** restores all nine defaults. Restart,
camera switching and mountain reload retain preferences. Missing keys receive
defaults through the existing configuration loader. Scripted
runs isolate preferences and never write personal settings.

Height means desired height above the skier in third person. Terrain can raise
or retract the camera for clearance. The Camera tab orders FoV, third-person
distance/height, per-view tilt, then smoothing/reset. Paired controls show metres,
degrees (signed for tilt) or percentages; keyboard/controller focus scrolls them
into view on shorter displays. First person keeps
its existing eye position; its vertical stabilization uses the shared strength.

## Framing and stabilization

Third person starts 3 m behind / 6 m above the skier, reaching 7 m / 8 m at
200 km/h. Desired framing prefers **2 m above snow**; the final collision pass
requires **1 m**. This replaces the previous 10–12 m overhead floor. Upward
manual look progressively releases preferred clearance down to the collision
floor. Bounded boom probes retain their 0.6 m terrain clearance, and geology
rays retract the boom before rock obstructions. These are terrain/rock checks,
not comprehensive decorative-mesh or foliage occlusion.

FoV defaults to 72–110 degrees and blends the configured endpoints without
requiring ascending values. Its existing speed factor is 20% smoothstep(0,60),
50% smoothstep(60,120), and 30% smoothstep(120,200), in km/h, smoothed at 2.5/s.
Height and distance use that same factor. Carving still subtracts at most 0.6 m
of distance and 0.25 m of height, with 0.12/0.6 s attack/release. Tuck and load
compression remain bounded. The height floor is 1 m before terrain correction.

The completed 120 Hz rider pose still drives presentation. Godot's vertical axis
is **Y**; horizontal X/Z translation follows immediately. A separate exponential
filter stabilizes automatic camera elevation:
`alpha = 1 - exp(-dt / tau)`, with `tau = 0.24 * strength / 100` seconds.
The default 50% gives 0.12 s; 0% bypasses the added filter and retains the
existing boom/heading response. Added elevation lag relative to the base follow
is bounded to 1.5 m in third person and 0.2 m in first person. First person's
existing 0.8 m terrain floor remains. Sustained descent cannot accumulate
unbounded lag.

Riding pitch is independent of this vertical movement. First person holds a
10-degree downward base angle. Chase uses the nominal speed-blended settings:
`pitch = -atan2(height - 0.6, distance + min(distance, lerp(4, 6, speed_blend)))`.
Limiting nominal look-ahead to the boom distance keeps short, low camera setups
framed around the skier without aiming at a terrain sample. Bumps,
takeoff/landing switches, tuck, load compression, carving offsets and collision
corrections cannot rotate that automatic aim. Pitch chatter is disabled in both
riding views; optional bank and roll chatter remain. Changing speed still gently
changes chase framing through the existing speed blend.

The fixed first-person angle prioritizes a steady horizon. During extended
airtime over steep terrain, nearby landing snow can move below the frame;
manual downward look remains immediate instead of automatically pitching at it.

Manual orbit elevation retains only the existing boom response; it bypasses
the vertical stabilization. Manual yaw and pitch are applied after the steady
automatic orientation and the selected view's configured tilt, preserving
mouse/stick response. Tilt does not move the camera boom, change clearance, or
enter manual-look state. Recenter returns to the configured tilt. The chase boom retains
its orbit response. Final optical pitch is limited to -80/+80 degrees in both
riding views. Collision correction reconciles position filter state without
tilting the camera; clearance takes priority over damping when necessary.

Reset, drop-in, restart and reload seed the filters directly; a view change also
reseeds them. Pause retains the follow state and allows it to settle, and resume
continues from that state. Title, summit and crash follow bypass stabilization;
the summit retains its 30 m behind / 45 m above overview. Crash framing keeps
the former 12–14 m height and 10–12 m snow clearance, independently of riding
height controls. The ragdoll focus still owns crash aim. Independent look and the hidden first-person body remain.

V disables speed framing, carving, bank, chatter and motion effects, using the
configured resting distance/height/FoV. **Tilt and vertical stabilization
stay active**. Summit, menu, crash and survey retain their existing lens and aim;
the new lens/tilt preferences apply only to riding. No input, terrain/contact, physics resource, replay format or
record-eligibility behavior is changed by these preferences. The camera-response
workbench control continues to tune the existing boom response independently.

## Controls and lifecycle

- Mouse movement: look directly, at 0.10 degrees per screen pixel, independent of render scale. No button needs to be held.
- Right stick: logical SDL axes, 0.18 radial deadzone, squared response after deadzone, maximum yaw/pitch rates 150/100 degrees per second. Vertical look is non-inverted.
- Middle mouse / R3: start smooth recentering. C / R1: switch chase and first person.
- Third person and summit allow full horizontal orbit. First person limits yaw to ±120 degrees. Look pitch is limited to -65/+60 degrees, with final optical/orbit limits preventing vertical flips.
- After 0.8 seconds idle, moving above 5 km/h recenters with a 0.35-second exponential time constant. Stationary and summit look holds until input or explicit recentering.

Gameplay captures the cursor. Pause, menus, authoring, focus loss, loading, crash, and exit release it. Pending motion is cleared at control ownership changes; the first capture motion is discarded. A stick held through pause, restart, or a view switch must return to neutral before controlling the view. Restart, drop-in, and view switching reset look and carve state. Live mouse and stick input are excluded from autoplay; automated fixtures can inject camera input explicitly.

## Validation

Run the focused camera suite and required physics/runtime suites:

~~~powershell
./godotw.ps1 --headless --script tests/camera_suite.gd
./godotw.ps1 --headless --script tests/physics_suite.gd
./godotw.ps1 --headless --script tests/runtime_suite.gd
~~~

Native review includes speed fixtures, carving/release fixtures, both look modes, summit orbit, comfort, native cursor capture/release, controls help, and real 120 Hz solver clips with 60 Hz presentation. Frozen telemetry fixtures are labeled separately from moving clips.

~~~powershell
./godotw.ps1 --script tests/camera_playtest.gd '--' --views --benchmark-label=camera_upgrade_views --benchmark-resolution=3840x2160 --graphics-quality=high --upscaler=fsr2 --render-scale=0.75 --fps-limit=120 --terrain-gi=off
./scripts/benchmark_pc.ps1 -Label camera_upgrade_high_clear -ThirdPerson
~~~

Reports are under `artifacts/camera_upgrade/` and `artifacts/pc_environment/camera_upgrade_views/`. The separate uncaptured performance run reports actual output/internal pixels, frame percentiles, CPU/GPU timings, and memory. Automated and native synthetic input checks do not verify a physical mouse or PlayStation controller; user skiing remains the camera-feel acceptance gate.

Camera comfort, controller/mouse feel and continuous motion need player review.
Use [current validation gates](VALIDATION.md) for fresh performance measurements;
old framing comparisons and local reports have been removed.

The camera suite also exercises isolated/repeated bumps, brief airtime, hard
landings, terrain clearance and rock retraction at 30/60/120/240 Hz, with
0/40/100% vertical smoothing and default/close-low framing. Constant-speed
automatic pitch must remain within 0.1 degree, including with motion effects on.
`tests/camera_pitch_playtest.gd` records unranked v14 descent/jump clips in both
views with default and close-low settings, optical pitch and route/skier framing
telemetry. Its frame captures measure motion and framing, not rendered performance.

The lens/tilt regressions additionally cover 50–120° endpoints in ascending,
equal and descending order, ±30° view offsets, recentering, manual-look limits,
preference round trips and native degree readouts. Nonzero tilt participates in
the 30/60/120/240 Hz bump/airtime/landing/clearance matrix.
`tests/camera_settings_playtest.gd` reviews the current v15 Standard bake:

```powershell
./godotw.ps1 --script tests/camera_settings_playtest.gd '--' --views --version=15 --ui-staged-loading --benchmark-label=camera_options_720 --benchmark-resolution=1280x720 --camera-settings-menu-only
./godotw.ps1 --script tests/camera_settings_playtest.gd '--' --views --version=15 --ui-staged-loading --benchmark-label=camera_options_4k --benchmark-resolution=3840x2160 --graphics-quality=high --upscaler=auto --render-scale=0.75 --fps-limit=120 --terrain-gi=off --camera-motion-capture
```

Run these through the [validation guard](VALIDATION.md). The first checks the
scrolling menu, all nine controls, keyboard/gamepad events and reset. The second
also captures default, custom, narrow/wide lens and up/down tilt in both views
at rest/200 km/h, plus complete default/custom jump/landing frame sequences.
Preferences and ranked records remain isolated. These captures do not measure
rendered FPS or establish physical controller feel.

2026-09-11 validation: camera/interface/runtime/physics/menu-camera suites passed
1,195 checks in total. Native 720p and 4K settings reviews passed, with v15
default/custom motion captured in both riding views. Controlled nonzero-tilt
pitch excursion remained below 0.000007°. See
[the camera-options report](../artifacts/camera_options/report.md) for identities,
reviewed frames and the separate performance/user-acceptance boundaries.

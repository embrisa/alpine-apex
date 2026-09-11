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

## Camera profiles and presets

Open **Tools → Settings & Controls → Camera**. Third-person and first-person
profiles are independent. Each retains its own lens, reference tilt, speed
progression, follow response, and optional motion strengths. Device look controls
and forest visibility remain shared.

| Preset | Vertical FoV, rest → full speed | Chase distance | Chase height | Chase tilt | First-person tilt |
| --- | --- | --- | --- | --- | --- |
| Connected (default) | 55° → 75° | 3 → 4.5 m | 3 → 3.5 m | −45° | −25° |
| Race | 60° → 80° | 3.5 → 5.5 m | 3.5 → 4.5 m | −40° | −22° |
| Stable | 60° fixed | 3.5 m fixed | 3.5 m fixed | −45° | −25° |

Tilt values in this table are the reference aim on a 15° descent. With default
slope following, Connected aims −30° on level ground and 0° on a 30° uphill;
first person aims −10° and +20° respectively. This fixes the former fixed-world
view becoming too top-down on flats and losing the route when skiing uphill.

Connected uses 50% of the existing carve, tuck, load/landing, peripheral blur and
speed-streak strengths, 35% bank, and no chatter. Race uses 100% of each existing
effect. Stable disables them and uses 75% vertical smoothing; the others use 50%.
First-person eye height is 1.45 m and full-strength tuck lowering is 0.35 m.

Built-in presets are immutable. Editing a profile changes its selector to
**Custom**, without changing its saved source. **Save new**, **Replace**,
**Rename**, and **Delete** operate on named presets for the selected view.
Replacing uses the entered existing name; rename/delete target the last selected
preset. Names are 1–40 characters and cannot use built-in names or Custom.
Reset-current-view restores Connected; reset-all additionally resets shared
controls. Neither reset deletes named presets.

Working edits save automatically to `user://camera_v2.cfg` and survive restart
and mountain reload. The file contains version 2, both working profiles, shared
preferences, selected preset labels, and independent named-preset dictionaries.
The old camera_v1 file is untouched and is not loaded or migrated. Missing or
invalid current data receives safe defaults. Nonfinite or incorrectly typed live
edits leave the current valid value intact. Automated fixtures isolate
preferences and never write the player's file.

## Framing and speed response

Each profile has start speed, full-effect speed, exponent, and separate
acceleration/deceleration smoothing. The default factor is:

```text
t = clamp((km/h − start_speed) / (full_speed − start_speed), 0, 1)
blend = pow(t, exponent)
start_speed = 0 km/h; full_speed = 200 km/h; exponent = 1.6
```

At 60/100/120/160/180/200 km/h the default factor is approximately
15/33/44/70/84/100%. Connected's vertical FoV is approximately
58/62/64/69/72/75° at those speeds. One smoothed factor blends lens, distance,
height and tilt. Both time constants default to 0.4 s and use exponential
frame-rate-independent integration. Zero time applies the target directly.
The full-effect threshold is constrained to at least 1 km/h above start speed.

Rest/fast FoV is 50–120° in 1° steps. Rest/fast reference tilt is −80° to
+80° in 1° steps: **negative looks down; positive looks up**. Equal endpoints
remove speed-driven tilt changes; descending endpoints are supported.
Slope following adds a broad directional terrain correction to the reference
tilt. Manual look is applied afterward, before the final ±80° optical limit.
Recenter returns to this terrain-adjusted aim. Setting slope following to 0%
restores absolute world-space tilt.

Chase distance is 1–20 m and height is 2–20 m, with 0.25 m steps.
First-person eye height is 1–2 m and full-strength tuck lowering is 0–0.5 m,
with 0.05 m steps. Eye position uses the profile's tuck-motion strength.
V disables automatic speed framing and optional motion, using resting lens,
distance, height and reference tilt while retaining slope following, manual
look and vertical smoothing.

Terrain clearance always wins over the configured position. Chase prefers 2 m
above uphill snow and enforces the existing 1 m final floor. First person keeps
its 0.8 m floor. Bounded boom probes and geology retraction remain in place.
Collision raises or retracts the camera without directly supplying optical pitch.
Uphill terrain following rotates the chase boom around the skier as the aim
rises, retaining the skier in view; the usual snow/rock clearance still wins.
Extreme custom geometry/tilt combinations can crop the skier; preview them before
riding. The preset visibility checks cover ordinary and steep support surfaces.

## Follow, motion and independent look

Expandable groups expose framing, speed response, follow/stability, motion,
shared look controls, forest visibility, and named presets. A graph samples the
same framing evaluator as the riding and preview cameras.

Vertical smoothing remains 0–100%, with a maximum 0.24 s time constant and
bounded lag of 1.5 m in chase and 0.2 m in first person. Horizontal translation
follows immediately. Boom response defaults to 7.5/s and heading response to
5.5/s; these now live in camera preferences. The duplicate physics-workbench
camera response and unused lens tuning fields have been removed.

Slope following defaults to 100%, with 0.35 s of exponential smoothing, in
each view. It reads two terrain secants 8–20 m ahead and behind the rider in
the viewing direction. This measures broad grade rather than local contact
normals, rider bounce or vertical velocity. The estimator uses four bounded
height queries per riding/preview frame; menus and fixed-tilt profiles skip it.
Small near-rider bumps and contact-height steps do not change the grade estimate.
The takeoff slope is held in air and resumes smoothing after landing.

The correction is `slope_follow / 100 * (aim_grade + 15°)`, added to the
configured tilt. First person uses the filtered grade directly. Chase clamps
aim grade at a minimum of −15°: it retains its established steep-downhill view
instead of pointing farther down and cropping the skier. Flat/uphill views rise.
Uphill orbit adjustment uses the same filtered grade.
Directional grade is bounded to ±65°, and the final optical limit stays ±80°.
Shared controls, named presets and existing v2 profiles are retained; the added
numeric settings receive their normal defaults when absent.

Independent 0–100% controls scale existing carve pull-in, tuck movement,
load/landing movement, bank, roll chatter, peripheral blur and speed streaks.
Full-strength carve retains its 0.6 m distance/0.25 m height bounds and
0.12/0.6 s attack/release. Pitch chatter remains disabled while riding.
Speed-streak strength also scales exaggerated precipitation stretching.
Disabling those effects never suppresses the separate impact-reserve warning.

Shared look defaults remain 0.10° per mouse output pixel, stick yaw/pitch
150/100° per second, 0.18 radial deadzone, squared stick response, non-inverted
vertical look, 0.8 s idle recenter delay and 0.35 s return smoothing.
Each is adjustable; automatic recentering can be disabled. Explicit
middle-mouse/R3 recenter remains available. C/R1 changes the riding view.
Chase/summit support full horizontal orbit; first person retains ±120° yaw.

Main owns cursor capture and clears pending look on ownership changes. Held
sticks must return to neutral after pause, restart or view switching. Camera
deadzone/response edits affect only camera sampling, never rider controls.

## Paused riding preview

**Preview camera** uses another camera over the already loaded world, with only
one camera rendering. It preserves gameplay aspect ratio and projection.
A collapsible left drawer shares the normal Camera controls, and its toolbar
provides Hide/Show controls, Exit preview and (from a paused run) Resume skiing.

The 0–300 km/h **Preview speed** slider starts at actual rider speed.
It only changes local framing; the rider, simulation, race timer, recording,
eligibility, weather and audio do not advance. View selection in the drawer
does not replace the retained riding view. First-person preview hides the body
just like actual first person. This is a stationary framing review; it cannot
establish moving camera comfort.

Tab changes, preview exit, restart, loading, focus loss and quit release preview
ownership, discard pending look and reset camera/weather temporal history.
Returning to gameplay primes the riding camera using actual speed.
Ordinary title/pause/results cameras, summit overview, crash and race survey
retain their own framing. Gameplay instruments return after menus; the controls
footer remains menu-only.

## Validation

Run serially through `scripts/run_guarded.ps1`:

- `tests/camera_profiles_suite.gd`: validated bounds, progression, profile
  independence, named presets, working copies and isolated persistence.
- `tests/camera_suite.gd`: framing, preset projection, manual look, motion
  strengths, collision, speed/vertical response at 30/60/120/240 Hz, and bounded
  pitch through bumps, airtime and landing.
- `tests/camera_slope_suite.gd`: directional uphill/downhill/traverse framing,
  skier and 20 m route visibility, slope response at 30–240 Hz, takeoff hold,
  landing recovery, fixed-tilt option and preview isolation.
- `tests/runtime_suite.gd`, `tests/interface_suite.gd`,
  `tests/menu_camera_suite.gd`, `tests/physics_suite.gd`, and
  `tests/foliage_sight_suite.gd`: integration and unaffected boundaries.

Native menu review uses `tests/camera_settings_playtest.gd` with
`--views --version=15 --ui-staged-loading --camera-settings-menu-only` at
1280×720. The full 3840×2160 review omits the menu-only flag and adds
`--camera-motion-capture`. It covers all presets/views at 0, 60, 120, 160 and
200 km/h on upper, steep and forest terrain, plus real 120 Hz solver turn/brake,
jump/landing and steep clips, and clearly labeled synthetic bump sequences.

`tests/camera_performance_descent.gd` preserves the production benchmark hooks.
`--camera-matched` fixes 60° FoV, 3.5 m distance/height, −45° tilt, 75%
stabilization and motion off. An explicit `--camera-baseline-script` can load
the frozen pre-change camera from ignored review artifacts for a matched
comparison; this is a test fixture, not a production compatibility path.
Matched mode also disables slope following to preserve that absolute framing.
Omitting these flags measures Connected. Use a current successful input trace,
3840×2160 High, Auto FSR 75%, cap 120, frame generation/SDFGI off, and report
actual pixels, rendered p95/p99, CPU/GPU, camera cost and memory without captures.

Automated correctness, rendered framing, measured performance, and physical
controller/user skiing acceptance are separate. See the
[2026-09-11 validation report](CAMERA_V2_VALIDATION.md). Raw evidence is recorded
under `artifacts/camera_v2/` and the labeled `artifacts/pc_environment/` directories.


### Slope-following correction, 2026-09-11

All 3,708 checks passed through the serial guard: slope 650, camera 766,
profiles 1,971, interface 114, runtime 187, menu camera 20. The slope fixtures
cover all presets and views through 200 km/h on grades from −50° to +45°,
including projected rider/ski-tail visibility, 20 m forward terrain, clearance,
30/60/120/240 Hz transitions, airborne hold and preview isolation.

`tests/camera_slope_playtest.gd` produced 49 successful native 3840×2160
captures on Standard v15 seed 849205174, High, Auto FSR 75%, frame generation
and SDFGI off. Evidence: `artifacts/pc_environment/camera_slope_final/`;
guard logs use `camera_slope_*` labels. The matrix covers all presets and
both views at 0 and 120 km/h on flat, downhill and uphill terrain. On the
captured 41.25° hill, Connected chase retains −45° aim downhill and raises
it to +11.25° uphill; flat aim is −30°. The skier remains in frame and the
route ahead is visible. Local snow can still partially occlude the skis;
this correction does not change snow relief or equipment placement.

Two four-second sequences use the actual 120 Hz solver and 60 Hz camera,
with 120 captured frames each at 30 fps. Chronological review covers uphill
deceleration from 60 km/h through stopping and reversing downhill, separately
from frozen framing. The paused uphill preview uses the same terrain response.
The earlier full-grade chase experiment was rejected during rendered review
because it cropped the skier on steep descents; the final chase limit above
preserves downhill visibility.

These captures include readback overhead and do not establish current rendered
performance. The historical v2 benchmark predates slope following; no new
capture-free performance comparison is claimed here. Physical controller feel
and user skiing acceptance remain unverified.

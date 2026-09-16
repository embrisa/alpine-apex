# Camera and interface

## Test Cases

Open **Test Cases** from the game menu, choose **New recording**, set independent
scenario controls, then select a summit face and drop in using normal riding input.
During a take, **F9** or controller **Start** opens the paused Test Controls panel;
**F10** or **Save & review** saves completed coverage. The recording overlay shows
actual speed, held target (when enabled), immunity and collision settings.

| Recording control | Meaning and default |
|---|---|
| Speed / Set speed now | One magnitude change, 0–300 km/h; default natural speed. It preserves travel direction, using heading at rest. |
| Hold target speed | Off by default; 1–300 km/h restored before each skiing tick. Gravity, braking and physical impacts still resolve normally within the step. |
| Immortality | Off by default. Enabling fills reserve; damage/crashes are prevented while impact reactions and diagnostic severity remain. Disabling resumes ordinary damage from full reserve. |
| Tree collisions | On by default; switch physical tree contact without hiding trees. |
| Rock collisions | On by default; switch placed rocks and formations without hiding them. Terrain, exposed rocky ground, props and boundaries stay active. |

Paused changes apply in order on the next recording tick. Re-enabling an overlapping
category is rejected until the rider/equipment is clear. Speed and immortality are
unavailable during a crash; collision switches remain available. New takes retain
session settings but never repeat a consumed one-shot speed command. Leaving test
mode resets the diagnostic controls.

Review offers a tick-aligned scrubber, play/pause, 0.1×/0.25×/0.5×/1×/2× rates,
individual physics-tick and captured-frame steps, and orange control-event markers.
Set In/Out and loop the interval; the timeline displays duration and original times.
**Save selected clip** accepts a title and optional observed/expected behavior notes.
It creates another standalone case; **Copy path** and **Open folder** expose it.

Switch recorded/free camera at any time, including while paused. In free view,
right-drag orbits, middle-drag pans and the wheel zooms. **Control free camera**
captures the mouse for look and WASD/QE movement; Escape returns to the panel.
**Focus skier** recenters on the captured rider. **F9 / Hide controls** clears the
view. Controller navigation uses existing focus and text entry: A activates, B
backs out, shoulders step one second and triggers scrub. While controlling the
free camera, sticks move/look and triggers move vertically; B returns to controls.
Review and panel input is consumed before riding input.

The displayed poses and camera are saved evidence reconstructed in the current
renderer; live skiing and ragdoll simulation stay disabled in review. Audio/video
fidelity is outside this format. Storage ownership is documented in
[Racing](RACING.md#diagnostic-test-cases), and agent commands in
[Validation](VALIDATION.md#recorded-bug-cases).

## Internal build identification

The title/pause menu shows the process's frozen Dev ID and compatibility labels.
**Tools → Copy build details** copies the full commit, modified fingerprint,
compatibility numbers, tuning hash and actual engine identity through the ordinary
controller focus flow. Identity failures are explicit; restart after code changes.
[Version policy](DEVELOPMENT.md#internal-development-versions) owns numbering,
notes and package metadata. Patch notes are outside the game for now.

## Ownership and navigation

`main.gd` chooses one rendering camera: riding, menu, race/navigation survey or paused
preview. UI dispatches existing owner actions; it does not acquire physics,
race, mountain-generation or save authority. `hud.gd` routes title/pause/crash/
results and tool surfaces. `menu_navigation.gd` owns focus scopes, repeat,
topmost Back, device switching and virtual text entry. MountainLibrary,
RaceWorkshop and CompetitivePanel retain their data/lifecycle responsibilities.

Settings categories are Display, Graphics, Camera, Controls, Audio, Interface &
HUD, Weather and Rider. Display preview is a transaction; other live settings
must not overwrite its draft. Interface sound volume and shell scale/safe-area
sliders apply every step immediately but write their preference file once,
0.4 s after the last change (and on drag end or scene exit), not per step.
Action buttons draw their badge once and animate the primary pulse through an
overlay's modulate; derived badge styleboxes are cached per reserve width. Graphics preset application is described in
[Rendering](RENDERING.md#graphics-and-display). UI controls cannot regenerate
physical terrain merely because a display/presentation preference changed.

The responsive shell uses output pixels, scrolling groups and controller focus.
Resolve nested popups/dialogs before the parent page; Back must not resume a run
while dismissing a child scope. Text entry owns typing and can use the controller
keyboard. Shoulder navigation keeps the selected small-screen category visible.
Endpoint terrain picking remains explicit pointer input. The controls footer is
menu-only, including summit staging; compact start/pause cards and crash actions omit it. The Controls page retains the full shortcut
inventory.

Weather settings expose six conditions, time bands, independent automatic and
next-launch controls, Rare storms and lightning Full/Reduced/Off. Manual choices
apply immediately; next-launch toggles leave the current scene alone. Race
controls show a latched practice reason when authored visibility is changed.
Defaults, persistence and clock behavior belong to [Weather](RENDERING.md#weather);
eligibility and restoration belong to [Racing](RACING.md#records-and-compatibility).

## Session navigation map

Map / Navigation in the summit and pause menus opens the existing rendered
overhead survey without creating a race. `race_workshop.gd` owns this camera;
`session_navigation_panel.gd` owns its drawer and explicit terrain focus mode.
Opening holds completed rider/session state and weather/audio progression.
Back returns to the originating menu; opening directly from active summit
staging returns there without a respawn. Resume uses the normal input neutral
gates, so held map controls cannot become the next skiing input.

Place up to 32 violet beams. Select a numbered map point or a list row to move
or remove it; Clear all removes only personal points. Hide/Show changes beam
visibility immediately and keeps the editable map list/numbers. A full list
reports the limit and never discards an older point. Moving is a preview until
confirmed; Back first cancels a pending move, then leaves terrain mode, then
returns to the previous menu. There is no automatic removal when passing points.

Mouse clicks outside the drawer add/select points; WASD/arrows pan and the wheel
zooms in terrain mode. Right-click resumes terrain controls; Tab returns to the
panel. On a controller select Add point or Move selected, release Select, then
use the left stick to pan, right stick up/down to zoom and the south button to
confirm at the visible reticle. The west button returns to the panel; east/Start
backs out. Drawer focus, focus loss and device changes suspend map input; stick
neutral and confirm release gates prevent carried controls from placing points.
Race endpoint terrain picking remains pointer-only.

`racing/session_navigation.gd` is a memory-only list held by SceneTree metadata,
keyed by the entire canonical physical mountain reference. The same mountain
retains IDs/positions/visibility through retry, summit return, race/free-ski
changes and scene rebuilds. Binding a different physical reference clears it,
even for the same seed; application exit destroys the owner. There are no
navigation files or additions to mountain/race/share/replay/record data.

`presentation/session_navigation_beams.gd` owns personal meshes separately from
race marker cleanup. It uses the shared explicit beam style: violet, 1,600 m
height with top fade from 1,250 m, 3.5 m radius, natural depth/fog and no dense
race halo, shadow, GI, collision or world text. Add/move only rebuilds the changed
shaft; normal frames do no marker terrain rebuild. Reduced Motion uses the
existing beam effect group. Numbers/selection/reticle exist only on the map.
Native distance/readability/cost and real-controller usefulness require the
separate validation evidence; implementation dimensions alone do not prove them.

## Controller prompts

`ui/menu_navigation.gd` detects the active input device before initial loading,
then follows meaningful button, stick, keyboard and mouse activity. Connect selects
a pad when keyboard is active; disconnect selects another attached pad or falls
back to keyboard. Scene reload retains the last-used device. Stick/trigger values
below 0.25, negative trigger rest and mouse movements of at most three pixels do not switch
prompts. Menu navigation retains its separate 0.60 activation / 0.35 release gates.

`ui/controller_prompts.gd` owns Xbox, PlayStation and generic controller names.
Detection uses the mapped/raw names and Sony/Microsoft vendor or XInput metadata
from [Godot Input](https://docs.godotengine.org/en/stable/classes/class_input.html#class-input-method-get-joy-info).
Unknown devices use positional button names. A virtual controller that exposes
only an Xbox identity is shown as Xbox; the hidden physical brand cannot be
inferred. This changes presentation, not SDL mappings or rider sampling.

Controls, loading hints and summit drop-in help read gameplay actions from
`InputMap`; menu prompts describe navigation's logical buttons. Device changes
refresh existing Controls labels without rebuilding focus/scroll state. The
summit hint names forward tuck or the south button for drop-in, never the hop
trigger. Keyboard-only tools remain explicitly labelled in the Controls guide.

`tests/controller_prompts_suite.gd` exercises detection, hotplug, multiple pads,
noise, reloads and the actual guide with simulated devices; a native invocation
captures the Xbox/PlayStation/generic/keyboard pages in
`artifacts/controller_prompts/`. Physical Xbox and PlayStation testing remains
separate from those automated and rendered checks.

## Visual language and HUD

`alpine_theme.gd` and `angular_style_box.gd` own cached white translucent panels,
navy/slate text, cyan selection and green/amber/red semantic accents. Opposing
clipped corners retain their 2:1 slope and full rectangular hit targets. World
HUD and photographic loading use their separate bright text palette; menu ink
colors must never darken those overlays. Color supplements descriptive status.

`compact_menu.gd` retains Ride, Explore and Tools pages inside a content-sized
left card: at most 420 logical pixels / 36% of usable width and 75% of usable
height. Overflow scrolls. Start leads with Drop in; pause with Resume and Try
again. Settings has its own entry and Quit Game a separate bottom entry; Tools
contains diagnostics, Test Cases and build details. Settings and specialized
workspaces retain larger layouts and return to their originating card/focus.
Compact cards omit full-screen branding, edge shading and navigation footers.

`action_button.gd` keeps native click/focus behavior and a separate bind badge.
Gameplay shortcut badges read InputMap; logical Back uses Esc/controller east.
Unbound actions fall back to a focused confirm badge. Device changes refresh
existing buttons without changing text, focus or row geometry. Direct restart
is available in the compact pause card; child tools/popups retain input priority.
Primary cards pulse gently, presses flash their border, and important HUD
status/split changes briefly emphasize the existing readout. Reduced Motion
settles all transitions. Photography remains limited to loading.

**HUD backgrounds default off.** Optional backgrounds use the Interface & HUD
preference. Keep normal-weight text, an 11-logical-pixel minimum and a faint
one-pixel shadow. The user rejected heavy dark outlines/edging; text, gauges
and riding screen edges remain restrained. Debug follows the same background
choice; transient notice frames disappear with their notices. World markers,
menus/errors/loading and full-screen impact warning are separate.

`hud_layout_v1.cfg` stores each widget's visibility, normalized travel inside
the safe area, uniform .5–2 scale and opacity. `interface_layout_v1.cfg` stores
.85–1.4 requested UI scale, 0–8% safe area and backgrounds. Bound effective scale
for small screens and clamp whole widget rectangles on resolution changes.
Timed instruments hide in free ski, debug defaults off, and H hides temporarily
without overwriting persisted choices. Loading/reload handoffs retain layout.

Riding frames only do interface work whose inputs changed. Widget layout
re-applies on size, safe-area, race-mode, menu, preview or transient-notice
changes (`hud_layout.gd` compares the last applied state); personal best,
altitude/weather, split, run-context and course-spec text format when their
values change; the impact tint override applies on change; the 10 Hz telemetry
string is built only while the debug panel is visible; while every instrument
is hidden behind a menu or H, `update_hud` keeps the retained readouts and
returns after its notice timers. The crash card formats its clock and buttons
once per changed input rather than per 120 Hz tick. `main.gd` builds the mode
label and controls footer once per frame from cached prompts and a cached menu
background state that registered views refresh through `visibility_changed`.
`menu_navigation.gd` stops its per-frame scope scan while no scope exists and
wakes on any input event, controller connection change, window focus or a
scope owner (panel, popup, loading overlay) changing visibility. Flavor site
discovery rescans only after the rider travels the exact slack measured at the
last scan. Readouts, cadence and focus routing are unchanged.

The speed dial retains its static background arc and threshold marks in separate
CanvasItems, preserving background/fill/mark order. Only speed, tint or size changes
redraw the moving arc; resize invalidates the static layers. Keep the existing
80-point antialiased geometry, live numeric speed, inherited scale/opacity and
input transparency. Native `tests/hud_dial_suite.gd` compares the original paint
sequence and verifies retained drawing through updates and layout changes.

Edit HUD freezes a real world image and reparents the actual composite instrument
wrappers into an aspect-matched preview. Timed/free/low-reserve/near-finish sample
states exercise hidden widgets, which remain list-selectable. Drag or controller
Move/Resize operates whole instruments; Back exits movement mode before cancelling.
Apply saves atomically; Cancel restores the session snapshot. Do not invent a
second approximate HUD for this editor.

## Crash recovery controls

The crash view shows only two bottom-centered text actions: **Stand Up** and
**Try again**, each with its current device bind. Enter/controller south invokes
existing local recovery; R/controller north restarts. Both are clickable. The
minimal view uses direct actions rather than focus selection. An unavailable
Stand Up stays disabled with its reason on the same line (full reason also in
its tooltip); Try again remains available. No tabs, clock block or footer appears.

Esc/controller Menu or east opens the compact crash-pause card and explicitly
holds the recovery clock/ragdoll. Return to crash/Back resumes the action view;
Settings and Tools retain that explicit pause until returning. Focus loss still
holds the clock and disables recovery independently. The underlying clock keeps
running through incidental subpages that did not request pause and through the
ragdoll settle cap. The pause card shows the retained time and paused status.
Menu/crash ownership and camera/audio lifecycle remain active even when the
large working panels are hidden. [Racing](RACING.md#crash-location-recovery) owns
placement, eligibility and exact timing.

Local recovery stops the ragdoll, restores the previous riding view and resets
pose/camera interpolation, player tracks/powder, particles, audio/voice observers,
haptics and screen/weather transients. Existing neutral/release gates rearm
steer, jump, grab, air controls and shared axes, preventing held confirmation
from becoming a jump or pole stroke. Full restart resets the whole attempt.
Navigation remains unavailable during crash/recovery, finish, loading and
transitions; it cannot conceal a running recovery clock behind the map.

## Ghost selection

Records → Ghosts offers Automatic fastest 10 or a manual subset, including an
explicit empty set. Rows show rank, time, UTC date, short stable run ID and a
color swatch; color supplements identity. `ui/ghost_selector.gd` emits selection
intent through the existing menu owner. Choices save for the next start/retry;
current competitors and frozen PB split comparisons stay unchanged. Missing or
evicted choices produce a notice rather than silently replacing a manual set.

G / Show selected ghosts changes current visibility immediately. Hidden ghosts
stop emitting and clear their presentation histories; reenabling starts at the
current time without stamping the missed route. Colors are chosen deterministically
from run IDs and the player's effective clothing/atlas color, then shared with
the selector. Free skiing has no competitive selection. Storage, ordering and
playback lifecycle belong to [Racing](RACING.md#recording-and-ghosts).

## Riding camera

[CameraSettings](../scripts/presentation/camera_settings.gd) owns independent
third-/first-person working profiles and named presets in `user://camera_v2.cfg`.
[ChaseCamera](../scripts/presentation/chase_camera.gd) consumes them at render time.
Device look and forest visibility preferences are shared. Editing a built-in
or named preset creates Custom; Save new/Replace stores explicitly. Reset view
restores Connected; reset-all also restores shared values. Neither deletes named
presets. Names are 1–40 characters and exclude built-in names/Custom. Invalid
typed/nonfinite live edits retain the current valid value. V1 is not migrated.

Connected defaults: vertical FoV 55–75°, chase distance 3–4.5 m, height 3–3.5 m,
reference tilt −45° chase/−25° first person on a 15° descent. Race broadens framing;
Stable fixes it and disables optional motion. Exact profiles/ranges are in the
settings source. FoV/tilt use 1° steps; **negative looks down, positive looks up**.
Working edits save immediately and affect riding without reload.

One frame-rate-independent speed factor blends lens/distance/height/tilt:
`pow(clamp((kmh-start)/(full-start),0,1), exponent)`. Defaults are 0/200 km/h,
exponent 1.6 and .4 s acceleration/deceleration smoothing. Full speed remains
at least 1 km/h above start. Equal endpoints disable that progression component.
The preview graph uses the same evaluator, not its own approximation.

Horizontal position follows immediately; vertical lag is bounded to 1.5 m chase
and .2 m first person, with at most .24 s smoothing. Bounded boom/support/solid
probes raise/retract for clearance; collision does not directly set optical pitch.
Chase prefers 2 m above uphill snow with a 1 m final floor; first person keeps
.8 m. Extreme custom framing can crop the skier.

### Slope following

Default 100% strength and .35 s smoothing use broad directional terrain secants
8–20 m ahead/behind: four bounded height queries per riding/preview frame.
Local bump normals, vertical velocity and rider bounce are not the estimator.
Hold takeoff grade in air; resume smoothing after landing. Menus and zero-strength
profiles skip these queries.

Add `strength * (aim_grade + 15°)` to reference tilt. First person uses filtered
grade directly; chase clamps its minimum to −15° to retain steep-downhill
framing. Chase adds up to 15° more lift on flat terrain, fading linearly to zero
at ±15° grade. The boom orbits with this lift to keep the skier and skis visible;
the existing snow/solid clearance still wins. Uphill orbit adjustment shares the
filtered grade. Directional grade is bounded to ±65° and final optical pitch to
±80°. Zero strength restores absolute tilt and disables the extra flat lift.
For Connected, default flat-ground aim is −15° chase/−10° first person; a 30°
uphill retains 0°/+20°. Manual look applies after slope correction; recenter
returns to the corrected aim.

### Look and motion

Shared defaults: .10° mouse/output pixel, stick yaw/pitch 150/100° per second,
.18 radial deadzone, squared response, .8 s idle recenter and .35 s return.
Explicit middle-mouse/R3 recenter remains available; chase/summit allow full
orbit and first person ±120° yaw. C/right shoulder changes riding view. Main
owns cursor capture; lifecycle/view switches discard pending look and held
sticks must neutralize. Camera response edits never change rider input sampling.

Per-profile strengths scale carve pull-in, tuck, landing/load motion, bank,
chatter, peripheral blur and streaks. Riding pitch chatter remains off. V uses
resting framing and disables speed/motion accents while retaining slope following,
manual look and vertical smoothing. Optional motion controls never disable the
separate impact-reserve warning. Streak strength also scales exaggerated weather
stretching, not physical weather.

Camera > Motion effects also exposes **Motion blur** On/Off and **Motion blur
strength** (0–100%) for each riding view. These are separate from Peripheral
blur and Speed streaks. Off retains strength; zero also bypasses the effect.
All built-ins default Off, with 50% retained in Connected/Race and 0% in Stable.
Live apply, named presets and resets use the same typed profile store. V and
reduced interface motion suppress scene blur, as do inactive riding, pause,
preview, menus, crashes/results, loading, focus loss and transitions. Preview
remains stationary framing only. Unsupported renderers show disabled controls
and a reason. [Rendering](RENDERING.md#scene-motion-blur) owns buffer/order/cost
and the remaining full-resolution validation.

### Forest visibility

Forest visibility is shared by both riding views and the paused camera preview.
Transparency strength controls how much nearby canopy is removed across the
whole screen, including edges and corners (0–100%, 1% steps, default 100%). Aid
reach retains its 0–100% range and 60% default, setting the affected distance
independently. Either at zero disables removal. Trunks remain visible; this does
not change tree population, collision, racing or replay identity.

Edits apply immediately and save with camera preferences; reset-all restores
both defaults. View resets and presets leave these shared controls alone. The
former opening-size field is ignored on load and absent from saved output;
there is no size migration. Shader ownership is in [Rendering](RENDERING.md#terrain-forests-and-lighting).

## Menu and preview cameras

[MenuCamera](../scripts/presentation/menu_camera.gd) is render-time over the loaded
world. Title alternates player shots and up to six validated spatially separated
landform views, 24 seconds each with a .7 s world-only fade. Player defaults
are 60° FoV, 9 m boom, 4.5 m height and 4°/s orbit. Terrain/solid clearance wins;
invalid scenic pools fall back to player framing. Libraries/settings retain
their originating context rather than restarting the sequence.

Pause/results stay local. Crashes follow the moving ragdoll, orbiting only after
its freeze. Reduced interface motion holds the viewpoint and suppresses cuts/
fades, except necessary moving-crash following. Menus show the skier regardless
of riding first-person preference. Leave-menu handoff cancels fades, selects/
primes riding camera immediately, clears look and resets weather history.
Weather receives the actual active camera and explicit first-person state.

Paused camera preview uses one aspect-matched camera over the existing world.
Its collapsible drawer shares Camera controls. Preview speed (0–300 km/h) changes
only local framing; view selection leaves the retained riding view untouched.
Simulation, race clock/recording, eligibility, weather/audio progression remain
held. Exit returns to settings; Resume is offered from a paused run. Tab change,
exit, restart, loading, focus loss and quit release ownership and prime normal
history. Stationary preview does not establish moving comfort.

## Loading and feedback

Loading observes the generation job's stage/work/error/cancel snapshot; it does
not own the job. Known totals yield percentages; unknown work stays indeterminate.
Elapsed and remaining estimates retain explicit labels. No artificial minimum
loading delay. Cancellation waits for the current cooperative work; real errors
display verbatim, hide the progress pulse and do not trigger automatic retries.

`loading_content.gd` derives tips/device bindings from actual production behavior:
holding forward pushes at low speed and tucks at speed, hop is release-to-jump,
centered stick flips do not require L1, and air rotation does not assign flight
trajectory. No invented marketing
claims or photograph locations. Tips hold eight seconds with .25 s fades; stage
changes do not restart their timer. Reduced motion settles fades, freezes photo
motion and centers the indeterminate marker. Loading wind is separately owned
by [Audio](AUDIO.md#source-audio-and-provenance).

`interface_feedback.gd` allocates six deterministic PCM cues once and three
player slots (navigation, adjustment, actions), with bounded repeat admission
and no queues/per-event synthesis. Canonical hover/press/back/adjust/success/error
and aliases live in the source. Unknown IDs return false. Actions clear obsolete
voices and suppress soft repeats; volume/mute/disable cancel immediately.
`play()`/`cue_played` report dispatch, not hardware sound. Headless admission
executes silently. Opacity-only reveals preserve geometry/focus/hit testing;
new reveals, lifecycle and reduced motion cancel obsolete tweens.

Continuous camera comfort, real-controller menu/HUD editing and listening remain
separate from [native interface evidence](VALIDATION.md#presentation-evidence).

## Startup

`startup.tscn` owns a one-shot presentation above the existing loading/menu flow.
The approved `assets/images/branding/alpine_apex_ice.svg` stays authoritative.
Each launch randomly selects one of the six supplied photographs in
`assets/images/startup/manifest.json`, using a private presentation RNG. Only the
chosen texture is loaded and shared with the remaining loading screen. A single
light sweep, four depths of white directional snow and icy wind gusts frame the unchanged
logo. Snow uses one optional canvas pass; static glacial facets
serve only as a missing-photo fallback. Copy is limited to factual loading/error
status and a skip instruction.
No tagline or invented location is shown.

The reveal uses monotonic wall time for 1.85 seconds plus a .28-second dissolve;
elapsed time remains real-time even when the engine clamps its frame delta. Main-thread stalls can still delay a presented frame or dissolve. Readiness always
wins: a ready menu immediately receives input, with no minimum display timer.
After .45 seconds, a fresh key, mouse button or controller button accelerates the
handoff; mouse movement, axes and key repeat do not. Skip cannot expose an absent
destination or cancel the mountain job. Longer initialization uses the existing
photography/tips/progress/elapsed/error flow. Reduced Motion keeps the logo and
static photography, removes snow, gusts, scale and light movement, and retains soft opacity
transitions. The main-menu world and camera own their existing behavior.

The opening does not recur on world reload: the current scene becomes `main.tscn`.
Optional audio/shader failures retain the brand, a solid background and working
handoff. Main-scene failures expose Retry/Quit. Development build identification
runs separately from menu construction; Copy build details becomes available
when its frozen result is ready. It never supplies a placeholder identity to
records or cases. See [startup evidence](VALIDATION.md#startup-evidence) for commands and acceptance boundaries.

Fullscreen is the supported project window mode from process creation. Startup
applies the saved Display preference before creating the opening or loading
resources. Explicit windowed choices remain authoritative. Reapplying an already
matching display state no longer toggles through Windowed during initialization.

The startup path defers only distant decorative scenery and terrain-grass setup
until the existing menu releases its loading shield and restores focus. Terrain,
forest/mineral collision, structures, rider setup and camera preparation remain
essential. Direct-main scene loads retain their normal build order.

`menu_cosmetics.gd` owns optional threaded resource reads and pure data work,
independently of LoadingOverlay. Decorative mesh loops yield cooperatively at
a 2 ms CPU budget between samples/rows; GPU submission still occurs on the main
thread. A menu quality change is applied before publishing the initial wilderness
candidate. Neither cosmetic completion nor its elapsed duration reopens loading
progress, blocks menu actions or advances simulation.

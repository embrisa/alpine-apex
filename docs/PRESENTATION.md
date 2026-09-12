# Camera and interface

## Ownership and navigation

`main.gd` chooses one rendering camera: riding, menu, endpoint survey or paused
preview. UI dispatches existing owner actions; it does not acquire physics,
race, mountain-generation or save authority. `hud.gd` routes title/pause/crash/
results and tool surfaces. `menu_navigation.gd` owns focus scopes, repeat,
topmost Back, device switching and virtual text entry. MountainLibrary,
RaceWorkshop and CompetitivePanel retain their data/lifecycle responsibilities.

Settings categories are Display, Graphics, Camera, Controls, Audio, Interface &
HUD, Weather and Rider. Display preview is a transaction; other live settings
must not overwrite its draft. Graphics preset application is described in
[Rendering](RENDERING.md#graphics-and-display). UI controls cannot regenerate
physical terrain merely because a display/presentation preference changed.

The responsive shell uses output pixels, scrolling groups and controller focus.
Resolve nested popups/dialogs before the parent page; Back must not resume a run
while dismissing a child scope. Text entry owns typing and can use the controller
keyboard. Shoulder navigation keeps the selected small-screen category visible.
Endpoint terrain picking remains explicit pointer input. The controls footer is
menu-only, including summit staging; the Controls page retains the full shortcut
inventory.

Weather settings expose six conditions, time bands, independent automatic and
next-launch controls, Rare storms and lightning Full/Reduced/Off. Manual choices
apply immediately; next-launch toggles leave the current scene alone. Race
controls show a latched practice reason when authored visibility is changed.
Defaults, persistence and clock behavior belong to [Weather](RENDERING.md#weather);
eligibility and restoration belong to [Racing](RACING.md#records-and-compatibility).

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

`alpine_theme.gd` and `angular_style_box.gd` own cached styles/icons and the shared
navy/cold-white/ice-blue angular language. Opposing clipped corners use a 2:1
slope and scale down for small controls. Focus/hover/selected styling preserves
content margins and the full native rectangular hit target. Photography appears
only during actual loading; ordinary menus show the loaded world.

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

Edit HUD freezes a real world image and reparents the actual composite instrument
wrappers into an aspect-matched preview. Timed/free/low-reserve/near-finish sample
states exercise hidden widgets, which remain list-selectable. Drag or controller
Move/Resize operates whole instruments; Back exits movement mode before cancelling.
Apply saves atomically; Cancel restores the session snapshot. Do not invent a
second approximate HUD for this editor.

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
framing. Uphill orbit adjustment shares that grade. Directional grade is bounded
to ±65° and final optical pitch to ±80°. Zero strength restores absolute tilt.
For Connected, default flat-ground aim is −30° chase/−10° first person; a 30°
uphill gives 0°/+20°. Manual look applies after slope correction; recenter
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
tuck reduces drag, hop is release-to-jump, centered stick flips do not require
L1, and air rotation does not assign flight trajectory. No invented marketing
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

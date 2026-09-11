# Interface windows and loading

The interface refresh on `codex/ui-workspace-loading` gives each activity its own
space while retaining the existing skiing, race, mountain and graphics contracts.

## Navigation

| Window | Tabs / actions |
| --- | --- |
| Main menu | Ride, Explore, Tools |
| Settings (Tools) | Display, Weather, Rider, Camera, Skier Voice, Interface, Controls, Audio |
| Mountains (Explore) | Create, Saved, Share; large terrain preview beside the controls |
| Races (Explore / F4) | Saved races, Import & share; separate in-world creation view |
| Personal best (Explore / F6) | Overview, Splits, Run history |
| Workbench (Tools / F2) | Handling, Forces, Feedback, Speed lab |

Settings and the workbench have fixed Back/Close buttons outside their scrolling
tab content. Tab/arrow navigation, focus outlines and Escape remain available.
Settings and records restore focus to their main-menu entry. The controls footer
appears only in menus and stays hidden while riding, including summit drop-in.
The Controls tab contains the complete shortcut list.

Menus show the loaded game world. The current layout, panel opacity, branding,
tabs and navigation are retained; photography and photo captions appear only
inside actual loading screens. The world-only transition cover ignores mouse
input and sits below all controls.

The main menu alternates the summit player with up to six validated mountain
views: 24-second shots and a 0.7-second fade through dark. Player shots orbit at
4 degrees/second, initially 9 m away and 4.5 m above the skier, with a 60-degree
FOV. Terrain and solid clearance override that framing. Pause/results orbit the
current player; crashes follow the ragdoll until its existing 15-second freeze,
then orbit its resting position. Settings, workbench, libraries and records
inherit the menu context without restarting the sequence. Endpoint placement
alone uses the controllable survey camera.

Reduced interface motion holds the current live viewpoint and suppresses cuts
and fades; a moving crash can still be followed. Clouds and precipitation animate
in ordinary menus, while the paused simulation, race timer, impact reserve,
daylight progression and automatic weather cycle remain held. Resume, Drop In
and Retry cancel outstanding fades and restore the selected riding view before
another simulation tick. Camera and weather history are reset at handoff.

The camera owns no mountain data or save state. Viewpoints consume the current
landform metadata, falling back to terrain-sampled summit views on archived
mountains and to a safe player view when no scenic shot passes clearance checks.
See [camera behavior and validation](CAMERA.md#live-menu-camera).

The Camera tab provides separate third-person and first-person profiles.
Connected defaults to 55°–75° vertical FoV, a 3–4.5 m chase distance,
3–3.5 m height, and steady −45° chase / −25° first-person aim. Race opens
visibility; Stable fixes framing and disables optional motion. Expandable groups
expose framing, speed progression, follow/stability, individual effects, shared
look controls, foliage visibility and named presets. Negative tilt looks down;
positive looks up, in 1° steps. Device look and forest preferences are shared.

Working edits save automatically in camera_v2.cfg. Editing a preset creates a
Custom working copy; Save new/Replace explicitly store named copies. View/all
resets retain saved presets. A small graph shows the delayed default progression
(44% at 120 km/h; 70% at 160; full at 200).

Preview camera opens a collapsible left drawer over the paused riding view.
Preview speed changes only framing, and view selection leaves the riding view
untouched. Exit returns to settings; Resume skiing is offered from a paused run.
The preview retains normal gameplay aspect ratio with one rendering camera.
Keyboard/controller focus follows the scrolling content. Settings remain usable
without preview; crashed/loading states disable preview.
See [camera behavior and controls](CAMERA.md) and the
[camera profiles and preview validation](CAMERA_V2_VALIDATION.md).

## Angular visual language

The interface shares the Alpine Apex logo's hard edges and diagonal cuts. Large
panels use opposing top-left/bottom-right 24 by 12 logical-pixel cuts; buttons,
tabs and fields use 12 by 6. All cuts keep a 2:1 slope and shrink proportionally
when a control or progress fill is small. The navy, cold-white and ice-blue
palette, photography and existing tab layouts are retained.

`scripts/ui/alpine_theme.gd` owns the shared theme, cached style resources and
small control icons. `scripts/ui/angular_style_box.gd` draws the polygon fills
and antialiased borders in canvas coordinates, keeping them sharp at native 4K
UI output. Icons are generated once from simple SVG geometry at four times
their logical dimensions. No additional photographic assets are needed.

Primary actions carry a double-chevron. Active tabs carry a small angled marker.
Keyboard focus uses a two-pixel outline, with a dark outline on light primary
actions for contrast. Hover, pressed, disabled and selected states keep identical
content margins, so interaction does not move text or change layout. Clipped
corners retain the full native rectangular click target.

The theme covers menu and tool panels, dropdowns and popup contents, toggles,
checkboxes, fields, lists, sliders, scrollbars, Godot file dialogs, color-picker
controls and loading. The mountain preview shares the panel silhouette. Skiing
keeps the speed dial and instrument positions; course/impact bars and footer
framing carry the angular treatment. The summit-return caption uses a matching
frame. Progress remains tied to actual work and retains its original values.

Standalone art validation includes a native control gallery at 1280x720,
1440x900 and 3840x2160, pointer activation at a clipped corner, keyboard slider
input, popup/dialog captures, text selection and zero/tiny/half/full progress.
The interface integration suite additionally captures rider color controls,
mountain file dialogs and a short unranked laboratory descent with the HUD.
An optional `--ui-baseline-hud=path/to/saved_hud.gd` argument accepts a saved pre-change
HUD script for a comparison over the same paused mountain at 4K. Both HUD
instances remain resident during that comparison; only one is visible at a time.

### Angular styling acceptance — 2026-09-08

- Automated: standalone interface review **80/80** and native integration
  **51/51**, with no engine errors in the final guarded runs. Hover, clipped-corner
  clicks, keyboard sliders, focus restoration, reduced motion, staged loading,
  disabled library actions and progress values passed.
- Rendered: **27** standalone captures and **28** integration captures. Inspected
  menu/control layouts at 1280x720, 1440x900 and 3840x2160; settings, dropdowns,
  file-dialog title framing, color pickers, mountain preview and the HUD during
  a short fixed-input unranked laboratory descent. The speed dial stays circular.
- Performance: same paused v11 mountain, RX 9070/D3D12, High, 3840x2160 output,
  2880x1620 FSR2 internal resolution, 120 FPS cap and GI off. Each paired sample
  used 120 warmup frames and 240 measured frames without screenshot overhead.

| Paused interface metric | Previous UI | Angular UI |
| --- | ---: | ---: |
| Mean frame time | 8.333 ms | 8.333 ms |
| Frame p95 / p99 | 8.384 / 8.454 ms | 8.389 / 8.443 ms |
| Render CPU mean | 1.120 ms | 1.225 ms |
| GPU mean | 5.323 ms | 5.286 ms |
| Engine video memory | 5328.24 MiB | 5330.12 MiB |
| Engine static memory | 638.85 MiB | 638.90 MiB |

This short sample maintained the 120 FPS cap; CPU render time increased by
about 0.105 ms. It does not establish descent performance. Both HUD instances
were retained for the paired draw comparison, so its memory figures are not
isolated per-theme allocations. Concurrent loading-atmosphere work was preserved;
the paired paused-HUD sample is the relevant comparison for this styling change.

Evidence and source hashes are in `artifacts/ui_angular/validation.json`; the
guarded logs are under `artifacts/guarded/angular_art/` and
`artifacts/guarded/angular_integration/`. Captures and full timing distributions
remain in `artifacts/interface_art/` and `artifacts/ui_refresh/`.

Human acceptance of styling and hands-on keyboard/controller feel remains open.
The rendered descent is inspection evidence, not a claim of user skiing approval.

Reproduce the rendered reviews from PowerShell:

```powershell
./godotw.ps1 --script tests/interface_art_playtest.gd
./godotw.ps1 --script tests/interface_suite.gd '--' --ui-staged-loading --graphics-quality=high
# Optional paired comparison, when the saved pre-change HUD is available:
./godotw.ps1 --script tests/interface_suite.gd '--' --ui-staged-loading --graphics-quality=high --ui-baseline-hud=artifacts/ui_angular/source_before/scripts__ui__hud.gd
```

## Sounds and motion

`scripts/ui/interface_feedback.gd` creates four short PCM cues at initialization:
hover/focus, activation, completion and error. A pool of three audio players keeps
playback bounded. Hover is rate-limited; UI construction does not trigger sounds.
Panel and tab reveals fade in over 160 ms. No animation drives skier movement.

Tools → Settings → Interface exposes UI volume, a preview sound, mute, reduced
interface motion and the existing skiing camera-effects toggle. M synchronizes
skiing audio and UI mute; muting stops an active UI cue. Reduced motion skips fades
and holds the unknown-progress indicator still. Volume, mute and reduced motion
persist in `user://interface_preferences.cfg`. Script/headless/autoplay runs do
not read or write these personal preferences. Camera-effects selection survives
mountain changes along with the existing graphics/weather/tuning snapshot.

## Loading architecture

Atmospheric loading adds photo drift, photo-matched moving glare/rays/lens flare,
32 drifting snow motes and optional quiet wind. **Loading wind ambience** has a
separate Interface switch and also obeys Interface volume and global mute.
Reduced motion holds the photo/light steady, removes motes and skips tip fades.
Tips rotate every eight seconds; elapsed time only appears after eight seconds.
The timer retains layout space and progress remains tied to real work. See
[loading artwork and verification](MENU_ART.md#loading-atmosphere--2026-09-08).
Cold startup and the HUD share the same preference reader; live changes and
scene reloads retain wind, volume, mute and reduced-motion values. Loading audio
and visual resources are released on completion or teardown.

`scripts/ui/loading_overlay.gd` is a scene-owned CanvasLayer above the HUD. It
exists before world construction and reports the current operation plus elapsed
time. Generation/import/reconstruction use an indeterminate indicator. Terrain
construction reports completed sections, using actual chunk counts rather than
a guessed overall percentage. The loader covers startup, seed generation, saved
mountains, mountain files, shared-race imports and scene changes.

Interactive initialization uses a worker for Node-independent mountain/scenery
data. Meshes, materials, Nodes and texture uploads stay on the main thread. The
existing mesh builder yields to drawing after each eight terrain chunks and
between asset/environment/backdrop/scenery phases. This follows Godot's
[thread-safety boundaries](https://docs.godotengine.org/en/stable/tutorials/performance/thread_safe_apis.html).
The mesh vertices, indices, LODs, authoritative 4 m contact surface and generator
implementations are unchanged.

`main.gd` gates input, simulation and presentation until initialization completes
and while the overlay is busy. It blocks duplicate world transitions. Loading
reconstructs a cross-mountain race once and passes that prepared surface through
the scene reload. Recoverable import/reconstruction failures return to the
existing UI; workers are joined on teardown. Closing the application during a
generation may wait for its bounded data job to finish.

Existing script suites retain synchronous startup by default. The explicit
`--ui-staged-loading` test flag exercises the interactive staged startup and world
reload path. This is cooperative loading, not streaming or asynchronous GPU
upload: individual material/shader, backdrop and scenery operations can still
pause the animation. Generation currently has no Cancel action.

## Validation — 2026-09-07

Commands below use the Windows `godotw.ps1` counterpart to `godotw`:

```powershell
./godotw.ps1 --headless --script tests/physics_suite.gd
./godotw.ps1 --headless --script tests/runtime_suite.gd
./godotw.ps1 --headless --script tests/race_suite.gd
./godotw.ps1 --headless --script tests/mountain_library_suite.gd
./godotw.ps1 --headless --script tests/interface_suite.gd '--' --graphics-quality=low --ui-staged-loading
./godotw.ps1 --script tests/interface_suite.gd '--' --graphics-quality=high --ui-staged-loading
```

Automated results: physics **56/56**, runtime **93/93**, race **51/51** and mountain
library **48/48**. The final native interface pass completed **43/43** assertions
and wrote 22 screenshots. An earlier headless staged interface pass completed
38/38 before the three shared-race import assertions were added to the native
pass. The intentionally malformed race-code fixture logs a JSON parse error;
the check verifies that it leaves the saved race intact and releases the UI.

Interface checks cover navigation, bounds, return focus, mute/motion state,
loading input blocking, disabled duplicate actions, generation completion,
invalid seed/code recovery, shared-race import, and a complete staged v4 reload.
The loaded world retains all 576 terrain chunks / 4,718,592 triangles. Existing
mountain tests additionally verify archived recipes, Technical Showcase v7,
graphics/tuning retention and unchanged personal-best files.

Rendered evidence: native Godot 4.7.2 / RX 9070 captures were inspected for menu,
settings, workbench, race import, mountain preview and loading layout. Captures
include actual 1440×900, 1280×720 and 3840×2160 output. Logs, screenshots and JSON
reports are under `artifacts/ui_refresh/`; `interface_native.json` contains the
final assertions and measurements.

Performance evidence: the final short sample of the Display window over a paused
v4 summit used High, 75% FSR2 (2880×1620 internal / 3840×2160 output), 120 FPS cap,
GI off. After 120 warmup frames, 240 frames without screenshot overhead measured:

| Metric | Final sample |
| --- | --- |
| Mean frame time / equivalent FPS | 8.397 ms / 119.1 FPS |
| Frame p95 / p99 | 8.513 / 18.068 ms |
| Render CPU mean / p95 / p99 | 0.988 / 1.373 / 1.621 ms |
| GPU mean / p95 / p99 | 5.604 / 5.747 / 7.364 ms |
| Reported video memory | 2,569,785,344 bytes |
| Godot static memory | 286,946,439 bytes |

This brief paused-view sample includes a p99 spike and is not an isolated skiing
benchmark or a full-process memory measurement. Other editor/test processes were
not stopped. It does not establish the 90–120 FPS target during downhill play.

Human acceptance remains open for audio balance, controller navigation feel,
transition comfort and repeated skiing/menu use. Automated assertions and native
screenshots do not substitute for that review.

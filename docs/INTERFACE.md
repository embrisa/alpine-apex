# Interface windows and loading

The interface refresh on `codex/ui-workspace-loading` gives each activity its own
space while retaining the existing skiing, race, mountain and graphics contracts.

## Navigation

| Window | Tabs / actions |
| --- | --- |
| Main menu | Ride, Explore, Tools |
| Settings (Tools) | Display, Weather, Rider, Interface, Controls |
| Mountains (Explore) | Create, Saved, Share; large terrain preview beside the controls |
| Races (Explore / F4) | Saved races, Import & share; separate in-world creation view |
| Personal best (Explore / F6) | Overview, Splits, Run history |
| Workbench (Tools / F2) | Handling, Forces, Camera, Speed lab |

Settings and the workbench have fixed Back/Close buttons outside their scrolling
tab content. Tab/arrow navigation, focus outlines and Escape remain available.
Settings and records restore focus to their main-menu entry. The skiing footer
shows primary controls; the Controls tab contains the complete shortcut list.

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

# Animation Workshop

Open **Menu → Tools → Animation Workshop**. For a lightweight studio without
loading a mountain, run `./godotw.ps1 --script scripts/workshop/open_workshop.gd`.
The studio edits working copies of the existing 33 clips on the 24-bone skier.
It does not apply edits to gameplay. Original clips remain intact.

## Pose and timing

Choose a source in **Clips**, then **Edit selected clip**. The top selector switches
between named variants. Use the timeline, slider, arrow keys or frame buttons to
seek; Space starts/stops playback. Frames are zero-based at 60 Hz. Playback speed,
looping and the In/Out range affect preview playback.

Select and drag a joint in one gesture with the default **Auto** tool. It moves
the pelvis, solves hand/foot IK, adjusts elbow/knee bend direction, and rotates
other bones. Colored rings and **Rotate / Move / IK** remain available for
explicit manipulation. Shift-click selects several bones without editing.
Viewport tips marked by terminal helper bones select their parent: dragging
the helmet tip rotates **Head**. The hierarchy still exposes the original rig.
Grounded pelvis edits default to **Hold feet**, including boot orientation;
disable it for free root motion. **Pin / unpin** also holds selected hands/feet.
Escape, Ctrl+Z during a gesture, or focus loss cancels that gesture; a completed
drag is one undo action. Original and Constrained views are read-only.
Bone lengths and the existing hierarchy remain
fixed. Right mouse orbits, middle mouse pans, and the wheel zooms. Front/Side/Back,
orthographic view, bone overlays and neighboring-pose ghosts aid inspection.

Mouse posing defaults to a correction with nine frames of smooth influence on
either side. The influence is clamped at clip endpoints; a correction on the
first/last frame remains effective at that endpoint and fades inward. **Edits**
lists corrections in composition order. Rename, mute, reset, delete, or adjust
their boundaries there; Timeline also exposes draggable boundary handles.

Disable **Smooth local correction** to insert explicit keys in a shared correction
track. **Curves** exposes local RX/RY/RZ and pelvis translation channels. Keys can
use constant, linear or cubic interpolation; selected cubic keys show tangent
handles. Shift-click for multi-selection, drag to move, and use Copy/Paste/Delete
keys. Double-click a curve to insert a key. Rotation UI values are degrees;
internal channels are radians in YXZ order, composed after the source quaternion.
The nearest equivalent YXZ branch preserves continuity across ±90° pitch.
Pausing, seeking and stepping snap to an exact native frame. Influence boundaries
cannot cross interior keys. Partial retiming splits crossing cubic curves before
scaling their separate incoming/outgoing tangents.

**Retime range** rescales its lead-in, scales the selected range, and moves the
tail while keeping a monotonic source-time map. **Set duration** scales the entire
clip. **Trim to range** changes visible clip bounds without deleting embedded
source data. Pose copy/paste and mirroring operate on selected bones/all bones,
respectively. Ctrl+Z/Ctrl+Y undo/redo complete gestures, including IK chains.

## Comparison and comments

Compare **Original**, **Your edit**, and **Constrained result**, individually,
side by side, or as translucent overlays. Free editing does not enforce the
current anatomical limits. The constrained character uses the production pose
pipeline and final skeleton writer. **Fit** selects grounded/airborne/Safety/Mute
fixtures and slope, stance, tuck and grab weight. Orange diagnostic bones show
changes exceeding 2 cm or about 6 degrees.

This is a controlled fitting preview. It does not reproduce gameplay blending,
event timing, trajectories, or the complete physical actor rotation. Fingers,
equipment authority and the existing rig retain their production limitations.

In **Notes**, create a comment on a frame/range and selected bones. Saving captures
marked original/edited/constrained frames around the range, the exact poses,
camera, fitting context, diagnostics and project revision. Later edits do not
change this evidence. New captures also record the physical model and fitting
source hashes, so older comments retain their original fitting context.
**Update text only** preserves the existing frames;
**Save comment + capture frames** explicitly refreshes them.

## Files and export

Projects use versioned, data-only `.apexmotion` JSON documents. They embed source
motion for used clips, rig rest transforms, source hashes, variants, correction
curves, time mapping and comments. No scripts/resources from a project file are
executed. A different source hash retains the embedded original; incompatible
bone hierarchies are rejected. Fitting always uses the installed production code.

Default storage is `user://animation_workshop/` (Godot's Alpine Apex app-data
directory). Save As supports other locations. Recovery autosaves every 30 seconds
after changes and on Close. Writes use a temporary file and a last-good `.bak`;
reopening can recover the backup if a write was interrupted. Source sample arrays
are immutable and shared between undo snapshots to bound editor memory overhead.

**Export for Astra** previews the included variants and comments, then writes one
ZIP to the chosen location. It contains `REVIEW.md`, structured comments, marked
PNGs/contact sheets, the editable project, and 60 Hz original/edited baked motion
with local quaternions, pelvis positions and coordinate conventions. Reviewed or
modified variants without written comments receive an automatic visual overview.
The package is local; attach it or give its path to Astra in a separate request.
The export-complete dialog also offers **Copy ZIP path**. Windows Explorer rejected
the app-data folder in this machine's test session despite successful reads from
Godot and PowerShell. Folder opening uses Godot's file-manager API; copying the
path or choosing a different export directory remains available.

## Ownership and validation

The workshop lazily creates its own world, characters, cameras and playback clock.
The live session stays paused, gameplay/F8 input is suppressed, and closing restores
the previous menu. Preview resources and processing are released on close. Shared
presentation changes are a final-writer extraction and an explicit optional pose
input; the ski solver, terrain, records and replay schema are unchanged.

Use `scripts/run_guarded.ps1` around these workloads; do not overlap them with
other Godot/Blender runs. `scripts/validate_animation_workshop.ps1` runs the data,
UI lifecycle, physics/runtime, motion, anatomy and attachment regressions.
`scripts/test_animation_workshop.ps1 native` captures 1440×900/3840×2160 layouts and
an exported review. `tests/animation_workshop_benchmark.gd` uses a frozen
pre-workshop visual in `artifacts/workshop_baseline_visual.gd` for a short laboratory
pair, followed by studio playback/scrubbing. It is not a full-mountain benchmark.

Validation artifacts live in `artifacts/animation_workshop/` and
`artifacts/guarded/workshop_*`. Automated correctness, native rendering, hardware
input, performance and the user's animation-feel acceptance are separate gates.

The 2026-09-09 acceptance record is in
`artifacts/animation_workshop/ACCEPTANCE.md`. Both native resolutions, mouse posing,
curves, saving, reopening and ZIP export were exercised. The saved
`user://animation_workshop/astra-head-study.apexmotion` contains a mouse-authored
head-lift proposal at frame 101 with a frozen review note; it is not a gameplay
override or a claim of player-approved animation quality. The matching package is
`user://animation_workshop/astra-head-study.zip`.

`tests/animation_workshop_package_suite.gd` reopens a native export and checks all
baked frames, image bytes and evidence timestamps. Pass
`--package=user://animation_workshop/astra-head-study.zip` after the `--` separator
to validate the mouse-authored example. The optional `--show-folder` flag also
exercises the OS file-manager request.

# Cascadeur trial evaluation — 2026-09-10

**Latest: [R9 deeper carving](CASCADEUR_DEEP_CARVING_R9.md)** follows the request for about 17 cm
between boot heights at the deepest carve. The optional trial reaches 16.94 cm
during the strong-turn fixture; its fresh model-28 comparison uses R8 and R9
pressure profiles with the same R7 hands. Earlier sealed evidence is preserved.

**R8 leg/snow follow-up:** the user accepted the hands as okay but requested a
foot-height difference and more leg feeling, then explicitly authorized physical
soft-snow sinking. [R8](CASCADEUR_SNOW_LEGS_R8.md) retains R7 hands while physical
ski support drives the leg response. It is an optional contact/pose experiment;
its model-27 movies predate concurrent model-28 handling changes. User preference
and Cascadeur adoption remain open.

**Carving follow-up:** after trying R6, the user said **“they look very similar?”**
and requested a slightly different carving variant for comparison. The optional
[R7 carving playtest](CASCADEUR_CARVING_R7.md) adds authored left/right upper-body
offsets over current carving. It is separate from R6's compression sequence;
normal launch and the production animation library retain their existing motion.
User preference and Cascadeur adoption remain open.

**Latest result — R6 completed:** the bounded timing edit, save/reopen/export and
real gameplay presentation comparison are now tested. Mechanical checks pass,
but existing downhill posture corrections replace much of the authored straight
compression. Steering retains a larger hand/pole difference without a demonstrated
quality improvement. [R6 report and recommendation](CASCADEUR_WORKFLOW_EVALUATION_R6.md)
and [interactive review](http://127.0.0.1:8769/comparisons/cascadeur-20260910-r6/review.html).
Keep the current production workflow; test source posture ownership before making
more Cascadeur clips. R6 user acceptance and broader adoption remain open.

**Latest user feedback:** after viewing R5, the user said **“It looks decent to me”**
and requested a new task for the next agent. R5 is the visual baseline for
[the next authoring and gameplay-fitting evaluation](tasks/CASCADEUR_WORKFLOW_AND_GAMEPLAY_EVALUATION.md).
The stiffness comments below are the author's assessment, not a user rejection.
The sealed R5 assessment predates this feedback and remains unchanged.

**User review update:** R4 was rejected because the shoulders appeared missing
and the shoulder/elbow regions wobbled. The subsequent rotation audit found
175.6° upper-spine and 178.8° neck lateral-axis deviation; shoulder-joint width
collapsed to 3.37 cm. The final Godot bones match the source rotation matrices
within 2.36e-6 per coefficient, so this defect is in the authored source. Length
checks did not validate articulation. A separate R5 candidate constrains torso
orientation helpers, clavicles and elbow planes; its rendered review is complete.
R4's images and the user's exact feedback are preserved.

The follow-up repaired the rig and produced an equipped, editable two-second
compression/recovery **blockout**. Cascadeur can now author and export this
skeleton without the pilot's large torso separation. It has **not** established
a convincing production skiing workflow: the motion remains stiff and symmetric,
the native material display fails after reopen, and gameplay fitting was untested
at the R5 checkpoint. R6 above now supplies that fitting evidence.
Keep the existing Blender/Godot workflow as the default. Do not adopt or purchase
Cascadeur on this evidence alone.

## R5: shoulder and elbow correction

[Compare R4 and R5](http://127.0.0.1:8769/revisions/cascadeur-20260910-r5/index.html)
using matched cameras, synchronized normal/half-speed playback, frame scrubbing,
all three views and front-view chronology. The editable source and tested export
procedure are in
[cascadeur_evaluation_20260910_r5](../art_source/animation/cascadeur_evaluation_20260910_r5/README.md).

R5 explicitly targets 31 controls on each of 61 frames: torso orientation helpers,
clavicles, shoulder positions, elbow bend planes and forearm orientation helpers,
alongside the existing head, hand and stationary foot targets. Torso frames are
calibrated from the rest pose. Elbows use reachable upper/forearm lengths and a
stable bend direction. The source rig solves these controls before export; no
exported transform patch, skin-weight change or alternate runtime writer is used.

The frontal shoulder silhouette remains connected across the inspected 61-frame
chronology. The collapsing clavicles and abrupt upper-body swings seen in R4 are
removed. Selected oblique, overhead and side renders retain connected elbows and
wrists. The remaining dominant issue is the stiff, symmetric compression and
recovery with little natural balance response. This is a correction of the reported
defect, not a convincing-skiing acceptance or a reason to adopt Cascadeur.

| R5 check | Result |
|---|---|
| Shoulder-joint width across the clip | 35.296–35.324 cm; R4 minimum was 3.366 cm |
| Maximum upper-spine rotation step | 0.388° per 30 FPS sample; R4 was 19.70° |
| Maximum forearm rotation step | 1.726°; R4 was 6.568° |
| Animation export | 24 joints, 61 samples, 2 seconds, 83,956 bytes, no meshes |
| Stationary foot/toe drift | Below 0.001 mm |
| Maximum segment-length variation | 0.04431 mm |
| Source to final-writer position error | 0.00222 mm maximum |
| Source to final-writer basis-axis error | 3.59e-6 maximum |
| Full render | 61 triptychs at 2400×1000; all camera transforms match R4 |
| Detail render | Frames 0, 12, 24, 30, 44, 60; oblique/overhead/side |
| Final skinned-clothing audit | 61 frames, zero pole-shaft intersections; intentional first 10 cm below grip excluded |
| Source provenance | All 66 captured source hashes match both snapshot and live files |

Capture/render/audit reports are under
`artifacts/pose_review/revisions/cascadeur-20260910-r5/`; rotation and import
diagnostics are under `artifacts/cascadeur_rig_20260910_r5/`. The author's assessment
records inspection coverage and limitations separately from the user's R4 rejection.
The user subsequently found R5 decent; gameplay acceptance and adoption remain
undecided. R5 save and re-export succeeded; the earlier reopen
and post-reopen edit tests apply to R4, not a separate R5 reopen verification.

At the user's request, the R5 render, detail render, encoding and clothing audit
ran alongside the v15 generation batch using `run_guarded.ps1 -AllowConcurrent`.
The successful guarded run completed at 18:21:47 local on September 10 with exit 0
and no engine or driver errors. Timeout and owned-process cleanup stayed enabled.
Overlapping wall times are not performance baselines. The first render invocation
failed because PowerShell consumed an unquoted `--`; quoting it fixed argument
delivery. Its logs remain in the guard history; the successful pose capture was
reused without replacing it.

## R4 follow-up: rig findings and rejected animation

Evidence ID: `cascadeur-20260910-r4`, still on Cascadeur **2026.2.2.0.16638**.
Export availability was checked live. The trial files are separate from the pilot
and no production asset, writer, gameplay animation or physics code was replaced.

- [Interactive review](http://127.0.0.1:8769/revisions/cascadeur-20260910-r4/index.html):
  61 chronological frames, fixed oblique/front/side cameras, normal and half-speed
  playback, and frame scrubbing. The local pose-review server must be running.
- [Preserved editable source and re-export procedure](../art_source/animation/cascadeur_evaluation_20260910/README.md).
- Diagnostic inputs, rejected experiments and exact MCP receipts:
  `artifacts/cascadeur_rig_20260910_r4/`.
- Frozen Godot evidence, source snapshots, engine identity and render metadata:
  `artifacts/pose_review/revisions/cascadeur-20260910-r4/`.

### Established rig cause and working correction

The **generated** control mapping differed from the requested template. The
actual QRT and TechnicalLinks assigned stomach to `Spine`, above chest=`Spine01`.
It generated `Spine_MainPoint` but no `Spine02_MainPoint`. Our skeleton runs
`Hips → Spine02 → Spine01 → Spine → neck → Head`; the control order was wrong.
This is the concrete failure found in the pilot, not evidence of a broken bind
skeleton or GLB exporter.

Removing `Armature` from template paths made `load_template_by_content` report
the intended mapping, but both `create_from_qrt_by_content` and
`generate_rig_elements` reverted the generated stomach assignment in this test.
**Correcting the template text alone is not the fix.** The underlying reason
within that generation route remains unproven; do not generalize this to every
Cascadeur import or attribute it to a particular release bug.

The successful route used the installed Python Biped builder with explicit
ObjectIds for every role. Core recipe, after import at 100×, a 61-frame timeline,
and entry into rig mode:

```python
import pycsc
from prototypes.rigs.qrt.biped import Biped, BipedData, BipedSettings
from prototypes.qrt_prototypes.create import _process_qrt

# ids maps verified Joint names to ObjectIds; template contains all limb roles.
# Required torso roles: pelvis=Hips, stomach=Spine02, chest=Spine01,
# neck=neck, head=Head. Verify names AND anatomical parentage first.
settings = BipedSettings(create_layers=True, replace_existing=True,
                        align_pelvis=True, spline_ik=True)
data = BipedData(settings, node_joints={role: ids[name]
                                      for role, name in mapping.items()})
py_scene = pycsc.wrap(scene)
Biped.add_qrt_json(py_scene, json.dumps(template))
builder = Biped(json.dumps(template), py_scene, data, 10., 10.,
                np.array([.2, .7, 1.], dtype=np.float32))
builder.run_rig_process(_process_qrt)
```

This is a version-specific installed API recipe, not a supported portable plugin.
Check generated TechnicalLinks and each `builder.get_joint(role).name`, then
leave rig mode in a separate update. The full successful request/response is
`receipts/170355_explicit_joint_builder.json`; the finalization receipt is
`170428_explicit_finalize.json`. The source folder preserves this recipe and its
mapping input. Do not execute the old failed QRT reproduction scripts as setup.

A 2 cm pelvis-control edit then kept torso segment changes near 0.02 mm. Repeating
the pilot's larger diagnostic targets kept the neck attachment change near
0.0027 mm, versus approximately **296 mm** in the failed pilot. Native skin
rendering confirmed that the gross shoulder/torso separation was removed.
The old arbitrary targets served only as a diagnostic comparison, not as the
authored skiing poses. Native before/after images use different cameras; they
are not a matched artistic comparison.

### Authored sequence and rejected contact approach

The new sequence has six beats at frames **0, 12, 24, 30, 44, 60** at 30 FPS:
ready, hold, absorption, maximum compression, recovery, and ready. Both endpoints
are skiing poses. The movement uses the pressure-control principle of flexing
and extending the legs while controlling the upper body, described by
[PSIA's pressure-control reference](https://thesnowpros.org/2023/01/32-degrees-how-to-apply-pressure-control-in-the-bumps/).
Timing and coordinates were authored; this is not mocap or a reconstruction of
reference video, and no claim of expert movement fidelity is made.

Actual boots, bindings, skis and poles were attached during authoring. Native
attachments were derived from the live game offsets and bind rotations. The
Godot preview uses the original equipment assets, rigid attachments and fixed
glove/pole sockets through `SkierVisual.present_authored` and the final writer.

Conventional six-key interpolation retained anatomy but allowed about 6.26 mm
of between-key foot drift. Standard foot interval/Fulcrum fixation reduced drift
to micrometres but introduced **4.68 mm of shin-length variation**. That variant
was rejected. The delivery instead samples the editable control targets and
solves all 61 frames through the rig with exact foot/toe targets. It does not
patch exported joint translations or stretch the game skeleton. Keep the six-key
scene for edits and the solved bake for export; re-bake after source changes.

### Mechanical and reliability evidence

| R4 check | Measured result | Scope |
|---|---|---|
| Animation export | 83,956 bytes, 24 joint names/parents, 61 samples, 2 seconds, no meshes | Final baked GLB |
| Maximum foot/toe drift | 0.000682 mm | All 61 stationary model-space samples |
| Maximum segment-length variation | 0.05423 mm | All 61 samples; not an artistic grade |
| Godot import position error | 0.00975 mm maximum | All frames and bones against GLB sample transforms |
| Existing final-writer position error | 0.00216 mm maximum | Isolated `present_authored` preview |
| Restored frozen-pose render error | 0.000854 mm maximum | Fixed 2400×1000 three-view renders |
| Save/reopen animation difference | 0.000696 mm maximum position change | All samples; GLB bytes differ, poses remain equivalent at this scale |
| Control edit after reopen | A separate 2 cm pelvis edit kept feet unchanged; maximum segment change 0.0969 mm | Probe copy only; reviewed bake was restored |
| Native material appearance after reopen | **Failed again**: orange/black patches | Actual native image; original Godot materials render correctly |
| Re-export procedure | Saved `export_animation.py` executed successfully | New file, animation only, exact 24-joint check |
| MCP completion reliability | One server idle-event timeout even though the edit, captures and save completed | `174321_reopen_edit_probe.json`; state inspected before recovery |

Reports include `baked_animation_audit.json`, `reopen_audit.json`,
`reopen_edit_audit.json`, `diagnostic_comparison.json`, and
`godot_preview_audit.json`. The pinned Godot build is 4.7.2 custom `ed1daf0bf`;
the executing engine SHA-256 is
`a18ddc9f3ee8fa1915a47d54c3e0d05ec4b10f8ee9deb15d7206b4e23d29bcc9`.
Capture and Render guarded runs exited zero, with empty stderr and no engine
errors. `freeze_sources.py` preserved 66 source files for this revision.

The final clothing audit and selected overhead/detail renders are recorded in
the review's author assessment with their actual completion status. A passing
export or a visible fixed grip must not be substituted for these checks.

Executed review commands (run stages serially when the shared lock is free):

```powershell
./scripts/run_guarded.ps1 -FilePath "$PWD/godotw.ps1" -Arguments @('--headless','--script','artifacts/cascadeur_rig_20260910_r4/preview_capture.gd') -Label cascadeur-r4-capture -TimeoutSeconds 150
python scripts/pose_review/freeze_sources.py --revision cascadeur-20260910-r4
./scripts/pose_review/run_stage.ps1 -Stage Render -Revision cascadeur-20260910-r4 -Engine "$PWD/.tools/godot-fsr/bin/godot.windows.template_debug.x86_64.console.exe" -TimeoutSeconds 180
python scripts/pose_review/encode_videos.py --revision cascadeur-20260910-r4 --ffmpeg "$PWD/.tools/animation-video/imageio_ffmpeg/binaries/ffmpeg-win-x86_64-v7.1.exe"
```

The MP4 contains every rendered sample at 30 FPS, including the 2.0-second end
pose, so its container duration is 2.033 seconds. Source animation duration is
2.0 seconds. This is encoded Godot evidence; native Cascadeur video export was
not retried. The updated trial `call.py` also records transport exceptions and
timeouts; inspect those receipts and app state before retrying mutations.

This capture invokes the shared writer, **not the gameplay composition and
anatomical fitting pipeline**. No simulation ticks ran. Captured `grounded=true`
means authored support intent, and `tick=frame*4` is a synthetic review index.
These are explicitly labelled in the capture manifest. Moving skis, slopes,
cuff limits under gameplay fitting, steering transitions, landing, AutoPhysics,
new-rig AI interpolation and gameplay performance were not tested.

### Author assessment and next decision

The rig is materially improved and the clip is usable for a constrained technical
comparison. It is **not yet the convincing skiing sequence requested as the
adoption case**. The worst visible issue is the synchronized upper-body bob and
stiff, symmetric arm/pole carry: the legs flex, but the movement lacks independent
balance and a persuasive terrain response. All 61 side frames were inspected
chronologically; the three-view video plays at 1× and 0.5×. Browser playback
checks and sampled screenshots are not a continuous human video review.
No numerical artistic grade, independent reviewer or user acceptance is claimed.

Authoring required explicit rig construction, direct equipment setup and a
separate contact bake. That is a working route, but it has not demonstrated a
time saving over Blender. Native save/reopen appearance remains unreliable and
the previously freezing MCP video path remains excluded. The misleading
idle-event timeout also makes automatic retries unsafe without state inspection.
One rig, repeated loading and one edited probe do not establish batch
repeatability across an animation library.

**Recommendation:** retain this trial as an optional authoring experiment and
keep Blender/Godot as the default. The next useful comparison is the same short
movement using a constrained Blender rig with foot, grip and anatomy checks,
judged on the same mesh/cameras. Blender was not tested in this follow-up, so
this is a proposed experiment, not a measured victory for Blender. Alternatively,
refine this six-beat source with a skiing animator before testing gameplay
composition; do not spend the next pass rediscovering the QRT mapping defect.
A landing test follows a satisfactory grounded clip. No whole-library conversion,
subscription decision or production integration follows from this blockout.

## Initial pilot — historical evidence

The remaining sections describe the earlier failed body-only pilot in
`artifacts/cascadeur_trial_20260910/`. Their unresolved rig diagnosis is superseded
by the R4 findings above; their AI and video results still apply to that pilot.

## What was actually tested

- Installed Cascadeur **2026.2.2.0.16638**, Pro trial, on the user's Windows PC.
- Built-in MCP server enabled through Scripts → MCP → Start script server.
  Its local `http://127.0.0.1:8765/mcp` endpoint exposes `run_script`, which executes
  Python inside Cascadeur. Requests and responses were recorded. This is an
  HTTP client of the installed server, not a newly registered Codex plugin.
- Imported a copy of `assets/graphics/models/skier_v7.glb`, generated a control
  rig with AutoPosing controls, authored a two-second compression/recovery
  diagnostic at frames 0/30/60, compared Bezier and AI interpolation, and exported
  animation-only GLBs at 30 FPS.
- Inspected the actual Cascadeur viewport and a native frame render. The test
  contains the body asset only; no skis, boots or poles were attached. The endpoint
  poses are a rig diagnostic, not accepted skiing motion.

## Results

| Check | Observed result |
|---|---|
| Static GLB import/export | All 24 joint names and parents preserved; maximum world-matrix coefficient difference about 1.42e-6 |
| Scale | Explicit 100× import and 0.01× export required for metres ↔ centimetres in this workflow |
| Mesh export | Original 49,217,948 bytes became 147,593,700 bytes; use animation-only delivery and retain the production mesh/materials |
| Animation-only export | 83,956 bytes, 24 joints, 61 samples, two seconds; no mesh |
| Rig generation | Control rig and AutoPosing controls created; posed torso failed deformation review |
| Latest Bezier interpolation | Maximum foot/toe joint displacement about 0.00000136 m across all 61 exported frames |
| Latest AI interpolation | Maximum ankle displacement 0.03284 m; toe displacement up to 0.01092 m |
| Torso | Adjacent neck-joint separation varied by about 0.296 m in the latest Bezier test and 0.301 m with AI; native render visibly shows unacceptable torso/shoulder deformation |
| Native still rendering | Worked |
| Native video export through MCP | Application became unresponsive; request timed out; no completed video produced |
| Godot import/playback | Passed in Godot 4.7.2 custom build after the shared validation slot became free: both exports generated 24-bone skeletons and two-second animations; poses sampled successfully |
| AutoPhysics, ski contact, poles, game performance | Not tested |

The interpolation numbers describe this experimental rig and these poses. They
do not establish Cascadeur's best achievable animation quality. In particular,
bad rig configuration must not be misreported as an intrinsic AI limitation.

## Rig and API findings

Our hierarchy is `Hips → Spine02 → Spine01 → Spine → neck → Head`. The first
custom Mixamo template mapped chest to `Spine`, skipping an intermediate joint.
The later mapping uses stomach=`Spine02`, chest=`Spine01`, neck=`neck`. That
correction alone did not resolve the distortion.

The installed rig-generation script automatically runs an AutoPosing update
when creating a one-frame rig if its corresponding setting is enabled. In this
pilot, that changed the initial pose and torso proportions substantially.
Creating the 61-frame timeline **before** rig generation preserved the imported
rest positions. Subsequent posed deformation still failed. The rig's spine
controls, spline settings and imported rest transforms need a dedicated review.

Use `app.current_scene().save(full_path)` for an explicit save. The attempted
`save_scene_as` route opened a modal dialog. Resize the timeline and edit its
poses in separate script calls; combining them caused an update exception in
this experiment. Check the boolean result of `modify_update_with_session`:
an outer MCP success response does not prove the modification succeeded.

Do not repeat the tested `RenderToFile.play_to_video_file` call from an MCP
script. It froze the application after the two latest scenes had been saved.
The cause has not been established; this may be an execution-context issue.
Single-frame `take_image` succeeded. Preserve a saved scene before further API
experiments and inspect actual app state after timeouts before retrying mutations.

Recovery: the unresponsive process was terminated only after confirming both
latest scenes were saved. Cascadeur was restarted with `compression_v3_bezier.casc`;
the file loaded and the process became responsive. The reopened viewport also
showed orange/black surface artifacts that were absent from the earlier native
still. Saved-scene material/display fidelity remains unvalidated. No further
video-export attempts were made.

## Files and reproducibility

All evaluation outputs are under `artifacts/cascadeur_trial_20260910/`:

- `compression_v3_bezier.casc` and `compression_v3_ai.casc`: saved latest scenes.
- `compression_v3_bezier_animation.glb` and `compression_v3_ai_animation.glb`:
  diagnostic animation exports, **not production candidates**.
- `v3_bezier_key30.png`: actual native render showing the deformation failure.
- `static_roundtrip_audit.json`, `animation_v3_bezier_audit.json`,
  `animation_v3_ai_audit.json`: numerical evidence, including sampled transforms.
- `receipts/`: exact MCP requests/responses. The video request timed out before
  the client could write a normal receipt; its last server log entry is retained
  in `cascadeur_log_before_recovery.log`.
- `godot_import_probe.gd`, `godot_import_audit.json`, `godot_comparison.json`:
  executed GLTFDocument import/playback check and comparison to exported poses.
  Guarded stdout/stderr and process receipt are in `artifacts/guarded/cascadeur_import/`.
- `source_hashes.json` and `source_hashes_after.json`: the production GLB, Blender
  source and animation library match their pre-test SHA-256 hashes.

No production asset, animation writer or physics implementation was replaced.
Earlier attempt files are diagnosis history and should not be used as approved
templates. No visual or gameplay acceptance is claimed.

## Pilot's original decision gate — superseded by the R4 checkpoint

Validate a corrected rig on one grounded compression and one airborne landing.
The source skeleton must retain sensible anatomical proportions throughout the
motion; grounded feet must obey the game's contact requirements. Export only
animation, inspect it on the original mesh, and verify it through the existing
final pose writer in Godot with skis and poles attached. Only then judge whether
Cascadeur saves enough authoring effort to keep alongside Blender.

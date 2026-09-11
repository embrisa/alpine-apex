# Task: continue evaluating animation workflows for Alpine Apex

Created: 2026-09-10. Project: `C:\Users\hp\Downloads\alpine-apex`.
Status: superseded by [the workflow and gameplay evaluation task](CASCADEUR_WORKFLOW_AND_GAMEPLAY_EVALUATION.md).
The user reviewed R5 and said **“It looks decent to me”**. Continue from that
satisfactory visual baseline using the new task; this file retains prior history.

**Latest user feedback:** R4 is rejected for missing/collapsed shoulders and
wobbling shoulder/elbow regions. Source rotations contain near-180° torso/neck
twist despite stable lengths. R5 is a separate candidate correcting orientation
helpers, clavicles and elbow planes. R5's 61-frame front chronology retains the
shoulders, and its full clothing audit reports zero shaft intersections. The
author observed stiffness and symmetry; the user subsequently found R5 decent.
This positive source-preview feedback does not establish gameplay or tool adoption.

## Latest review: R5

- [Matched R4/R5 comparison](http://127.0.0.1:8769/revisions/cascadeur-20260910-r5/index.html).
- [R5 editable source and export procedure](../../art_source/animation/cascadeur_evaluation_20260910_r5/README.md).
- Evidence: `artifacts/pose_review/revisions/cascadeur-20260910-r5/`.
- Source diagnostics: `artifacts/cascadeur_rig_20260910_r5/`.

The source fix constrains torso orientation helpers, clavicles, shoulder positions,
elbow planes and forearm helpers across all 61 frames. Shoulder width stays near
35.3 cm, with maximum forearm rotation steps below 1.726 degrees at 30 FPS. Position
and rotation transfer both pass through the existing final writer. All 66 captured
source files match the live files and snapshot. The review remains an isolated
authored preview, without gameplay composition/fitting or simulation.

The user explicitly authorized running this visual review concurrently with the
v15 generation batch. It completed successfully with the new opt-in
`run_guarded.ps1 -AllowConcurrent`; timeout, error checks and owned-process cleanup
remain active. Do not force the next isolated review to wait on a generation batch
when this authorization applies. Concurrent timings do not establish performance.

R5 resolves the reported collapse but does not yet establish convincing skiing or
Cascadeur adoption. The next quality question is natural balance and absorption,
not another importer repair. Keep the existing Blender/Godot default; a constrained
Blender comparison remains unperformed. Read the evaluation for current evidence
and reliability limits. R4 below is preserved history and is user rejected.

## R4 checkpoint — historical follow-up on 2026-09-10

The large torso deformation is diagnosed and corrected: generated stomach was
mapped to `Spine`, above chest=`Spine01`, despite the requested template. Explicit
Joint ObjectIds through the installed Biped builder preserve the intended
`Spine02`/`Spine01` roles. Template path edits alone still reverted on generation.
Do not restart generic rig diagnosis or reuse the pilot's failed templates.

An equipped two-second ready → compression → recovery blockout now has an
editable six-beat scene, a rig-solved 61-frame contact bake, a clean animation-only
export and a frozen three-view Godot preview. The bake holds stationary foot/toe
drift below 0.001 mm and segment-length variation below 0.055 mm. Save/reopen
preserves animation transforms but reproduces orange/black material corruption.
A separate post-reopen control edit also worked, although MCP reported an idle
timeout after completing it. Inspect saved outputs/current state before retries.

- [Current evaluation, cause, metrics and recommendation](../CASCADEUR_TRIAL_EVALUATION.md).
- [Durable source and tested export procedure](../../art_source/animation/cascadeur_evaluation_20260910/README.md).
- [Interactive preview](http://127.0.0.1:8769/revisions/cascadeur-20260910-r4/index.html).
- New diagnostics: `artifacts/cascadeur_rig_20260910_r4/`.
- Frozen evidence: `artifacts/pose_review/revisions/cascadeur-20260910-r4/`.

This is **preview only**: `present_authored` → existing final writer, without
gameplay composition, fitting or simulation. The motion remains stiff and
symmetric and does not yet pass the convincing-skiing adoption gate. Final
clothing/detail coverage is recorded in the revision's author assessment; do
not infer coverage from successful import. No user acceptance is recorded.

Keep Blender/Godot as default. Next, compare the same movement using a constrained
Blender rig, or refine the preserved source with skiing animation expertise before
gameplay fitting. Blender was not tested in R4. A landing clip is still a second
gate, not the immediate next expansion. The historical instructions below retain
the broader evaluation boundaries; R4 findings supersede their unknown torso cause.

**We have not decided to adopt or commit to Cascadeur.** Its Pro trial is an
opportunity to evaluate one candidate tool. This is not a Cascadeur migration or
implementation assignment. A good outcome may be to recommend Cascadeur, reject
it, or identify a specific remaining test before deciding. Installing it, testing
its MCP, or producing a successful demo does not constitute a commitment.

## Assignment and intended outcome

The user installed Cascadeur with a Pro trial and asked us to try it on Alpine
Apex. Continue this evaluation through practical animation work. The primary
question is which workflow can reliably produce good skiing animation with
reasonable authoring effort. Do not assume the answer must include Cascadeur.

Aim to produce **one convincing skiing sequence on the actual skier with its
equipment** as the evaluation case, with an editable source, a clean animation
export, and reviewable Godot evidence. Use this to judge quality, effort,
repeatability and reliability before recommending adoption. If a workflow fails
the bounded evaluation, document that result and recommend the next approach;
do not keep repairing Cascadeur indefinitely to satisfy a presumed commitment.
The recommended first sequence is athletic downhill ready stance
→ grounded compression → controlled recovery to ready stance. This is a proposed
starting scope, not an already approved artistic pose. Use real skiing reference
and the existing gameplay requirements to establish timing and body mechanics.
Do not start from or preserve the pilot's T-pose endpoints as animation targets.

Repair and validate the rig before polishing timing or adding AI interpolation.
Try Cascadeur as an authoring tool, but prioritize the resulting animation over
making a particular tool succeed. Compare against the existing Blender workflow
when useful; neither Cascadeur nor a replacement workflow is preselected. If a
tested rig correction does not make Cascadeur useful, evaluate a properly
constrained Blender rig or another justified approach and document the reason. Avoid an
open-ended sequence of guessed control-point coordinates. A short airborne
landing is a second validation case after the first clip works, not a reason to
expand into a whole animation library immediately.

## Read first

Read current files; other agents may have changed production since this handoff.

1. `AGENTS.md` and `.agents/skills/alpine-animation/SKILL.md`.
2. `docs/CASCADEUR_TRIAL_EVALUATION.md` — results from this specific trial.
3. The animation skill's `references/rig-and-actions.md`, `review-loop.md`,
   `tool-recipes.md`, and `handoff.md`.
4. `docs/ANIMATION_AGENT_WORKFLOW.md`, `docs/ANIMATION_REVIEW_LESSONS.md`,
   `docs/SKIER_ANATOMY.md`, and `docs/EQUIPMENT.md`.
5. `docs/DOWNHILL_TUCK_ALIGNMENT_R4.md` if working on tuck/carry. It is a prior
   refinement with user acceptance pending, not a certified quality baseline.
6. `docs/STEEP_MOTION_GAMEPLAY.md` for asset-to-gameplay integration.

## Non-negotiable project boundaries

- The independent 120 Hz ski solver and shared terrain/contact data own motion.
  Animation must not change trajectory, physical contacts, forces, COM, replay,
  records or simulation randomness to make a pose look better.
- Preserve **one final skeleton writer**:
  `scripts/presentation/skier_pose_writer.gd`. An AnimationPlayer in an isolated
  import probe is fine; adding a competing AnimationPlayer to gameplay is not.
- Preserve rigid skis, boots and poles, connected limbs, and fixed glove sockets.
  Do not hide a bad pose by stretching anatomy, sliding a grip, moving a pole
  independently, bending a boot, or widening joint limits indiscriminately.
- Keep existing production assets while developing the candidate in a new
  isolated folder. Preserve other agents' edits and unsaved DCC sessions.
- Follow the root `AGENTS.md` Git workflow: work on `main`, and commit/push
  validated milestones frequently. Early-development breaking changes are allowed;
  avoid compatibility layers and unrelated cleanup.
- Godot and Blender validation workloads use `scripts/run_guarded.ps1`.
  The user authorized concurrent isolated animation checks using its explicit
  `-AllowConcurrent` option. Keep timeout/cleanup protections, separate outputs
  and no nested guards. Leave other workloads running; overlapping timings do
  not establish performance baselines.

## Current assets, coordinates and production ownership

| Purpose | Path |
|---|---|
| Production mesh/skin | `assets/graphics/models/skier_v7.glb` |
| Editable Blender source | `art_source/blender/skier_v7.blend` |
| Current animation data | `assets/animation/steep_ski_motion.res` |
| Physics/input-derived presentation channels | `scripts/presentation/skier_animation.gd` |
| Clip selection/composition and existing tick tracker | `scripts/presentation/skier_full_motion.gd` |
| Action/posture corrections | `scripts/presentation/action_posture.gd`, `downhill_posture.gd` |
| Support/anatomical fitting and attachment integration | `scripts/presentation/skier_visual.gd`, `skier_anatomy.gd`, `skier_equipment.gd` |
| Shared final writer | `scripts/presentation/skier_pose_writer.gd` |

The inspected rig has 24 bones and no finger bones. Its spine order is:

```text
Hips → Spine02 → Spine01 → Spine → neck → Head
```

`neck` is lowercase. Arm chains are `LeftShoulder → LeftArm → LeftForeArm →
LeftHand`, with corresponding right-side names. Leg chains are `LeftUpLeg →
LeftLeg → LeftFoot → LeftToeBase`, again mirrored by name.

Pose targets use +Z forward, +Y up, +X anatomical left; Godot's named FORWARD
constant is -Z. Internally use metres, seconds and radians. Source rotations are
quaternions; do not confuse them with local YXZ correction curves. Verify bind
axes and rest-local versus model-space transforms instead of assuming identity.
The existing writer expects model-space targets including bind axes and writes
unit bone scales. It must not be used to conceal a stretched source rig.

The reviewed grip offset is hand-local `(side * .070, 0, .018)`, where side is +1
for left and -1 for right. A pole shaft extends along its local -Y. Verify these
against live code and equipment before measuring. Skin, cuff and pole clearance
must be checked after the final pose, not just against requested control targets.

## Historical pilot: what was verified before R4

Environment at test time: Windows, Cascadeur **2026.2.2.0.16638**, Pro trial;
Godot **4.7.2 custom build**. Re-check installed versions and current trial state.
This task does not authorize a purchase or subscription change. Commercial-use
terms were not established by the technical tests; keep trial diagnostics out of
released assets pending the applicable licensing check.

| Test | Observed result | What it does not establish |
|---|---|---|
| Built-in MCP | Local server executed Python to inspect, rig, pose, save and export | Reliable unattended operation for every API |
| Static GLB round trip | 24 bone names/parents preserved; max world-matrix coefficient difference ~1.42e-6 | A usable control rig or good skin deformation in motion |
| Units | 100× import and 0.01× export worked for the metre/centimetre conversion | A universal default for all file formats |
| Full mesh export | 49,217,948-byte source became 147,593,700 bytes | A reason to replace our production mesh/materials |
| Animation-only export | 83,956 bytes, 24 joints, 61 samples over two seconds | Approved skiing motion |
| Godot import | Both latest exports produced a 24-bone skeleton and sampled animation; hierarchy matched source | Production integration or gameplay visual acceptance |
| Godot pose comparison | Max error ~9.04e-6 m for Bezier and ~9.28e-6 m for AI at the compared samples | Whole-sequence skin/equipment clearance |
| Latest Bezier test | Maximum foot/toe joint drift ~1.36e-6 m across 61 frames | Ground contact on a slope or moving skis; this was a stationary model-space diagnostic |
| Latest AI test | Ankle drift up to 0.03284 m; toe drift up to 0.01092 m | Cascadeur's best achievable AI quality on a correctly configured rig |
| Torso | Neck-to-parent separation varied ~0.296 m with Bezier and ~0.301 m with AI; native image showed bad shoulder/torso deformation | A solved retargeting pipeline |
| Rendering | Native still rendering worked; scripted native video export froze the app | Reliable video export through MCP |

The trial used a body-only asset: **no boots, skis or poles were attached**.
AutoPosing controls were generated and a procedural control-point solve was
tested; this is not proof of artist-quality AutoPosing operation. AutoPhysics,
equipment constraints, mocap import and live gameplay performance were not tested.

Production GLB, Blender source and animation library were SHA-256 checked before
and after the trial and were unchanged. The hash receipts are evidence of that
session, not permission to overwrite a newer version in the next session.

## Historical pilot: failures, corrections and unresolved causes

### Rig setup

The first custom Mixamo template mapped stomach=`Spine02`, chest=`Spine`,
neck=`neck`. That skipped an intermediate spine joint. A later template used
chest=`Spine01`, but this correction alone did **not** fix deformation. Neither
`apex_body.qrigcasc` nor `apex_body_v2.qrigcasc` is an approved rig template.

The installed `rig_mode/off.py` conditionally runs an AutoPosing update during
one-frame rig creation when `RiggingTool/Update autoposing` is enabled. In this
test, that changed the initial pose and torso proportions dramatically. Creating
the 61-frame timeline **before** rig generation preserved the imported rest
positions. Subsequent posing still distorted the torso.

R4 established incorrect generated controller/segment mapping as the concrete
torso failure and verified an explicit-ObjectId construction route. See the
current checkpoint. Why the normal QRT generation route remapped stomach is
still unproven. Do not blame the GLB exporter: the bad pose was already visible
inside Cascadeur.

The pilot's numerical targets were arbitrary diagnostic inputs. Copying
`pose_trial_v3.py` into a new scene is not a plan for a good skiing animation.
The v3 Bezier export kept feet fixed while the torso failed: foot locking alone
is not sufficient acceptance. AI interpolation introduced additional foot drift;
solve the rig and conventional animation first before comparing AI again.

### Freeze and recovery

This exact operation, called from the MCP script context, froze the app:

```python
app.get_tools_manager().get_tool('RenderToFile').play_to_video_file(
    app.current_scene(), render_parameters, output_path)
```

The client timed out, the user reported Cascadeur had stopped working, and the
process was confirmed unresponsive. Both latest scenes had saved successfully
beforehand. The hung process was terminated and Cascadeur restarted with
`compression_v3_bezier.casc`; loading completed and it became responsive again.
No video was completed. Cause remains unknown; a main-thread execution-context
problem is a hypothesis, not a diagnosis.

**Do not repeat that video call through MCP.** Use guarded Blender/Godot previews
or bounded single-frame Cascadeur renders. Save before potentially blocking work.
After a timeout, inspect app state and logs before retrying a mutation: the
original operation may still be running. Never kill an unrelated app or a user's
unsaved session based on the historical PID from this trial.

The reopened scene showed orange/black surface artifacts not present in the
earlier still. Treat save/reopen material or viewport fidelity as a separate
unresolved issue. Do not retexture the production skier to work around it.

## Evidence and reusable technical entry points

All trial artifacts are in `artifacts/cascadeur_trial_20260910/`. These are
disposable evaluation files; verify they still exist. Do not overwrite them with
a new attempt. Preserve useful source files outside disposable artifacts when
turning a successful experiment into maintained tooling.

| Files | Use |
|---|---|
| `compression_v3_bezier.casc`, `compression_v3_ai.casc` | Latest saved **failed-quality diagnostic** scenes |
| `compression_v3_bezier_animation.glb`, `compression_v3_ai_animation.glb` | Corresponding animation-only exports; not production candidates |
| `v3_bezier_key30.png` | Actual native render of the deformation defect |
| `skier_source.glb`, `skier_roundtrip.glb`, `static_roundtrip_audit.json` | Original snapshot and static round-trip evidence |
| `generated_rig_v3_baseline.json`, `generated_rig_v3_compression.json` | Scene joint/control positions in centimetres |
| `animation_v3_bezier_audit.json`, `animation_v3_ai_audit.json` | All sampled exported world transforms and drift metrics in metres |
| `godot_import_audit.json`, `godot_comparison.json` | Successful import and sampled pose comparison |
| `source_hashes.json`, `source_hashes_after.json` | Baseline and unchanged production asset receipts |
| `receipts/`, `cascadeur_log_before_recovery.log` | Exact MCP operations and server log before recovery |

Guarded Godot logs are in `artifacts/guarded/cascadeur_import/`; stdout contains
`CASCADEUR_IMPORT_PROBE PASS`, stderr was empty, exit code was zero. Both exported
skeleton hierarchies matched the source. The probe samples an isolated skeleton;
it does not place this clip on the production character through gameplay fitting.

The local client is `call.py` in the trial folder. It posts JSON-RPC `tools/call`
for `run_script` to `http://127.0.0.1:8765/mcp`, with `{ "code": "..." }` arguments.
It records requests/responses but currently does not record a normal receipt
when its 45-second HTTP timeout throws. The installed server provides `scene`,
`app` and `csc` in the script context and runs queued code on the application's
main thread. It exposes one general Python tool, not a collection of dedicated
animation tools. This connection was **not registered as a persistent Codex MCP
plugin**. After the recovery restart, do not assume the server is running.

If needed, use the current computer-use skill to enable
Scripts → MCP → Start script server, then make a read-only health/scene query.
Inspect existing user tabs first. Do not silently reuse an old scene reference
when a new scene has become active.

Installed documentation/source locations at test time:

```text
C:/Program Files/Cascadeur/resources/scripts/python/scripts/mcp/script_server/README.md
C:/Program Files/Cascadeur/resources/scripts/python/scripts/mcp/script_server/server.py
C:/Program Files/Cascadeur/resources/scripts/stubs/csc/
C:/Program Files/Cascadeur/resources/scripts/python/rig_mode/off.py
C:/Program Files/Cascadeur/resources/autorig_templates/Mixamo_No_Namespace_Template_New.qrigcasc
```

Useful API lessons:

- Explicit save: `app.current_scene().save(full_path)` worked.
  The tested `save_scene_as` route opened a modal dialog instead.
- Separate timeline resize, rig generation, pose edits and export into inspected
  steps. Resizing then solving poses in one callback produced a failed update.
- Assert the result of `scene.modify_update_with_session(...)`; an outer MCP
  success can contain a failed modification callback. Inspect the app log too.
- `get_objects()` plus `get_object_type_name()` was used for type filtering;
  do not mistake a name filter for a type filter. Not every `_MainPoint` named
  object is a Point with Transform data.
- Animation-only export selected Joint objects plus `Armature`, excluding mesh
  and generated helpers. `csc.glb.ExportOptions` used `include_animation=True`,
  `for_selected_objects=True`, `for_selected_interval=False`, `scale_factor=.01`,
  `fps=30`, `throw_exception=True`.
- `RenderToFile.take_image(scene_view, params, path)` worked for single images.
- The v3 reproduction sequence is documented by `create_v3.py` →
  `create_timeline.py` → `rig_v3.py` → `rig_mode.off.run(scene, True, True)` →
  `pose_trial_v3.py` → `export_v3_bezier.py`. These files contain hard-coded output
  paths and recreate the failure. Read/adapt them; do not execute them blindly.
- `audit_glb.py` adds `.tools/motion-plots` to Python's package search path for
  NumPy. It is a package directory, not a virtual environment. Resolve Python
  and dependencies on the new session rather than assuming a remembered path.
- `audit_animation.py` defaults to the **first-attempt** filenames when run as a
  script. Use its sampling helper with explicit new filenames or update a copy.
  Its current 61-frame/30-FPS assumptions are specific to this diagnostic.

## Execution plan and gates

### 1. Establish the current baseline

Inspect open authoring apps, live asset hashes, production owner functions and
the shared validation lock. Use a new attempt folder. Record a rest-pose image
and joint transforms from the untouched source. Inspect `v3_bezier_key30.png` and
the v3 numerical evidence to understand the actual failure before editing.

Create a small diagnostic set: rest/ready, shallow compression, deeper
compression, and recovery. For each stage record local translations/scales,
world joint positions, segment lengths, controller targets and a skinned render.
Use controlled front, side and oblique views. Do not hide a defect by changing
camera scale between comparisons.

### 2. Make the rig trustworthy

Start from a clean imported copy, with conventional interpolation and the
unwanted initial AutoPosing update prevented. Verify anatomical mapping against
positions and parentage, not names alone. Check spline distribution, joint rest
orientations, inherited scale and generated controller offsets.

Change one suspected cause at a time and record its result. Find the first stage
where the torso diverges; do not compensate with another layer of pose offsets.
If useful, compare a supported stock humanoid to this source rig to isolate an
import/custom-rig problem. A stock-rig success is diagnosis, not task completion.
Try a Blender-prepared canonical authoring skeleton only if evidence points to
an import/bind-axis issue; retain an explicit retarget back to the existing game
skeleton. Do not silently replace the project's canonical rig.

Gate: all diagnostic poses retain connected anatomy, stable intended segment
lengths and unit export scales, with no torso collapse/stretch or bad shoulder
skin. Validate save/reopen as well. Use numerical tolerances justified by the
rig and floating-point error, and inspect the rendered mesh. If Cascadeur setup
continues to fail, explain the observed failure and any established cause, then
evaluate the next promising approach instead of lowering the quality requirement
or treating Cascadeur repair as mandatory.

### 3. Author the actual movement

Choose suitable reference with clear support, hip/knee flexion, torso and gaze.
Reuse good licensed motion or project-authored poses where appropriate. Reference
video is visual guidance; do not assume inferred hidden joints are accurate mocap.

Set a few intentional poses and timing beats: athletic ready stance, anticipation,
compression, recovery, and a stable exit. Preserve cuff limits, forward gaze,
continuous spine, readable weight shift and connected arms. Include rigid boots,
skis and poles early enough to shape the pose; a body-only silhouette is not
enough. Use action-specific arm balance, not global tuck hand coordinates.

First obtain a good conventional version. Then compare AI interpolation on a
copy only if it improves the motion without losing contacts or proportions.
AutoPhysics is optional and untested here: sliding skis and slope support differ
from walking foot plants. Do not let an authoring simulation replace game physics.

### 4. Export, integrate and review the final result

Export animation only, preserve the original skinned mesh/materials, and verify
names, hierarchy, rest transforms, timing, units and root-motion policy. Re-run
an adapted import probe for the new clip. Any direct AnimationPlayer preview is
an intermediate check; feed the candidate through the existing composition,
fitting and final writer for the gameplay evidence.

Compare source → requested → final pose. If a source pose is good but the final
pose is bad, diagnose the specific blend/limit/fitting stage before changing
the source again. In the game, judge feet relative to solver-owned skis/support;
world-space foot movement during downhill travel is expected and is not itself
foot sliding.

Use a new revision with the maintained `scripts/pose_review/` workflow. Resolve
and pin the actual engine, capture/freeze sources, select physical-event phases,
then render and inspect the whole chronological sequence at normal and slow
speed. Include front, side, oblique, overhead equipment views and gameplay view.
Run selected checks while iterating, then full relevant clothing/attachment
coverage and regressions for the candidate. For flight/landing audits include
`-IncludeFlight` and confirm nonzero scenario coverage. Check ready/tuck entry,
light and strong steering both directions, and release/residual turn so the new
carry does not break neighboring actions.

Mechanical foundations include `tests/skier_motion_suite.gd`,
`skier_anatomy_suite.gd`, `steep_motion_suite.gd`, and, where applicable,
`landing_absorption_suite.gd` and `airborne_pose_suite.gd`. Choose tests according
to the files changed; preserve the shared guard. Read the current tool recipes
rather than copying old renderer commands. If a guarded command returns zero,
still inspect logs for Godot errors.

## Evaluation outcome and handoff requirements

- An evidence-based recommendation: continue with Cascadeur, choose an
  alternative, or run a clearly specified remaining experiment. Explain quality,
  authoring effort, reliability and maintenance tradeoffs. Adoption and paid
  commitment remain undecided until the user chooses; do not assume either.
- For a successful candidate, editable authoring source, a reproducible export
  procedure, and a good reference-led sequence on the actual skier and equipment
  with clean rest/skin compatibility and usable Godot animation data.
- A failed candidate is a valid evaluation result when supported by reproducible
  evidence and a useful next recommendation. Do not imply a good animation was
  achieved if it was not, or treat rejecting Cascadeur as failure of the task.
- Matched before/after evidence, chronological playback, selected phase reasons,
  source/engine hashes, actual commands and validation logs in a new revision.
- Final-pose checks for anatomical continuity, cuff/boot alignment, grip/cuff
  errors, complete pole shafts/tips, skin clearance and transition smoothness.
- Honest author review identifying the worst remaining issue. Obtain independent
  review if available; keep its evidence ID and comments separate from author
  review. Do not invent grades, use old grades for new evidence, or imply user
  acceptance. No new numerical artistic grade was requested in this handoff.
- A clear explanation of whether Cascadeur merits further use, including any
  remaining rig, material or automation limits and alternatives actually tested
  versus alternatives only proposed.
- Update the relevant maintained documentation with newly verified reasoning.
  Do not call the task complete merely because imports or mechanical tests pass.
  A preview-only result must be labelled preview-only; user gameplay/visual
  acceptance remains a separate result.

The next agent should use the new linked task and the user-reviewed R5 baseline.
The torso mapping, working builder route, equipped preview and re-export are
already established. Do not repeat the initial MCP/GLB investigation.

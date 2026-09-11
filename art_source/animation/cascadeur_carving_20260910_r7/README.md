# Editable Cascadeur R7 carving source

Open `carving_r7.casc` in Cascadeur. The retained export is
`carving_r7_animation.glb`; the independent reopened export is
`carving_r7_reopened.glb`. They agree within 0.001 mm despite different file hashes.
The original R5/R6 scenes and their sealed review folders were not modified.

This scene contains neutral at frames 0/30/60, authored right at 15 and left at 45,
sampled at 30 FPS. `build_controls.py` defines 31 oriented control targets at all
61 frames. It uses the established R5 rest calibration and neutral targets.
`solve_controls.py` submits those targets to the Cascadeur rig. Timing/targets are
scripted; native AI Inbetweening and AutoPhysics are not part of this variant.

The in-game experiment uses the local differences between neutral and the turn
poses as a small layer over current carving, before its final limits/tracker.
See [integration, controls and limitations](../../../docs/presentation/CASCADEUR_CARVING_R7.md).

## Re-export without overwriting evidence

The installed local MCP endpoint is `http://127.0.0.1:8765/mcp`. Start it from
Cascadeur's Scripts > MCP > Start script server if it is stopped. Its `run_script`
method executes scripts inside the app. Run shell commands from the project root.
First verify the active scene with a read-only `mcp_call.py` request; the export
helper also asserts that it is this R7 scene.

```powershell
python art_source/animation/cascadeur_carving_20260910_r7/mcp_call.py verify_scene --code "print(app.current_scene().get_path_name())"
python art_source/animation/cascadeur_carving_20260910_r7/mcp_call.py export_fresh --code "output_name='carving_r7_verification_new.glb'; exec(open('C:/Users/hp/Downloads/alpine-apex/art_source/animation/cascadeur_carving_20260910_r7/export_animation.py',encoding='utf-8-sig').read())"
python art_source/animation/cascadeur_carving_20260910_r7/audit_animation.py art_source/animation/cascadeur_carving_20260910_r7/carving_r7_verification_new.glb art_source/animation/cascadeur_carving_20260910_r7/verification_new.json --compare art_source/animation/cascadeur_carving_20260910_r7/carving_r7_animation.glb
```

The export selects exactly 24 joints plus Armature, uses 0.01 scale, and includes
animation only. Pick fresh output names; helpers refuse existing exports/audits.
Save, load and export calls are separate. Inspect the inner `ok`/`isError` and
current scene after any timeout before retrying a mutation. `receipts/` preserves
the executed requests, including the initial disconnected-server result.

## Review reproduction

Existing captures and frozen sources are under
`artifacts/pose_review/revisions/cascadeur-20260910-r7-{source,production,gameplay}`.
The fixtures are reproducible recipes, not commands to overwrite frozen evidence.
For another candidate choose a new source/revision folder, update explicit paths,
then capture, freeze, render, audit and compare using maintained `scripts/pose_review/`
tools. `prepare_review.py` records how inspected R6 import/capture recipes were
adapted; it is a one-time scaffold and refuses existing files.

The completed stages use `run_review.ps1` under one direct guard per invocation:

```powershell
./scripts/run_guarded.ps1 -FilePath (Get-Command pwsh).Source -Arguments @('-NoProfile','-File',"$PWD/art_source/animation/cascadeur_carving_20260910_r7/run_review.ps1",'-Stage','Tests') -AllowConcurrent -Label cascadeur-r7-new-tests -TimeoutSeconds 300
```

Stages `Capture`, `Selected`, `Full`, `Audit`, `Videos` and `Chase` contain the exact
Godot/Python/FFmpeg arguments. Audit failures must be read; the baseline tuck-turn
case exposed a pre-existing problem and interrupted the first finishing batch.
No failed batch is a successful validation. Guard logs and assessment record the
separately completed stages and observed limitations.

Attempt 01 is retained under `attempt01/` with its export, targets and audit.
Its segment stretch and wrist-helper issue were fixed in the retained scene.

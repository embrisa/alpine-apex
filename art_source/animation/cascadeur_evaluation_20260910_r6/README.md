# Cascadeur R6 editable evaluation source

This is the retained task-owned R6 scene and animation export. It is not installed
in the production motion library. [Outcome and limitations](../../../docs/presentation/CASCADEUR_WORKFLOW_EVALUATION_R6.md).

Open `ready_compression_r6.casc` in Cascadeur. The source has 61 solved frames
at 30 FPS and 31 constrained point controls. R5's recovery beat 44 moves to R6
frame 48; the remaining meaningful beats are 0, 12, 24, 30 and 60. The native
scene is 297,216,864 bytes. `ready_compression_r6_animation.glb` is an animation-only
24-joint export, 83,956 bytes. Original mesh, skin and equipment remain in Godot.
`manifest.json` pins these files, recipes and receipts by SHA-256.

## Tested edit/export procedure

Run shell examples from `C:/Users/hp/Downloads/alpine-apex`. Cascadeur 2026.2.2.0.16638
was running with trial export available and its installed script/MCP server on
`http://127.0.0.1:8765/mcp`. The installed `csc.glb` API was used directly. Preserve
unrelated and unsaved tabs; these recipes assert the active R6 scene path.

The executed sequence was:

1. Copy the preserved R5 `.casc` to this task-owned R6 path, then open it with
   `app.get_data_source_manager().load_scene(path)`. Check the active scene before
   continuing. Export the reopened baseline to `r5_reopened.glb` and compare it
   with the original R5 animation. Maximum position difference was 0.000596 mm.
2. Run `python art_source/animation/cascadeur_evaluation_20260910_r6/build_timing_edit.py`.
   It applies six monotone timing knots to R5's 31 oriented control targets,
   writes `control_targets.json`, and refuses to overwrite an existing file.
   This command has already been executed; retain the existing result.
3. Submit `solve_controls.py` through the installed server using:

   ```powershell
   python art_source/animation/cascadeur_evaluation_20260910_r6/mcp_call.py solve_timing_edit art_source/animation/cascadeur_evaluation_20260910_r6/solve_controls.py
   ```

   The one Cascadeur transaction solved all 61 frames. Python supplied timing and
   control targets; Cascadeur supplied constraint solving. No per-frame manual
   repairs, native AI interpolation or AutoPhysics were used.
4. Export with the helper below, save the active R6 scene with
   `app.current_scene().save(path)`, then reopen that saved scene in its own tab
   and export to another fresh filename. Save, reopen and export were separate
   calls, with inner `ok` and `isError` inspected. The exact scripts and results
   are preserved in timestamped `receipts/*.json`.

To re-export the retained R6 scene without modifying its animation, open it and
run this in Cascadeur's script context, choosing a fresh basename:

```python
output_name = 'r6_verification_new.glb'
exec(open('C:/Users/hp/Downloads/alpine-apex/art_source/animation/cascadeur_evaluation_20260910_r6/export_animation.py').read())
```

The helper selects exactly 24 joints plus Armature, uses scale 0.01 and 30 FPS,
and refuses existing outputs. `mcp_call.py LABEL --code CODE` submits the same
script remotely and writes a receipt even after transport failure. Inspect state
and outputs after a timeout before retrying a mutation. The saved/reopened R6
comparison is `r6_reopen_audit.json`: position difference below 0.000608 mm.
Audit a fresh export with:

```powershell
python art_source/animation/cascadeur_evaluation_20260910_r6/audit_animation.py art_source/animation/cascadeur_evaluation_20260910_r6/r6_verification_new.glb art_source/animation/cascadeur_evaluation_20260910_r6/verification_new.json --compare art_source/animation/cascadeur_evaluation_20260910_r6/ready_compression_r6_animation.glb
```

The audit uses NumPy from the existing `.tools/motion-plots`. It verifies timing,
hierarchy, units, scales, contacts, normalized rotation continuity and transforms.
`audit_bind_rest.py` separately checks original inverse-bind rest axes. Tiny scale
noise must be removed before computing rotation angles. The initial R5 reopen
audit predates that normalization and is retained as historical evidence only;
its transform comparison remains valid.

These helpers deliberately contain this evaluation's paths and output guards.
For a later authoring experiment, copy the recipes and scene into a fresh revision,
update explicit paths/assertions, and choose fresh review outputs. Do not overwrite
R5, R6 captures or seals to make a rerun succeed.

## Gameplay reproduction and review

`gameplay_capture.gd` runs a shared actual 120 Hz solver through two instances of
the current presentation pipeline. `evaluation_motion.gd` only substitutes forward
navigation samples in the candidate. The phase/input policy is in the report and
the capture JSON. Production sources, limits, tracking and final writer are shared.
`preview_capture.gd` is the separate isolated authored transfer check.

The completed commands used the guard directly with `-AllowConcurrent`, one owner
per label, and sequential stages inside each batch. Example of the executed capture:

```powershell
./scripts/run_guarded.ps1 -FilePath "$PWD/.tools/godot-fsr/bin/godot.windows.template_debug.x86_64.console.exe" -Arguments @('--path',"$PWD",'--headless','--script','art_source/animation/cascadeur_evaluation_20260910_r6/gameplay_capture.gd') -AllowConcurrent -Label cascadeur-r6-gameplay-capture -TimeoutSeconds 240
```

The fixture refuses existing capture manifests. A new execution requires a fresh
revision and adjusted recipe constants. `scripts/pose_review/freeze_sources.py`
pins sources/tooling; the maintained `tests/pose_reference_render.gd`,
`encode_videos.py`, `compare_revisions.py`, `inspect_revision.py` and
`tests/pose_pole_mesh_audit.gd` produced the evidence. `review_batch.ps1` records
the tested render/encode/audit commands; the source's full render was a separate
preceding step. Do not rerun this batch over existing encoded videos.

`gameplay_camera_render.gd` rephotographs recorded ChaseCamera transforms.
`stage_diagnostics.gd` reconstructs selected source/requested states without
feeding them back to gameplay. `analyze_gameplay.py` measures attachments and
matched physical state; `stage_analysis.json` records all 605 static-stage deltas.
`match_details.ps1` rephotographed R6 details with exact baseline cameras using a
small subclass of the maintained renderer. The original pelvis-following images
remain under `details_pelvis_focus/`, explicitly superseded for matched comparison.

The first regression batch was interrupted after skier motion and anatomy passed.
`remaining_tests.ps1` completed steep motion, compact posture and attachment tests.
All five result summaries pass (236 checks). The original production render batch
was interrupted after encoding; its 605-frame clothing audit was completed in a
separate guard. `collect_execution.py` preserves these distinctions and their logs.

To verify frozen evidence, without executing a new simulation:

```powershell
python scripts/pose_review/inspect_revision.py --revision cascadeur-20260910-r6-gameplay --require-snapshot --verify-seal
python scripts/pose_review/inspect_revision.py --revision cascadeur-20260910-r6-production --require-snapshot --verify-seal
python scripts/pose_review/inspect_revision.py --revision cascadeur-20260910-r6-source --require-snapshot --verify-seal
python scripts/pose_review/inspect_revision.py --revision cascadeur-20260910-r6-diagnosis --require-snapshot --verify-seal
```

To serve the review, first inspect `http://127.0.0.1:8769/__pose_review_health`.
If the matching server is already available, use it. Otherwise run:

```powershell
python scripts/pose_review/serve_review.py --root artifacts/pose_review --port 8769
```

Open [R6 review](http://127.0.0.1:8769/comparisons/cascadeur-20260910-r6/review.html).
Native material corruption persists after reopening, while the Godot render uses
the original materials correctly. No adoption, purchase, controller acceptance,
mountain descent or performance claim follows from these checks.

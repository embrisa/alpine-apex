# R8 snow-support trial

R8 retains the R7 Cascadeur upper-body source. It adds no native Cascadeur file
or new imported leg clip. See [the handoff](../../../docs/presentation/CASCADEUR_SNOW_LEGS_R8.md)
for exact user feedback, implementation, coordinates and acceptance limits.

The live trial is `tests/cascadeur_r8_playtest/playtest.tscn`, launched with
`Play Cascadeur Snow Carving.cmd`. F9 changes physical snow support while R7 hands
stay enabled. Runs are unranked. The core simulation is inherited; concurrent
model-28 handling work remains in the normal project.

The frozen R8-01 movie pair was captured against base model 27, before the
concurrent handling change. `coordinate_probe.gd` checks the same frame-54 boot
origins against current source. It is deliberately a separate coordinate
receipt, not a silent replacement of the movies.

Recipes used (run from the project root with an explicit engine and the project
validation guard; use new labels/revision IDs for later attempts):

```powershell
./scripts/run_guarded.ps1 -FilePath pwsh -Arguments @('-NoProfile','-File','tests/cascadeur_r8_playtest/run_checks.ps1') -Label NEW_checks -TimeoutSeconds 180
./scripts/run_guarded.ps1 -FilePath '.tools/godot-fsr/bin/godot.windows.template_debug.x86_64.console.exe' -Arguments @('--path','C:/Users/hp/Downloads/alpine-apex','--headless','--script','tests/cascadeur_r8_playtest/coordinate_probe.gd') -Label NEW_coordinates -TimeoutSeconds 60
```

Capture: `tests/cascadeur_r8_playtest/capture.gd`, supplied with a fresh
`--revision-base=res://artifacts/pose_review/revisions/NEW-` path. The live recipe
now derives model labels from the actual simulation. The R8-01 source snapshots
retain the original model-27 recipe exactly. Render with maintained `tests/pose_reference_render.gd`
at camera size 4.1; use `tests/pose_pole_mesh_audit.gd` over all six scenarios.
The audit must retain both variants' reports even when clothing fails.

`analyze.py` checks final fitted geometry at matched input times. Its paths target
the frozen R8-01 pair. `prepare_media.py` created full and front-leg videos and
chronological inspection sheets before sealing. It intentionally refuses an
existing inspection directory. `finalize_evidence.py` records receipts and
seals all files; it must not be rerun over sealed evidence.

No file-integrity seal, geometry result or author inspection is user acceptance.
The known shared tuck/pole intersection remains in both movie variants.

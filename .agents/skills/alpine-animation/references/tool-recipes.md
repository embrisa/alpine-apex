# Pose review commands

Run at repository root. Resolve Python 3 (`$py`), Godot console (`$engine`) and
ffmpeg (`$ffmpeg`) from the current installation. Pin the same explicit engine
and hash for both revisions. Use a new `$rev` for changed source; never overwrite
historical evidence.

## Inspect and capture

```powershell
& $py scripts/pose_review/inspect_revision.py --revision $before --require-snapshot --verify-seal
$folder = "artifacts/pose_review/revisions/$rev"
./scripts/pose_review/run_stage.ps1 -Stage Capture -Revision $rev -Engine $engine -Scenarios 'regular,tuck,prepare_takeoff,carve_left,carve_right'
& $py scripts/pose_review/freeze_sources.py --revision $rev
& $py scripts/pose_review/select_frames.py --revision $rev
./scripts/pose_review/run_stage.ps1 -Stage Render -Revision $rev -Engine $engine -Selected
./scripts/pose_review/run_stage.ps1 -Stage Details -Revision $rev -Engine $engine -Selected
& $py scripts/pose_review/measure_alignment.py --revision $rev --output "$folder/alignment.json"
./scripts/pose_review/run_stage.ps1 -Stage Diagnose -Revision $rev -Engine $engine
./scripts/pose_review/run_stage.ps1 -Stage Audit -Revision $rev -Engine $engine -Scenarios 'regular,tuck,prepare_takeoff' -Selected
```

Stop on a failed stage. `run_stage.ps1` already uses the exclusive guard and fails
on Godot error lines; do not nest guards. `-Describe` prints arguments. Capture/
Audit defaults include six scenarios: pass actual scope explicitly. Diagnose
always uses selection; `-Selected` applies to Render/Details/Audit. Flight and
landing audit coverage needs `-IncludeFlight`.

Capture samples final bones/world equipment at 60 FPS over the 120 Hz solver in
an unranked cached fixture. Freeze immediately before editing: manifest hashes
must match. Current captures hash six equipment GLBs; R1-R4 did not. `tooling.json`
records copied tools, not executed checks. Preserve textures/imports separately
when appearance changes or cross-machine reproduction matters.

Inspection reports coverage, drift, snapshot/seal integrity and actual receipts;
missing checks are null. `--require-live` is only for captures expected to match
current source. A missing historical capture needs a known-state recapture.
Selection IDs are frame IDs, not offsets. Inspect event/peak/neighbor reasons,
represent all scenarios and add defects before sealing. Support loss defines the
end of grounded preparation, not a historical frame number.

Render rephotographs frozen final transforms without simulation: whole-body
triptychs are 2400x1000; details use fixed 1.35 m scale and pelvis-following focus.
Check recorded camera transforms/restored-bone error. Historical rig changes need
isolated source/assets; do not swap live files to reproduce them.

## Full sequence and comparison

```powershell
./scripts/pose_review/run_stage.ps1 -Stage Render -Revision $rev -Engine $engine
./scripts/pose_review/run_stage.ps1 -Stage Audit -Revision $rev -Engine $engine -Scenarios 'regular,tuck,prepare_takeoff,carve_left,carve_right'
./scripts/pose_review/run_stage.ps1 -Stage Regression -Revision $rev -Engine $engine -AnimationOnly
& $py scripts/pose_review/encode_videos.py --revision $rev --ffmpeg $ffmpeg
& $py scripts/pose_review/compare_revisions.py --before $before --after $rev --output "artifacts/pose_review/comparisons/$rev" --require-physics-match
```

Full rendering replaces selected metadata only in unsealed revisions. Encoding
requires every frame, preserves captured FPS and creates new movies without gap
renumbering/interpolation/overwrite. Comparison pairs after-selection IDs, rejects
coverage/physics mismatch and never grades. Verify camera matching separately.
Retain both source revisions and inspect stills, full chronology and playback.

AnimationOnly covers anatomy, compact posture, attachment and motion. Flight/
landing adds `tests/landing_absorption_suite.gd`, `tests/airborne_pose_suite.gd` and
action-specific contact/grip evidence. Solver/input/session changes additionally
need [project checks](../../../../docs/VALIDATION.md#check-selection).
Tool changes use `tests/pose_review_tools_test.py`, real-capture CLI checks and a
guarded render smoke when rendering changes.

Readers, selection, measurement, comparison and encoding use Python stdlib;
contact sheets (`inspect_capture.py --revision NAME --sheets`) and grading packages
also need Pillow. New outputs refuse overwrite/sealed destinations; stdout
measurement can inspect sealed evidence, with new analysis saved elsewhere.
Structural skill validation separately requires PyYAML.

For named-parameter PowerShell scripts, target native `pwsh` through the guard
with `@('-NoProfile','-File',SCRIPT_PATH,...)`; direct string array splatting binds
named-looking arguments positionally. Explicitly authorized isolated concurrent
checks may use `scripts/run_guarded.ps1 -AllowConcurrent` with unique labels;
timings are then contended. Keep stages sequential and preserve other workloads.

## Browser, assessment and seal

`serve_review.py --root artifacts/pose_review --port 8769` serves localhost.
Reuse a matching `/__pose_review_health` response; do not kill another port owner.
Start background helpers with `Start-Process -WindowStyle Hidden`. Open the real
page and check media, controls, decoding and console before recording browser
success.

`build_review.py` consumes explicit assessment-source schemas. Historical
`author_assessment_r1.py`/`author_assessment_r2.py` are author records, not new-grade generators.
`tests/pose_review_evidence.py` validates that package, not the focused comparison;
`tests/pose_review_state.test.cjs` checks independent user/model feedback state.

Seal actual files after executed checks and review, then verify their hashes.
Keep captures, frozen sources, tool/engine identity, render metadata, audit scope,
regressions and reviewer records together. Do not reuse disposable artifact
`seal.py`/`publish.py` with dated paths/manual receipts. A seal preserves evidence;
acceptance remains separately recorded.

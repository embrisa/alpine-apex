# Reproducible tool recipes

Run from the repository root. Resolve an available Python 3 executable (`$py`),
Godot console executable (`$engine`) and, for video, ffmpeg (`$ffmpeg`) first.
Use the workspace dependency loader if Python is not on PATH. Do not copy a
historical user's absolute runtime path. `godotw.ps1` can select a custom engine;
pin the same explicit `-Engine` for both sides and record its hash/version.

## Inspect before spending a render

```powershell
& $py scripts/pose_review/inspect_revision.py --revision 20260909-r4 --require-snapshot --verify-seal
```

This reports stable capture coverage, source drift, snapshot integrity, selected
IDs and existing render/audit/regression receipts. Missing checks are `null`.
Historical live-source drift is informational; add `--require-live` for a capture
that must match current sources. `--verify-seal` verifies the listed SHA-256 files;
the sealed flag alone does not. Do not infer acceptance
from a revision number, test result or author score. Artifacts are disposable;
if a historical capture is gone, the durable lessons remain but its baseline
must be recaptured from a known source state, not invented.

## Capture, diagnose, iterate

Choose a new descriptive revision name for every changed source candidate.
`$rev` below is that new name, not R4. Do not run a new capture into old evidence.

```powershell
$rev = 'tuck-candidate-01'
$folder = "artifacts/pose_review/revisions/$rev"
./scripts/pose_review/run_stage.ps1 -Stage Capture -Revision $rev -Engine $engine -Scenarios 'regular,tuck,prepare_takeoff,carve_left,carve_right'
& $py scripts/pose_review/freeze_sources.py --revision $rev
& $py scripts/pose_review/select_frames.py --revision $rev
./scripts/pose_review/run_stage.ps1 -Stage Render -Revision $rev -Engine $engine -Selected
./scripts/pose_review/run_stage.ps1 -Stage Details -Revision $rev -Engine $engine -Selected
& $py scripts/pose_review/measure_alignment.py --revision $rev --output "$folder/alignment.json"
```

Check each command's exit status before continuing. `run_stage.ps1` uses the shared
exclusive guard, preserves logs and fails on Godot error lines even with exit 0.
It uses the existing cached production fixture, never a race session. If another
workload owns the lock, leave it running and retry after it finishes; no nested
guards. `-Describe` prints arguments without starting a workload. `-Selected`
applies to Render/Details/Audit. Diagnose always uses the selection. Defaults for
Capture/Audit include six scenarios; pass the actual desired set explicitly.

When the user authorizes an isolated visual or functional check concurrently,
invoke `scripts/run_guarded.ps1` directly with `-AllowConcurrent` and a unique
label. This skips the shared lock and busy-process exclusion while retaining
the owned process job, timeout, error checks and diagnostics. It does not stop
existing workloads. Treat overlapping timings as contended, not performance
baselines. Keep each review's output folder separate and its stages sequential.

Capture records actual final bones and world equipment at 60 FPS over the 120 Hz
solver. Freeze immediately, before editing: all manifest source hashes must still
match. Future captures include the six current ski/binding/boot/pole GLBs. Review
tools are copied separately into `tooling/` with `tooling.json`; their snapshot
time is not a receipt that checks ran. Earlier R1–R4 captures did not hash equipment
assets. Material textures/import caches are not a complete archived runtime;
preserve them as well if changing appearance or reproducing on another machine.

The selector chooses entry/middle/end, supported compression, peak relevant
channels, physical bank for carves, and neighbors of physical events. It saves
reasons separately. It is a starting selection: review it and add problem frames
with explicit reasons before sealing. IDs are frame IDs, not list offsets. Keep
all captured scenarios represented. Preparation's grounded compression ends at
support loss, even if the old reference used frame 65. Do not select only good poses.

```powershell
./scripts/pose_review/run_stage.ps1 -Stage Diagnose -Revision $rev -Engine $engine
./scripts/pose_review/run_stage.ps1 -Stage Audit -Revision $rev -Engine $engine -Scenarios 'regular,tuck,prepare_takeoff' -Selected
```

The fixed-scale whole-body renderer emits 2400×1000 triptychs (oblique/front/side).
Details emits oblique/overhead/side at fixed 1.35 m scale with pelvis-following
focus. Each records camera transforms and restored-bone error. The renderer
rephotographs final frozen transforms and does not run the solver. For a historical
rig/attachment change use an isolated source/asset snapshot; do not replace live
project files to make old evidence render. Current renderer checks captured GLBs.

Use `--help` on the Python tools. The new readers, selector, measurements,
comparison and encoder accept a revision name or explicit path, use only the
standard library and refuse output inside sealed revisions. New
selection/JSON/comparison outputs do not overwrite existing files. Measurement
output to stdout works for sealed evidence; save new analysis in a separate folder.

For a chronological contact sheet after full rendering, use
`inspect_capture.py --revision NAME --sheets`. It prints event-based selected
phases and creates `inspection/*.jpg`; contact sheets and the grading packager
also require Pillow. The skill creator's structural validator separately needs
PyYAML. These dependencies are not required by the standard-library review tools.

## Complete evidence and regression

```powershell
./scripts/pose_review/run_stage.ps1 -Stage Render -Revision $rev -Engine $engine
./scripts/pose_review/run_stage.ps1 -Stage Audit -Revision $rev -Engine $engine -Scenarios 'regular,tuck,prepare_takeoff,carve_left,carve_right'
./scripts/pose_review/run_stage.ps1 -Stage Regression -Revision $rev -Engine $engine -AnimationOnly
& $py scripts/pose_review/encode_videos.py --revision $rev --ffmpeg $ffmpeg
```

Full render replaces the unsealed selected render metadata with full coverage.
The encoder checks every frame, keeps captured FPS and writes new `videos/*.mp4`.
It never interpolates, renumbers gaps or overwrites a movie. Review normal speed
and slow playback; a studio render is not a controller-feel or performance test.

| Change | Mechanical checks beyond visual review |
|---|---|
| Downhill arm/trunk/attachment correction | `Regression -AnimationOnly`: anatomy, compact posture, ski attachment, skier motion |
| Landing / flight / grabs | Add `landing_absorption_suite.gd`, `airborne_pose_suite.gd` and relevant anatomy/grip cases; new contact/mesh evidence for that action |
| Physics, input or session ownership | `tests/physics_suite.gd`, `tests/runtime_suite.gd`, plus affected contact/terrain tests; read architecture first |
| Tool-only changes | `tests/pose_review_tools_test.py`, relevant real-capture CLI checks, guarded render smoke if renderer changed; no need to rerun unrelated physics |

Other Godot suites use `scripts/run_guarded.ps1 -FilePath ./godotw.ps1
-Arguments @('--headless','--script','tests/airborne_pose_suite.gd')` with a unique
label, outside another guard. Do not broaden testing indefinitely once relevant
checks pass and the intended visible result is established.

For a PowerShell script with named parameters, make the guard's target the native
`pwsh` executable and pass `@('-NoProfile','-File',SCRIPT_PATH,...)`. Directly
array-splatting strings such as `'-Output'` into a parameterized `.ps1` binds them
positionally. The stage runner already handles this for Regression.

## Compare, review and hand off

```powershell
& $py scripts/pose_review/compare_revisions.py --before $before --after $rev --output "artifacts/pose_review/comparisons/$rev" --require-physics-match
```

The page pairs the after-selection's frame/tick IDs, shows full triptychs and
available details/videos, and reports exact differences in recorded physics and
ski fields. It fails on different scenario/frame coverage and never assigns grades.
Missing images/videos are labeled; render them before final acceptance. Inspect
linked camera metadata: tick matching alone does not establish camera matching.
The output references source media; retain both revisions with the comparison.

`serve_review.py --root artifacts/pose_review --port 8769` is a localhost static
server. Check `http://127.0.0.1:8769/__pose_review_health` to reuse a matching server;
do not terminate an unrelated port owner. Launch any background Python helper with
PowerShell `Start-Process ... -WindowStyle Hidden`. Open the actual page and verify
images, controls, video decoding and console errors using available browser tools.
Never fill a “browser passed” field because generation succeeded.

For per-bone grading, the maintained `build_review.py` and schemas provide the
structured grading UI; read its required assessment-source format before use.
`author_assessment_r1.py`/`r2.py` are historical author records, not grade generators
for new revisions. `tests/pose_review_evidence.py` validates that grading package,
not the separate focused comparison format. The user/model stores are independent.
`tests/pose_review_state.test.cjs` checks feedback-state semantics.

Keep raw capture, frozen sources, tool/engine identity, render metadata, audit
scope, regressions, reviewer records and the handoff together. For a seal, hash
the actual files only after review, verify those hashes, and preserve the existing
package format. Do not reuse artifact `seal.py`/`publish.py` scripts: they contain
dated paths and manually entered receipts. Sealing preserves evidence; it does
not approve the animation. Record reviewer/user acceptance separately.

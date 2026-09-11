# Carving direction on steering entry — 2026-09-11

## Follow-up: whole-body lean from straight skiing

The user playtested the first clip-selection change below and reported that the
visible bug remained. They clarified that it starts from straight skiing and
affects the whole body / torso lean. The first change was insufficient evidence
that their reported issue was fixed.

The larger remaining error was a coordinate-frame mismatch in the final pose.
The authored torso and pelvis were placed in the terrain-normal support frame.
When steering across a steep fall line, that frame gains outward cross-slope
roll. Even a correctly signed local carving pose then appears to lean outward
until physical bank builds enough to outweigh the terrain tilt. A 35-degree
analytic slope reproduced about 15 degrees of opposite projected torso bank.
Source phase adds smaller sway, but was not the cause of that large motion.

`skier_full_motion.upright_support()` now derives an unbanked frame with the same
forward axis and slope pitch. `skier_visual` supplies it from the interpolated
root timestamp. Composition aligns the connected gliding/carving body before
the shared pelvis and leg fit, using the existing continuous posture weights.
This is frame alignment outside local articulation limits, not an added spine
bend. The physical boots, skis and solver remain authoritative. Airborne action
weights release the correction; one final skeleton writer remains in use.

The standard studio renderer removed initial terrain tilt, concealing this
particular error. Its new optional `--world-up` view exposes the same apparent
bank measured by the regression. The default review camera is unchanged.

### Follow-up evidence

Final frozen revisions: `20260911-carve-entry-before` and
`20260911-carve-entry-final`. Each contains four complete 180-frame sequences
at 60 FPS: hard steering and gradual tucked steering, left and right, on the
35-degree fall line. Input begins at 0.5 seconds; release is at 2.25 seconds.
The source snapshots retain the first change as the follow-up baseline.

- `tests/carve_entry_suite.gd` measures the final torso axis and foot-to-chest
  silhouette in a gravity/heading frame, including two entry phases, hard and
  gradual input, tuck, both directions, and release. It uses full-axis lateral
  angles so deep forward tuck does not make projected roll ill-conditioned.
- The frozen baseline fails 22 of 64 checks. The current candidate passes all
  64. Across its 16 cases, extra opposite whole-body entry is zero, the largest
  opposite torso variation is 0.238 degrees, and the largest per-tick connected
  joint displacement through entry/release is 0.0313 m. A 1-degree allowance
  admits the source's small pre-existing sway; this is not an artistic grade.
- All 720 paired frames have identical physical positions, speed, body roll,
  ski edges/loads/transforms, input and root transforms. Model 28/replay 5 stay
  unchanged. See `artifacts/carve_entry/verification.json` and guarded receipts.
- Anatomy, compact posture, ski attachment and skier motion suites pass on the
  final source (`artifacts/carve_entry/regression-final/results.json`). The
  intermediate `20260911-carve-entry-after` revision exposed a diagnostic loop
  that assumed every procedural joint position had a rotation (toe markers do
  not). Separate dictionary traversals fixed comparison-mode script errors.
  The final recapture matches all 720 complete intermediate frame records
  exactly; its reviewed renders/videos are reused with `render-reuse.json`
  provenance. Failed intermediate receipts remain preserved.
- Author inspection covers all 720 chronological front-view body silhouettes,
  paired entry strips and selected full oblique/front/side triptychs. The paired
  videos decode at 60 FPS and complete at normal and quarter speed without
  browser errors. This establishes the visible reproduction, not controller
  feel or an independent artistic grade.
- The full 720-frame pole/clothing audit retains 10 intersecting tuck frames:
  frames 35–39 in each direction. A full 360-frame baseline tuck audit finds
  exactly the same frame IDs, pole sides, materials and hit counts (along-shaft
  distances vary by at most 2.45 mm after alignment). No new intersecting frame
  was introduced. This is a retained tuck-transition clipping issue, not an
  all-clear mesh audit; both failed audit receipts remain available.
- The existing carving-response suite also passes all 52 checks on final source,
  including counterbank, reversal, taps and release. Together with the new entry
  suite this is 116 focused checks. Live production chase-camera runs add 210
  frames per revision at 1280x720/30 FPS, with identical camera and physical
  records, stable sources and no script errors. Paired entry crops were inspected
  in `artifacts/carve_entry/chase-inspection/`; these use the 35-degree analytic
  snow plane, not a full-mountain or controller-feel acceptance run.

Run the capture and regression through `scripts/run_guarded.ps1`, using new
output folders. For the correct diagnostic view, render the frozen capture with
`tests/pose_reference_render.gd -- --revision=artifacts/pose_review/revisions/REVISION --world-up`.
The paired page is `artifacts/pose_review/comparisons/20260911-carve-entry-final/index.html`.
Human controller/full-mountain acceptance remains separate from these checks.
Restart the game process to load the updated scripts.

## First change: clip selection (insufficient for the reported body lean)

The initial investigation found a wrong-direction carving clip before it corrected
itself. `skier_full_motion.gd` used the signed, load-weighted ski edge response
for both physical bank and the LEFT/RIGHT source-clip choice. A cross-slope bank
or the previous turn can oppose newly applied steering, so the animation could
select the opposite clip for the entire edge transfer.

Active steering now chooses the forward-carve clip side and its yaw cue.
Completed ski response still supplies the blend magnitude and physical bank.
Released steering follows the remaining loaded edge, preserving the release
behavior that the earlier carving review fixed. The existing joint tracker,
limits, support fitting, and final skeleton writer remain in charge. This is a
presentation change; simulation model 28 and replay format 5 are unchanged.

The old response suite asserted agreement with the edge, so it approved this
bug. The older reference capture also selected direction-consistent physical
turns. The new analytic fixtures deliberately retain cross-slope counterbank.
Do not replace their input-direction checks with edge-direction checks.

## Evidence

Before/after revisions are under `artifacts/pose_review/revisions/`:
`20260911-carve-direction-before` and `20260911-carve-direction-after`.
Both contain raw captures, exact source/tool snapshots, all 1,890 rendered
triptychs and nine complete 60 FPS videos. The engine is the selected custom
Godot 4.7.2 DX12 runtime; its hashes are in `artifacts/carve_direction/verification.json`.
The paired page is `artifacts/pose_review/comparisons/20260911-carve-direction/index.html`.

- Expanded `carve_response_suite.gd`: the old code failed four direction checks;
  the fix passes 52 checks, including released steering, flat-edge gating,
  connected-joint continuity, and identical paired simulation/replay states.
- Matched 60 FPS captures: opposite-steering clip selections decreased from
  405 to zero (135 in each mirrored counterbank case, 71 in reversal, 64 in taps).
  Physical positions, speed, body bank, ski transforms, edges and loads match
  exactly across all 1,890 before/after frames.
- The five cases without conflicting steering/bank have identical final bones.
- Anatomy, compact posture, ski attachment and skier motion suites passed.
- Author visual inspection covered all 840 chronological front-view frames in
  the four affected cases, paired oblique/front/side stills, and sampled live
  production chase-camera views. No direction-selection regression was found.
  Fast taps still produce rapid arm counterbalance, bounded by the same tracker.
- Live analytic-slope playtest: 420 captured frames at 1280×720/30 FPS, production
  solver, skier and chase camera, no race session, no crashes or script errors.
  See `artifacts/carve_direction/gameplay-after/`. This is not a full-mountain
  performance or controller-feel acceptance test.

The full final-clothing audit is **not an all-clear**: 1,680 non-tuck frames have
zero intersections, while `tuck_turn` frames 32–36 contain five intersecting
frames. A separate full 210-frame baseline tuck audit returned exactly the same
hit data. Every final bone and pole transform in that case is unchanged. This
existing tuck/pole issue is outside the direction fix, and both failed audit
receipts remain visible. Human skiing acceptance and independent artistic
grading have not been claimed.

Concurrent work later changed `powder_surface.gd`, `snow_response.gd`,
`snow_tracks.gd`, and `speed_effects.gd`. The captures were internally stable and
frozen before those changes. They use analytic planes and do not instantiate
those snow-effects systems; the motion, anatomy, equipment and solver sources
used here still match. Existing unrelated work and historical reviews were
preserved. Overlapping validation timings are not performance evidence.

## Reproduction

Use a new output/revision name. Run these through `scripts/run_guarded.ps1`
outside another guard, keeping the same explicit `GODOT_BIN` for both captures.
The receipts in `artifacts/guarded/carve-direction-*` retain the actual commands
and statuses used here. Concurrent runs used separate outputs and owned process
jobs while another task's audit was active.

```powershell
./scripts/run_guarded.ps1 -FilePath ./godotw.ps1 -Label carve-direction-check -Arguments @('--headless','--script','tests/carve_response_suite.gd')
./scripts/run_guarded.ps1 -FilePath ./godotw.ps1 -Label carve-direction-capture -Arguments @('--headless','--script','tests/carve_direction_capture.gd','--','--output=res://artifacts/pose_review/revisions/NEW-REVISION/capture')
python scripts/pose_review/freeze_sources.py --revision NEW-REVISION
./scripts/pose_review/run_stage.ps1 -Stage Render -Revision NEW-REVISION
./scripts/pose_review/run_stage.ps1 -Stage Audit -Revision NEW-REVISION -Scenarios 'flat_left,flat_right,cross_left,cross_right,cross_mirror_left,cross_mirror_right,reversal,taps,tuck_turn'
./scripts/run_guarded.ps1 -FilePath ./godotw.ps1 -Label carve-direction-playtest -Arguments @('--script','tests/carve_direction_playtest.gd','--','--output=res://artifacts/carve_direction/NEW-PLAYTEST','--scenarios=cross_right,cross_mirror_left,reversal,taps')
```

The analytic plane uses `height = cross_gradient*x - 0.30*z`, with mirrored
cross gradients ±0.22. Starts are 25 m/s, 0.5 seconds of settling, followed by
held ±0.55 steering, reversal, or alternating ±0.8 taps every 0.1 seconds.
No mountain cache or generator is used by these focused fixtures.

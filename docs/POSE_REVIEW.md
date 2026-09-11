# Skier pose review

This local review preserves reference sheets, exact rendered skeletons and
independent reviewer feedback. R1 reviews seven sheets and 21 poses. The R2
follow-up covers the three downhill sequences requested by the user; its
implementation is described in [Downhill pose correction](DOWNHILL_POSE_REVIEW_R2.md).
The review page itself never changes gameplay or Workshop poses.

Run `./scripts/open_pose_review.ps1` from the project to reopen the latest review.
It serves only on `127.0.0.1:8769`. The generated `review/index.html` also works as a
local file, but browser storage behavior for file URLs varies. Export feedback JSON
before closing or switching browsers. The page reports unavailable storage and can
still export in-memory feedback.

## Revision 20260909-r2

Location: `artifacts/pose_review/revisions/20260909-r2/`. The three requested
downhill sequences have 552 captured frames, nine graded cards, three 60 FPS
videos and 119 frozen source inputs (physics/model 25). The new implementing
reviewer's overall grades are 8.0–8.5, minimum scored body region 6.5, and motion
grades 8.0. These are separate from the supplied r1 user feedback; all 192 user
fields start blank. Hidden neck appearance remains unjudgeable.

Preparation frame 66 retains its partial airborne-match label and links to
frame 65, the last supported pose. The full chronology and source/fitting
diagnostics remain available. Wider pole spread and early hand gathering are
explicit residual differences. See [implementation and validation](DOWNHILL_POSE_REVIEW_R2.md).

## Revision 20260909-r1

Location: `artifacts/pose_review/revisions/20260909-r1/`.

- `capture/manifest.json`: capture time, Godot identity, physics 23, replay-compatible
  source snapshot, default seed 849205174 / mountain v14, terrain fingerprints,
  60 FPS capture / 120 Hz simulation, scenario controls, verified skeleton and hashes.
- `capture/*.json`: 1,092 exact final skeleton frames across six scenarios, including
  production blended requests, clip clocks/weights/mirroring/seam contributions,
  physical state, equipment transforms and events. Preparation and takeoff share
  the same jump trace. No race session or record-writing path is instantiated.
- `baseline/`: copies of all 117 hashed source inputs, including the original rig
  and motion resource. These preserve the reviewed baseline despite concurrent work.
- `frames/` and `render.json`: corrected three-view rephotography of the captured
  bones. The first raw capture's camera framing is retained under `capture/` but is
  not used on the review page. Final reconstruction error is under 0.000001 m.
- `diagnosis/`: dominant source, blended request and final articulation. Dominant
  source samples omit other contributors/history; their equipment is illustrative.
- `assessment-source.json`: authored reviewer judgments. `review/evidence.json`
  expands every pose to 20 body regions with controlling/coupled bones and notes.
- `review/`: page, images, six 60 FPS MP4 videos, read-only Codex assessment and
  independent blank user scores. Half-point scores, Unjudgeable and blank are distinct.
- `sealed.json`: freezes the revision after validation. The packager refuses to
  overwrite a sealed revision. Capture refuses an existing manifest.

Current shared-workspace rig, physics source and tuning changed after the capture.
They are not graded by r1. `current-source-differences.json` records the observed
differences; the capture harness also changed to reject accidental overwrites.
Any newer source requires a new capture/review revision, retaining this folder.

## Matching and interpretation

Frames are zero-based. A frame is captured after two completed simulation steps:
frame 0 = tick 2 = 0.016667 s. MP4 time starts at 0, so video time is frame / 60 while
simulation time is (frame + 1) / 60. Event-relative time uses exact simulation ticks.

The jump happens at tick 133; contact in the standalone landing at tick 34.
Turn peaks use maximum absolute physical bank within the same turn. Negative
steering is travel-left; positive steering is travel-right. Skeleton left/right
always means anatomical side, verified against projected bone markers. The oblique
camera sees the right arm nearest. The spine hierarchy is Hips → Spine02 → Spine01
→ Spine → neck → Head, despite the non-obvious naming order.

Camera yaw follows the skier; fixed initial slope alignment makes the studio view
comparable while retaining bank, changes in slope, flight pitch and equipment.
Reference projection and body proportions are unknown. A fixed 1.6× uniform image
magnification around pixel (400,710) is used for every close gameplay panel. No pose
is independently stretched, mirrored, or normalized by its height. Full frames and
videos retain wide equipment framing. Reference panel crops retain original panel
boundaries, including any pole/ski clipped or crossing a boundary in the AI sheet.

Two cards are partial matches: pre-jump panel 3 and takeoff panel 2 depict apparent
ground support, while corresponding extension in the same recorded jump is already
airborne. These get conditional visible-fit grades and explicit timing caveats.
Both carving sheets show the same screen-bank direction; do not reverse correct
gameplay turning to imitate that ambiguity. Neck articulation is obscured throughout;
separate lower/middle spine articulation in carving is also Unjudgeable.

Overall scores are holistic, never an average of regional scores. Motion grades are
separate moderate-confidence judgments from rendered chronological evidence. The
untimed drawings cannot establish exact duration, 3D angles, limb lengths or impact
severity. The moderate landing fixture does not justify globally deeper absorption.
Fine fingers and hidden wrist twist are excluded from visible hand-placement grades.

## Feedback format

`feedback.schema.json` and `evidence.schema.json` document data-only version 1.
Feedback uses the exact capture `evidenceId` and stable pose/region keys:

```json
{"status":"scored","score":6.5,"comment":"Pelvis should be farther forward."}
```

Unrated and Unjudgeable both have `score: null`, distinguished by `status`.
Zero is a real score. User records never replace Codex evidence. A numeric difference
of at least two points is highlighted without averaging. Import validates all keys,
half-points, format, reviewer and capture identity before changing any user state.
It keeps a browser backup before a valid import. Invalid imports leave feedback intact.
Different captures have separate storage keys; old exports must be opened with the
corresponding old revision. An export includes all 448 independent user records.

## Reproduce and extend

Use a fresh revision directory for each capture. Preserve the current source snapshot
before any concurrent edits. Run guarded Godot workloads sequentially; do not close
the user's editor or bypass an active workload lock.

1. Run `tests/pose_reference_capture.gd --probe` against a fresh temporary output to
   validate event/contact fixtures. Then run rendered capture with
   `--output=res://artifacts/pose_review/revisions/NEW_REVISION/capture`.
2. Copy every manifest source into that revision's baseline and verify every hash.
   Run `tests/pose_reference_render.gd --revision=res://artifacts/pose_review/revisions/NEW_REVISION`
   with that same rig/source available. The renderer rejects a changed rig.
3. Select chronological frames from events, visually inspect final poses and surrounding
   motion, and author new assessments. `author_assessment_r1.py` reconstructs only the
   original r1 judgments; it must never be used to grade a new capture automatically.
4. Run the renderer with `--diagnostic` after creating `selection.json`, then
   `scripts/pose_review/build_review.py --revision NEW_REVISION --video` with the
   bundled Python (Pillow and NumPy). The builder checks scores, ordering and assets.
5. Validate, write `sealed.json`, then update `artifacts/pose_review/latest.json` to
   the new relative page path. Leave earlier revision folders intact.

The selector currently contains r1 fixture/frame choices; adapt it from the new trace.
The packager's event anchors are also r1-specific until the next capture is reviewed.
Do not silently carry those anchors or grades into different inputs.

## Verification and acceptance

See each revision's `ACCEPTANCE.md`, package/browser validation and guarded logs.
State tests cover score semantics, half-points, roundtrip, reviewer separation and
revision separation. Browser tests use an isolated Edge profile and verify all 21
cards, 20 regions each, three cameras, bone markers, six videos, playback rates,
local save/reload, JSON export/import, storage failure and invalid import behavior.

Headless motion/anatomy/attachment checks are structural evidence, not reference-fit
or human skiing acceptance. Physics/runtime suites are required if future work changes
shared runtime instrumentation; this implementation changes only offline capture,
rendering, packaging and review tools. Human scores and animation-feel acceptance are
the next step. Optional read/navigation WebMCP hooks are feature-detected; no native
WebMCP context was available in the validation browser, so that integration is unverified.

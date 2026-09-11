# Cascadeur evaluation source — 2026-09-10 R4

**Evaluation blockout, not approved production animation.** No game asset loader
references this folder. The two-second stationary ready/compression/recovery
sequence uses the actual 24-bone skier with rigid boots, bindings, skis and poles.
The user rejected R4 for collapsing shoulders and shoulder/elbow wobble. These
files preserve that rejected source; stable segment lengths missed near-180°
torso/neck twist. Use the later R5 evidence when evaluating the correction.
See [the evaluation](../../../docs/CASCADEUR_TRIAL_EVALUATION.md) for the decision
and known limitations. Cascadeur 2026.2.2.0.16638 was used.

## Editable files

- `ready_compression_blockout.casc`: six authored beats, frames 0/12/24/30/44/60
  at 30 FPS. Edit this version for timing and pose changes. Its between-key foot
  drift is about 6.26 mm; it is not the contact-validated delivery.
- `ready_compression_baked.casc`: each of the 61 export samples solved through
  the rig with fixed foot/toe targets. This is the scene behind the R4 review.
- `ready_compression_baked_animation.glb`: animation only, 24 joints, 61 samples,
  83,956 bytes. Retain the game's original skinned mesh and materials.
- `sequence_intents.json`, `contact_bake_inputs.json`, `equipment_specs.json`:
  authoring targets and attachment inputs. Cascadeur coordinates are centimetres;
  GLB audits use metres. Targets are not solver-owned contacts or physical COM.
- `manifest.json`: SHA-256 identity of the preserved source and numerical reports.

Do not use the earlier failed QRT templates to regenerate this rig. The verified
rig assigns stomach to `Spine02`, chest to `Spine01`, and neck to `neck` using
explicit ObjectIds. The normal template-generation route reverted the stomach
assignment to `Spine` in this test. The exact installed-builder recipe and
checks are recorded in the evaluation documentation.

## Re-export procedure

1. Open the saved `ready_compression_baked.casc` in Cascadeur. It may show the
   reproduced orange/black material corruption. The exported joint transforms
   survived reopening; preserve the original Godot materials.
2. Run `export_animation.py` inside Cascadeur's Python `run_script` context.
   It checks the scene filename and all 24 joint names, then exports Joint objects
   plus Armature at 30 FPS with a 0.01 scale. It writes a new
   `ready_compression_baked_reexport.glb` beside the scene and refuses overwrite.
   The local MCP endpoint in the trial was `http://127.0.0.1:8765/mcp`; inspect
   current app/server state before use. This script is not a standalone CPython
   program and does not enable the server.
3. Compare numeric transforms, hierarchy, anatomy and contacts after any edit or
   re-export. GLB byte hashes can change after reopen even when poses match.
   This bake's all-frame foot drift was below 0.001 mm and maximum segment-length
   variation below 0.055 mm. Those results apply only to the preserved source.
4. Recreate a new Godot review revision after edits. R4 used `present_authored`
   and the shared final writer in an isolated preview. Gameplay composition,
   anatomical fitting, moving-slope contacts and adjacent actions remain untested.

Do not repair exported joint transforms to hide a failing source rig. Re-bake
through the control rig after changing the six-beat source. Standard foot interval
fixation was rejected because it introduced about 4.68 mm of shin stretching.

The complete trial scripts and exact MCP request/response receipts remain in
`artifacts/cascadeur_rig_20260910_r4/`; they include rejected experiments and
hard-coded historical paths. They are diagnostic history, not a batch runner.
The frozen review is `artifacts/pose_review/revisions/cascadeur-20260910-r4/`.

A separate post-reopen 2 cm pelvis edit verified that controls remain editable:
feet stayed unchanged and maximum segment change was 0.0969 mm. That operation
saved successfully despite a server idle-event timeout. Inspect app state and
output receipts before retrying a timed-out edit. The probe is separate from
these preserved sources; the original review bake was restored afterward.

No purchase or workflow adoption is implied. This source is for evaluation;
the trial's applicable release/commercial terms were not assessed by these tests.

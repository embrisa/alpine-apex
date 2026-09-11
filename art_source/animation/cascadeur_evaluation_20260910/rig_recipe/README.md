# Verified rig construction evidence

`build_request_response.json` preserves the exact successful MCP request and
generated joint/role checks. `finalize_request_response.json` preserves the
separate rig-mode exit and resulting spine controller chain. These are recorded
recipes, not commands to run blindly; their embedded paths point to the original
trial. Adapt paths and assert the active scene before any future reconstruction.

`template_input.qrigcasc` is input to the **explicit-ObjectId Biped builder**.
Using it through the normal QRT generation route alone did not work in the trial:
that route reverted stomach to `Spine`. A correct-looking JSON template is not
proof of a correct generated rig.

Create the 61-frame timeline before generating controls. Use the actual
24-bone source and verify the body hierarchy, role ObjectIds, generated
TechnicalLinks and spline controls before posing. The intended torso controls
are `Hips_MainPoint`, `Spine02_MainPoint`, `Spine01_MainPoint`, `neck_MainPoint`,
and `Head_MainPoint`; `Spine` remains in the original joint chain.

This is a verified recipe for the tested Cascadeur build and this skier, not an
engine-independent rig generator. Editing the preserved .casc needs no re-rig.

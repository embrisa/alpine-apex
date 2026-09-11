# Cascadeur R5 — shoulder and elbow correction

Correction candidate for the user's rejection of R4's collapsed shoulders and
wobbling shoulder/elbow regions. **Isolated authored preview; user acceptance
pending.** No production assets or game pose logic reference this folder.

Open `ready_compression_r5.casc` in Cascadeur 2026.2.2.0.16638. It contains the
actual skier and equipment, all control helpers, and 61 solved samples over two
seconds at 30 FPS. The original six-beat timing and intended foot contacts are
retained. R5 explicitly constrains torso orientation helpers, the clavicles and
shoulder positions, elbow bend planes, and forearm orientation helpers.

The prior source contained nearly 180 degrees of upper-spine/neck twist. Stable
joint lengths did not prevent the resulting skin collapse. R5 changes the
Cascadeur controls and solves the rig; it does not patch exported bone positions,
change skin weights or override the game's final skeleton writer.

`ready_compression_r5_animation.glb` is the animation-only export (24 joints,
61 samples, 83,956 bytes). Retain the original game mesh and materials. Run the
tested `export_animation.py` in Cascadeur's `run_script` context to re-export
this saved scene into a new `ready_compression_r5_reexport.glb`; it verifies the
24 joint names and refuses overwrite. It is not a standalone Python program.

`control_targets.json` records every source control target in centimetres.
`build_control_targets.py` and `solve_oriented_controls.py` are exact tested
recipes from the trial; they retain historical project/artifact paths. Read and
adapt them before reuse. `explicit_rest.json` and `contact_bake_inputs.json`
preserve their inputs here, so future work need not depend on disposable files.
The first recipe uses rest-calibrated torso frames and a reachable two-segment
elbow construction; the second solves all changed controls through Cascadeur.
There is no alternate runtime pose writer.

See [the current evaluation](../../../docs/CASCADEUR_TRIAL_EVALUATION.md) and
the `cascadeur-20260910-r5` frozen review for actual rendered and audit results.
The R4 source remains preserved separately with the user's rejection. R5 is
not an artistic acceptance grade, a gameplay integration or an adoption decision.

Known authoring reliability limits from R4 still apply: native materials can show
orange/black corruption after reopening, and an MCP idle-event timeout can occur
even after a mutation saves. Inspect app state before retrying. Native video
export through MCP remains excluded. These tests do not assess licensing for a
released asset.

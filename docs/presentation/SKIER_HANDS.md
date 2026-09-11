# Connected skier gloves

The original glove surface used four nearly circular finger tubes and separate
palm/thumb pieces. Their exposed ends read as additional fingers. The replacement
uses one continuous glove shell per hand, with four rounded fingers, one thumb,
a fitted cuff and an interior passage aligned to the existing pole handle.

The source was generated from the retained reference using explicit Meshy 7,
Ultra, 2K PBR textures and GLB output. One job consumed **35 of 500 authorized
credits**, with the account changing from 3,760 to 3,725. No rigging or animation
jobs were submitted. The built-in imagegen reference and exact prompt, raw GLB,
source textures, task ID and ledger are in `art_source/meshy/hands_v1/`.

The runtime pair has **5,644 triangles**, replacing 3,272. Both hands share one
glove material and three embedded 2K texture images. The full body is now 38,272
triangles. Hand vertices retain the
existing Hand bones; the cuff blends into ForeArm weights. The 24-bone rig,
animation library, pole transforms, physics, input and replay remain unchanged.

## Local preparation and preservation

`scripts/art/prepare_skier_hands.py` welds the Ultra source before simplification,
fits and mirrors the glove, bakes the Ultra surface detail into a new 2K UV atlas, and creates a staged skier. The reduced source cache
is checked against the raw GLB hash. All rebuild steps are local and spend no
credits. Use a separate background Blender process through `scripts/run_guarded.ps1`.

`scripts/art/glove_graft.py` changes only the `SkierV7Gloves` primitive and its
material. All original body accessors and their bytes, node transforms, skin
and inverse bind data, and non-glove materials are preserved exactly. The
original runtime GLB, editable assembly and old preparation script are retained
under `art_source/meshy/hands_v1/baseline/`. The editable assembly retains its
separate boots.

From the repository root, rebuild the staged hand-only files with:

```powershell
./scripts/run_guarded.ps1 -FilePath 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe' -Arguments @('--background','--factory-startup','--python-exit-code','1','--python','scripts/art/prepare_skier_hands.py') -Label hands_local_rebuild -TimeoutSeconds 600
```

Review `runtime_qa.json` and the staged model before installation. Run
`python scripts/art/install_skier_hands.py` under the same validation guard,
followed by a Godot editor import. Installation checks the current runtime and
editable hashes against the last installation record before replacing them.
The original baseline files are never overwritten.

The full skier rebuild also uses the new local glove template through
`scripts/art/skier_gloves.py`; it cannot accidentally recreate the old tubes.
The template is `art_source/blender/skier_glove_v1.blend`. Hand-only preparation
produces `skier_staged.glb` and `skier_staged.blend` in the source directory;
installation must check the baseline hash before replacing the active files.

The contact lining has a softened tangent normal bake where the tight palm
concavity caused crossed projection rays. The mask is baked away, preserving
outer stitching without extra runtime attributes, textures or shader operations.

## Acceptance evidence

Asset validation checks connected topology, closed boundaries, manifold edges,
the triangle limit, normalized hand/cuff skin weights, embedded textures and
independent GLB reimport. The graft checks exact preservation outside the gloves.

`tests/skier_hands_playtest.gd` uses the production skier, simulation and equipment
on an explicit fixture, without a session or personal-best writes. It captures
both hands in glide, tuck, left/right turns, jump, Safety/Mute grabs, landing and
Jolt crash poses. Pass `--hand-label=final` after the quoted `--` separator. For
matched originals, add `--hands-baseline --hand-label=before`; the test swaps only
the glove surface in memory and leaves the installed asset untouched. Captures,
the interactive `comparison.html` gallery and reports are under
`artifacts/hands_v1/`.

`scripts/benchmark_skier_hands.ps1`, run through the guard, measures both glove
variants on the same current production course at 3840 x 2160 High, 75% FSR2 and
a 120 FPS cap. It checks source hashes throughout the pair. The test reconstructs
both meshes with the same full-detail surface path so all non-glove surfaces are
identical. The baseline variant retains the loaded replacement resource in the
test process; its memory reading is not a clean estimate of old asset residency.
An earlier timing sample was superseded because concurrent physics code changed.

Automated, rendered, performance and user skiing acceptance are recorded
separately in the delivery report. Static fingers still cannot open around a ski
for a grab; existing animation and joint-limit behavior are retained.


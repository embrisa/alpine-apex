# Scenery variation

## PC alpine environment (2026-09-07)

The active spruce, fir and pine families now each have three Blender-authored silhouettes. Six angular rocks replace runtime rock selections: two fractured buttresses, two layered ledges and two broken boulders. Original sources and legacy exports below remain archived. The showcase uses coherent conifer palettes in its existing stands and leaves the open glades and physical obstacle list intact.

Each tree has one surface, explicit near/mid geometry and an eight-view, albedo-only directional impostor atlas. Vertex masks separate bark, fine needles, needle clusters and snow deposits. Analytic cutouts match between Blender atlas baking and runtime; near needles remain individual geometry. Crowns use bounded wind and 20 m opaque LOD dithering; region MultiMesh batching remains. High uses 95/280 m tree transitions and matching mid-detail shadow proxies to 160 m. Exact shared batch bounds avoid submitting invisible detailed LODs; the far shader crops empty atlas sides without changing silhouettes. High uses 4K scanned snow/rock/bark, with 2K and 1K surface derivatives on Balanced/Low. Atlases have 4096x512 and 2048x256 derivatives, mipmaps and VRAM compression.

Editable source: `art_source/blender/pc_environment/pc_environment.blend`. Rebuild with `blender --background --python-exit-code 1 --python scripts/art/build_pc_environment.py`, then import with Godot, run `python scripts/art/configure_imports.py --pc-only`, and import again. The builder independently reimports all 33 GLBs and records triangles, dimensions in Blender XYZ, material surfaces and SHA-256 in `art_source/pc_environment_manifest.json`; runtime GLBs use Y up. The shared runtime manifest includes them too.

Trees are 10.5 m tall before placement scale, with a 0.44 m base trunk fitted to the existing approximately 0.46 m collision radius. Branches remain visual; the existing 11 m cylindrical collision approximation is unchanged. Rock meshes stay within the original 1.35 m radius / 2 m height envelope and include a buried skirt. The terrain stays authoritative for contacts, tracks, surveys and crash geometry.

Texture sources and hashes are in `art_source/pc_texture_sources.json`: Poly Haven snow_02, rock_face_03 and bark_brown_02, CC0. The PC Meshy ledger is separate: `art_source/pc_environment_credit_ledger.json`. This increment spent **0 / 1500 authorized credits**; no generation batches or purchases were needed. The optional [snowy spruce source pack](https://superhivemarket.com/products/low-poly-snowy-spruce-tree-pack) remains a potential time-saving source, not an acquired dependency.

## Archived scenery library


The visual library contains **43 tree shapes across 11 families** and **26 rock shapes across seven families**. Each consumes the original obstacle position, yaw and scale. Trees range from about 6.8 to 17.3 m in visible height; rock diameters reach approximately 2.2–8.9 m. Crown width, crown height distribution, branch twist, fracture shape and stone proportions distinguish the authored derivatives.

| Tree family | Shapes | Visual role |
|---|---:|---|
| Spruce | 3 | Original dense evergreen crowns |
| Silver fir | 4 | Snowy layered spires |
| Stone pine | 4 | Open, rounded snowy boughs |
| Larch | 4 | Sparse russet branch clusters |
| Silver birch | 4 | White bark and a bare spreading crown |
| Rowan | 4 | Fine bare branches with sparse reddish clusters |
| Scots pine | 4 | Orange bark and a high green crown |
| Windswept pine | 4 | Asymmetric wind-shaped branches |
| Broken snag | 4 | Splintered crown and torn limbs |
| Split snag | 4 | Two broken spars and an exposed central split |
| Hollow snag | 4 | Weathered trunk with a decayed opening |

These are game-art families inspired by the named species, not botanical specimens. Larch retains russet clusters; it is not a fully needle-free winter specimen. The three snag families are standing dead trees. Short stumps and fallen logs would need their own collision envelopes before they can replace these tall obstacles.

Granite, layered schist (`slate` asset IDs), limestone, gneiss, split boulders and jagged outcrops each have four geometry variants. Two rounded erratics complete the rock pool. All rocks use the existing shared triplanar rock/snow material. The visual bounds remain 1.35 m radius / 2 m above the anchor before obstacle scaling; a buried skirt hides small slope seams.

## Placement and rendering

`scripts/world/alpine_scenery.gd` uses cosmetic `SCENERY_VERSION = 3`, a separate RNG and broad shoulder/stand preferences. It leaves the solver's obstacle list and random stream untouched. One derivative per family per 128 m region reduces batch fragmentation; different regions expose the full shape pool over a descent. Low/Balanced/High retain the existing visibility distances and do not alter placement or collision.

The new trees use 6–14k triangles near and 1.8–5k mid, with one shared PBR material per family. Each derivative has a matching albedo-only, two-triangle far card. Shared 2K/1K texture sets follow graphics quality; wind and light follow the existing presentation clock. Broken trunks do not sway. Raw Meshy meshes never enter the runtime scene.

The existing 11 m cylindrical tree collision approximation remains, with a 10.5 m visible tree before scaling. Upper branches and roots are visual approximations, as for the original spruce. Large leaning trunks, much shorter broken trees, fallen logs and playable saplings require explicitly versioned collision work. The laboratory bounds and benchmark identity are unchanged.

## Sources and rebuilding

This task spent **420 of the authorized 1,000 Meshy credits**: sixteen geometry previews at 20 credits and ten 2K PBR refinements at 10. The six generated rock sources reuse the existing rock textures. Task IDs, prompts, costs and account-balance reconciliation are in `art_source/meshy/scenery_credit_ledger.json`, separate from the previous graphics upgrade's ledger.

Raw GLBs/textures and raw/reduced Blender QA renders are under `art_source/meshy/scenery/`. Editable normalized families are `art_source/blender/<family>_family.blend`; rounded erratics are `round_boulders.blend`. `scenery_models_qa.json` and `round_boulders_qa.json` record independent GLB reimport checks. Generated ground discs are removed before trunk fitting. All runtime geometry, dimensions and material bindings are rechecked after export.

Rebuilds use existing local sources and spend no Meshy credits:

```sh
blender --background --python scripts/art/build_round_boulders.py
blender --background --python scripts/art/prepare_scenery_models.py
./godotw --headless --editor --import
python3 scripts/art/configure_imports.py
./godotw --headless --editor --import
./godotw --headless --script tests/graphics_suite.gd
./godotw --script tests/scenery_gallery.gd
./godotw --script tests/scenery_playtest.gd -- --scenery-label=after
```

Pass family names after `--` to rebuild a subset, e.g. `-- birch rowan`. Subset rebuilds merge export metadata into the existing QA and runtime manifests. Run builders sequentially because they update shared manifests.

The gallery checks representative near, mid and far silhouettes, several complete four-variant groups, and every rock family. The playtest checks all three graphics settings at two positions and first-person motion at racing speed. It stays unranked. Static timing samples exclude warm-up and captures; they are local rendered-frame measurements, not a complete course benchmark or a device certification. Captures and measurements live in `artifacts/scenery_variation/`.

## Measured validation, 2026-09-05

All 45 physics, 72 runtime and 15 graphics checks pass. All 146 new runtime GLBs round-trip, and the 168-entry runtime manifest matches the exported file hashes. Nineteen final native captures cover the gallery and downhill views. The source identity audit confirms the solver, terrain/contact, input and session files are unchanged.

At 1440×900 on the M4, the matched static Low/Balanced/High views all remain around 8.33 ms at the display's 120 FPS cap. Balanced draw calls rise from 421 to 602; total scenery batches rise from 1,197 to 2,165. The cap conceals GPU headroom, so these samples do not establish equal rendering cost.

A complete screenshot-free Balanced/Legacy/Clear descent at **2560×1440** finishes without crashing in 55.703 simulation seconds, reaching 144.06 km/h. It measures **79.5 average FPS**, **54.2 FPS slowest-1% mean**, 625.6 mean draw calls and about 725 MiB reported peak video memory. World construction takes 1.18 s. The then-current 1440p/120 FPS target was unmet on this machine; the larger library adds rendering work. This historical Balanced run predates the [current PC policy](GRAPHICS.md#performance-policy) and does not establish PC or Low performance. The report is `artifacts/weather_benchmark_scenery_expanded_1440p.json`; the combined evidence is `artifacts/scenery_variation/validation.json`.

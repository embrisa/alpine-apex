# Asset sources and rebuilding

## Locations and provenance

`assets/` contains runtime resources; `art_source/` contains editable originals,
masters, generation receipts and reference images. Preserve binary bytes, UIDs
and import settings when moving/rebuilding. Runtime manifests record actual
hashes, bounds, counts and source IDs; this guide routes to them instead of
duplicating their catalogs. Generated QA/captures belong in `artifacts/`.

| Material | Source / receipt | Runtime |
|---|---|---|
| Skier | `art_source/meshy/skier_v7/`, `art_source/blender/skier_v7.blend` | `assets/graphics/models/skier_v7.glb` and separate boots |
| Hands | `art_source/meshy/hands_v1/`, local glove preparation | Incorporated into the weighted skier; fixed fingers remain |
| Equipment | `art_source/meshy/equipment_v1/`, packed `art_source/blender/equipment_v1_*.blend` | Detailed mirrored skis, v2 bindings, poles |
| Motion | `art_source/animation/steep_full_curves/manifest.json`, retained source exports | `assets/animation/steep_ski_motion.res` |
| Trees | Local purchased TreeDesigner source, packed Blender derivatives | `assets/graphics/trees/manifest.json` |
| Minerals | `art_source/blender/rock_generator.blend`, `art_source/blender/minerals_v3/` | `assets/graphics/minerals_v3/manifest.json`, geology runtime catalog |
| Flavor | `art_source/flavor_v1/` | `assets/graphics/flavor_v1/manifest.json` |
| Background | Explicit wilderness bake and receipts | `assets/graphics/scenery/alpine_valleys_01.res` |
| Photos/logo | Retained originals, prepared photo manifest, editable SVGs | `assets/images/prepared/`, `assets/images/branding/` |
| Audio | `art_source/audio/` source/credit/cut manifests | `assets/audio/`; [Audio](AUDIO.md#source-audio-and-provenance) |
| Pose/reference images | `art_source/references/`, including `skier_pose_reference_sheets/` | Authoring only; excluded from exports |

Purchased `TreeDesigner + 400 trees/` stays local and backed up separately;
do not distribute its generator. Vendor/license notices and generation ledgers
remain with their sources. A documented old budget/balance is not a new spend
authorization or a live account balance. Local rebuild scripts do not require
new paid generation.

## Skier and animation sources

The Meshy-7 Ultra body was prepared in Blender with packed textures and a
24-joint skin. Body, boots and equipment remain distinct assets. Hand-only
replacement preserves the surrounding rig/material and needs actual wrist seam,
clothing and grip inspection; it did not solve every strap/pole issue.

Full body rebuild: Blender `--background --python scripts/art/prepare_skier_v7.py`,
then guarded Godot editor import. `scripts/art/skier_gloves.py` uses the retained
`art_source/blender/skier_glove_v1.blend` template.

For hand-only work, resolve `$blender` to the installed executable, then:

```powershell
./scripts/run_guarded.ps1 -FilePath $blender -Arguments @('--background','--factory-startup','--python-exit-code','1','--python','scripts/art/prepare_skier_hands.py') -Label hands-rebuild -TimeoutSeconds 600
```

Inspect staged `runtime_qa.json` and meshes before guarded
`python scripts/art/install_skier_hands.py`, then editor import. Preparation welds,
fits/mirrors and bakes the source; `glove_graft.py` replaces only the glove
primitive/material, preserving body accessors, skin, transforms and other
materials. Installation verifies current runtime/editable hashes against the
last receipt; `art_source/meshy/hands_v1/baseline/` remains intact. Tight palm
concavities required softened baked tangent normals to avoid crossed-ray seams.

Rebuild equipment with `scripts/art/prepare_equipment_v1.py` and
`prepare_binding_v2.py` in Blender, then import and run
`tests/equipment_asset_suite.gd`. `equipment_gallery.gd` and
`equipment_playtest.gd` provide native views. Each export is one mesh with baked
transforms and self-contained PBR maps; extracted Mesh resources discard scene
correction transforms. [Animation](ANIMATION.md#connected-anatomy-and-equipment)
owns coordinate, fit and attachment constraints.

Meshy reference images, exact prompts/task IDs, raw GLBs/maps and credit ledgers
are retained. The three equipment requests used explicit `meshy-7`, Ultra/PBR,
4K and GLB, costing 105 of the authorized 1,000 credits at that checkpoint.
Use the ledger for subsequent decisions; no automatic regeneration is implied.

`scripts/art/export_ski_motion.gd` produces the compressed animation resource
with source/target hashes and mapping provenance. The curve manifest owns
source timebase/names/rest calibration. Procedural profile sources remain under
`art_source/animation/apex_ski_v17/`, rebuilt by `build_ski_motion.py`.
Retain original data; new retargeting must establish both position and rotation
agreement. Production constraints and historical rejected fits live in Animation.

To rebuild the recovered curves, `$decoder` must point to the existing local
decoder/native inventory. Its recorded installation was
`C:/Users/hp/Documents/Codex/Reports/Steep-Animations-2026-09-08/decoder`; verify
availability before starting. Resolve `$blender` as above:

```powershell
python scripts/art/recover_ski_motion.py --decoder $decoder
./scripts/run_guarded.ps1 -FilePath $blender -Arguments @('--background','--factory-startup','--python','scripts/art/retarget_ski_research.py','--','--source','artifacts/steep_motion_gameplay/exports/Steep_ID01_Female_Core_Motion.glb','--out','artifacts/steep_motion_gameplay/retarget','--skip-sheet') -Label motion-retarget
./scripts/run_guarded.ps1 -FilePath ./godotw.ps1 -Arguments @('--headless','--script','scripts/art/export_ski_motion.gd') -Label motion-export
```

`tests/steep_motion_suite.gd` checks the export; `scripts/test_steep_motion_final.ps1`
checks repeat export/focused regressions. `scripts/measure_steep_motion.ps1`
captures the native A/B (`-Timing` for screenshot-free timing); invoke these
parameterized scripts through the native-pwsh guard pattern in Validation.

Cascadeur R5/R6/R7/R8/R9 source directories retain their own editable files,
exports and source receipts. Their short source READMEs describe asset-local
commands; the canonical experiment status is [Animation](ANIMATION.md#retained-findings-and-acceptance).
Existing authoring/sealing scripts are historical tools, not proof of current
acceptance; do not rewrite sealed manifests to pretend later source hashes match.
Timestamped handoff hash maps retain their historical paths; current source
READMEs and producer scripts carry the relocated paths.

## Trees

The collection has 24 variants: four each spruce, fir, pine, winter birch,
dead snag and broken crown. Revision 3 rebuilds twelve living conifers with
curved branch sprays, needle textures, richer greens and moderate upper snow;
bare/dead/broken geometry retains its established variants. Source manifests
own seeds, masks, physics proxies and export hashes. Tree population, placement
and collision are [World](WORLD.md) contracts, separate from art revisions.

GLBs carry UVs, vertex masks and twelve branch tags in one surface. Godot applies
foliage textures to alpha-.7 vertices; wood/snow retain their masks. A GLB
placeholder is not a portable recreation of the Godot shader. Other engines need
the corresponding cutout material/textures. Shared textures/materials stay
resident through serial scene post-import because it can request texture imports.
Wind/contact bend branches cosmetically without changing collision envelopes.

```powershell
./scripts/art/rebuild_foliage.ps1 -BakeNeedles -Resume
./scripts/art/rebuild_foliage.ps1 -Asset forest_spruce_01
./scripts/play_tree_gallery.ps1
```

The rebuild runner serializes authoring, packing, import and Blender roundtrip.
Resume verifies source/authoring identity and export hashes. Gallery keys 1–6
select families, A all, L near/mid/far, S snow, W wind and Space branch response;
comparison display height is normalized while labels retain actual metres.
`tests/density_lod_suite.gd` and `tests/foliage_playtest.gd` validate the runtime.

Retained pitfalls: fracture the actual clipped broken-stem boundary rather than
attaching a crown stub; prune whole twig tubes instead of arbitrary faces;
deduplicate attachment sites; use forked birch sources rather than dense conifer
presets. Near/mid/far visual review and texture memory are separate from tree
counts, synthetic capacity and full-descent performance.

## Minerals

The immutable supplied generator is now
[`art_source/blender/rock_generator.blend`](../art_source/blender/rock_generator.blend).
`scripts/art/build_mineral_library.py`, `build_mineral_detail.py`,
`rebuild_mineral_detail_library.py` and `package_mineral_detail_sources.py`
reference that location. The v3 catalog has 120 base assets in five categories;
variant dimensions/triangle/texture budgets and hashes live in its manifest.

Detailed source evaluation pins original local Position into a mesh attribute
before composition so procedural material does not smear when parts rotate.
Simplify the completed render mesh; bake unique albedo, tangent normals and
roughness with packed UVs. Exclude the generator's broad display pedestal from
composition (repetition made artificial fins). Sedimentary bodies can intersect;
render shells are not watertight collision meshes. Physics proxy preparation is
separate in [World](WORLD.md#geology-and-collision).

Base GLBs are bare, portable PBR. Optional moss/moss_grass scenes share meshes;
`optional_moss_material` can override surface 0 without mutating shared bare
material. No vegetation on glacier ice. Existing grass is static crossed cards
on nearby small/medium/large stones, not the pending wind/skier-reactive terrain
grass system. Godot adds metre-scale object-space mineral detail and snow treatment.

```powershell
./scripts/art/prepare_mineral_review.ps1 -Validate -Capture
./godotw.ps1 --path artifacts/minerals_v3/qa_project res://scenes/art/mineral_gallery.tscn
```

The isolated review avoids unrelated purchased Blender-source imports, uses
actual GLBs/import scripts and preserves other import products/UID cache.
Gallery 1–5 selects category, M moss, drag/wheel orbit/zoom; labels show real
metres despite normalized display sizes. Existing `--legacy` is a comparison.

In a resolved Blender executable, run `--background --factory-startup
--disable-autoexec --python-exit-code 1 --python
scripts/art/rebuild_mineral_detail_library.py`. After `'--'`, `--asset
mineral_medium_sedimentary_01` rebuilds one asset and its detailed bake working
file. `package_mineral_detail_sources.py` independently reimports and packs five
editable Asset Browser libraries. Resume trusts only matching manifest hashes;
deliberate single-asset rebuild avoids silently retaining stale geometry.

## Flavor and equipment

The twelve flavor assets include authored timber start/finish gates, Meshy-7
refuge/marmot, and Poly Haven gnome/sign/armchair/table/fire-pit/radio/crate/duck.
`assets/graphics/flavor_v1/manifest.json` and source records retain URLs/licenses,
raw models and derivative hashes. The refuge door is closed; no playable interior
is implied. Small prop collision uses conservative boxes. Gates use separate
solid feet/posts/overhead pieces around an open timing plane.

Use `scripts/play_flavor_gallery.ps1` for source/runtime presentation and
`scripts/play_flavor_gate_course.ps1` for the unranked gate fixture. Normal
placement is sparse/seeded and consumes the shared collision adapter, not gallery
transforms or old default-mountain placement counts.

Local rebuild order: `python scripts/art/fetch_flavor_sources.py`, Blender
`--background --factory-startup --disable-autoexec --python-exit-code 1 --python
scripts/art/build_flavor_library.py`, then three sequential
`python scripts/art/configure_flavor_library.py` / Godot editor-import pairs.
Those passes establish import remaps and material overrides. Use the validation
guard for engine/Blender stages. Retained raw Meshy GLBs are required; this
pipeline makes no new paid-generation requests. Check `tests/flavor_asset_suite.gd`
and the gallery/course after rebuilding.

## Branding and loading art

Editable master: `assets/images/branding/alpine_apex.svg`. The active title/loading
variant is `alpine_apex_ice.svg`; `alpine_apex_compact.svg` serves smaller headers.
Light/dark/mark variants and root `icon.svg` use the same named SVG geometry.
Custom letters/counters have no font dependency. Preserve the summit/chevron
negative space, aspect ratio and 2:1 angular family. Use full/compact/mark at
approximately ≥400/≥225/smaller logical pixels, with half-cap-height clear space.

`prepare_logo.py` and `prepare_logo_texture.py` rebuild derivatives. Preserve
transparent vector geometry; earlier image cleanup attempts produced painted
checkerboards rather than alpha and were rejected. Original PNG/shader remain
sources, not the active logo. The approved ice finish is a derivative, not a
reason to raster-replace the geometry master.

`prepare_interface_art.py` packages nine original photographs byte-for-byte,
including supported `.jpg` names for JPEG-in-JFIF originals; the prepared manifest
records source paths/sizes/hashes. Runtime uses lossless mipmapped imports and
`alpine_photo.gdshader`, with per-image framing/trim in `alpine_art.gd`.
Wide p1/p6/p7/p8 fill; the other five retain the entire photo in a frame over
a subdued enlargement. Output at 4K is not a claim of 4K source detail.

Retain originals and source provenance. Photographs/animated photographic light
are loading-only; live menus use the world. Loading holds one image at a time,
uses its private selection state, preserves progress/tips/audio across photo
changes and releases art afterward. No full-screen photo shader runs while skiing.
Behavior/accessibility belongs in [Presentation](PRESENTATION.md#loading-and-feedback).

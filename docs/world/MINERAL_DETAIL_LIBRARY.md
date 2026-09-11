# Mineral detail library v3

This rebuild addresses the surface-detail loss in the first mineral pack. The
default is **bare rock**, with optional moss scenes and separate moss-and-grass
scenes. The previous `assets/graphics/minerals` exports remain available for
comparison. The supplied `rock_generator.blend` is never overwritten.

## Assets and scale

The deliverable is `assets/graphics/minerals_v3`: 24 distinct base GLBs in each
of five categories. Sizes are the longest bounding-box dimension in metres.
All exports use a bottom-centred origin, Y up in Godot, and identity scale.

| Category | Longest dimensions | Near triangle ceiling | Normal bake |
|---|---|---:|---:|
| Small | 0.35, 0.60, 0.90, 1.20 m | 6,000 | 2K |
| Medium | 2.0, 3.2, 4.8, 6.5 m | 18,000 | 4K |
| Large | 10, 16, 24, 36 m | 45,000 | 4K |
| Huge boulders | 40, 55, 75, 100 m | 90,000 | 4K |
| Cliffs | 60, 100, 150, 220 m | 120,000 | 4K |

Small, medium and large include rounded, fractured, sedimentary, outcrop, cliff
and glacier families. Huge boulders include erratic, block, split, dome, overhang
and monolith profiles. Cliffs include wall, layered wall, corner, recess,
overhang wall and buttress profiles. Each family has four seeds and sizes.
The manifest records actual XYZ bounds, rather than assuming every size is a
width or height.

## Detail correction

The original conversion lowered the generator subdivision to 3, simplified each
part to 2,600 triangles, applied a voxel union and smoothing, and reused 1K maps
without baking the discarded geometry or layered source material. Those choices
removed the reference's fine strata and rounded its edges.

V3 keeps the source rock body's geometric deformation at subdivision 5 during
composition. It preserves source coordinates in a mesh attribute so that fitting
and rotating a part does not smear the original procedural material. It directly
simplifies the completed render mesh and bakes albedo, tangent-space normals and
roughness from the detailed source. Tightly packed UVs avoid wasting most of the
texture on padding. Small assets use 1K albedo; the other categories use 2K.
Roughness is 1K throughout.

The wide display pedestal from the supplied generator is excluded from individual
composition parts. Repeating it inside every layer produced artificial fins.
Sedimentary variants use one layered rock body; broader formations compose
overlapping bodies. These are render meshes with intersecting shells, **not
watertight collision meshes**. No terrain, skiing contact, race sessions or
personal bests are changed.

The Godot import script preserves the unique PBR bakes and adds shared 2K mineral
detail in object space at a consistent metre scale. This extra detail matters on
the 40–220 m formations. The portable GLBs contain their own baked PBR maps;
Godot's additional metre-scale grain and moss are implemented by
`rock_surface.gdshader`. Glacier variants use opaque blue ice and upper-face frost.

## Using the library

Drag a base GLB from a category folder into the game scene. Optional variants live
under `moss/<category>` and `moss_grass/<category>` as Godot scenes sharing the
imported mesh and textures. Moss covers selected upper surfaces. Grass uses the
supplied 512px grass texture on static crossed cards; its extra draw surface is
limited to the small, medium and large rock families and disappears at 60 m.
Ice does not receive vegetation.

Moss is also available on each imported rock mesh as the metadata resource
`optional_moss_material`. Applying it as surface override 0 leaves the shared bare
material unchanged. Every base GLB remains bare by default.

The near meshes and texture allocations are larger than v2. Godot generates mesh
LODs, but that does not remove texture memory or establish full-course performance.
The gallery is a visual review, not proof of the game's 4K/90–120 FPS target.
Placement density, streaming and course performance must be measured when these
assets are integrated into a mountain.

## Review and rebuild

```powershell
# Prepare an isolated Godot review without importing unrelated source folders.
./scripts/art/prepare_mineral_review.ps1

# Validate all 120 imports, write vegetation variants, and capture the review.
./scripts/art/prepare_mineral_review.ps1 -Validate -Capture

# Review the complete library after preparation.
./godotw.ps1 --path artifacts/minerals_v3/qa_project res://scenes/art/mineral_gallery.tscn
```

The gallery uses keys 1–5 for categories, M for moss, drag to orbit and the wheel
to zoom. Previews are displayed at a common size; labels give actual metres.
Pass `--legacy` after the quoted `'--'` separator to view the v2 gallery.

The isolated project uses the same engine, D3D12 renderer, actual GLB files and
import scripts. It avoids the unrelated `TreeDesigner + 400 trees` source folder,
whose unset Blender import path prevented a project-wide headless import during
this work. It does not change that folder, the engine configuration or addons.
Preparation copies only v3's completed import products into the main project's
rebuildable cache, so these assets can also load there without importing the
unrelated Blender source. Other import products and the UID cache are preserved.

```powershell
& 'C:\Program Files\Blender Foundation\Blender 5.2\blender.exe' `
  --background --factory-startup --disable-autoexec --python-exit-code 1 `
  --python scripts/art/rebuild_mineral_detail_library.py

# Rebuild one asset and save its detailed bake working file.
& 'C:\Program Files\Blender Foundation\Blender 5.2\blender.exe' `
  --background --factory-startup --disable-autoexec --python-exit-code 1 `
  --python scripts/art/rebuild_mineral_detail_library.py '--' `
  --asset mineral_medium_sedimentary_01

# Independently reimport all GLBs and package five editable Blender libraries.
& 'C:\Program Files\Blender Foundation\Blender 5.2\blender.exe' `
  --background --factory-startup --disable-autoexec --python-exit-code 1 `
  --python scripts/art/package_mineral_detail_sources.py
```

The builder resumes completed files only when their manifest hashes still match.
Delete a specific manifest entry or use `--asset` when deliberately rebuilding
it after a recipe change. The five packed `.blend` libraries are placed in
`art_source/blender/minerals_v3`, laid out at actual metre scale and marked for
Blender's Asset Browser. They contain the game meshes and packed PBR maps.
The one-asset command reconstructs the detailed source for rebaking.

## Validation evidence

`assets/graphics/minerals_v3/manifest.json` records source hashes, seeds, bounds,
source and game triangle counts, texture sizes and export hashes.
`artifacts/minerals_v3/blender_validation.json` records independent GLB round trips.
`artifacts/minerals_v3/godot_validation.json` records scene loading, materials,
normal resolutions, bounds, origins and LODs. Rendered evidence is in the same
folder: `comparison.png`, `bare.png`, `moss.png` and five category sheets.

Automated import checks, visual gallery inspection, course performance and user
skiing acceptance are separate evidence. The supplied source materials and grass
texture retain their original licensing; this workflow uses no paid generation.

## Completed delivery — 2026-09-07

- **120/120** GLBs pass independent Blender reimport and Godot validation in both
  the isolated review and the main project. Godot generates **2–6 additional
  LODs** per asset. All five categories contain 24 assets at the approved sizes.
- **108 moss scenes** and **60 moss/grass scenes** pass scene-loading and shared
  mesh checks. The grass scenes add **100,140 triangles in total** across all 60
  optional variants, with a 60 m draw-distance limit. Base GLBs stay bare.
- Five packed Blender libraries are saved and marked for the Asset Browser.
  The base GLBs total **3.36 GiB**; the higher-detail maps are a substantial
  increase over v2. This is source/export size, not measured resident GPU memory.
- All five categories were rendered and visually inspected at **1400×1800** in
  Godot 4.7.2 D3D12 Forward+ on the RX 9070. The comparison is **2040×1020**, with
  separate **1600×1200** close views. The huge-boulder and cliff captures were
  also run in the main project after scoped cache synchronization.
- The main runtime uses text-path fallback for some newly imported texture UIDs
  that are absent from its existing UID index. Loading and rendered checks pass;
  the isolated review resolves those IDs directly. The user's UID cache and
  unrelated editor/import settings were not replaced.
- The original generator and all 120 v2 GLBs remain byte-identical. The user's
  unsaved Blender session remained open. No assets were placed into active
  mountains, and no course performance or skiing acceptance is claimed.

Final captures and reports are retained in
`art_source/blender/minerals_v3/previews` as well as the working artifacts folder.

[Before/after and optional grass](../../art_source/blender/minerals_v3/previews/comparison_grass.png) ·
[Bare rock close view](../../art_source/blender/minerals_v3/previews/bare.png) ·
[Huge boulders](../../art_source/blender/minerals_v3/previews/huge_boulders.png) ·
[Cliffs](../../art_source/blender/minerals_v3/previews/cliffs.png)

## Mountain integration

The additive [geology v11 integration](GEOLOGY_V11.md) now selects this library across default and random mountains, with fitted terrain, solid collision and compressed runtime derivatives. The original gallery/source delivery above remains preserved.

# Alpine forest: coherent source LOD family

Prepared replacement sources for all 30 IDs in the existing eight-family tree
catalog. This package is excluded from production import by `.gdignore`.
It does not register or replace the live forest. The native review is a concrete
asset and material prototype for evaluating the whole family before installation.

## Representation

- **Near:** original seeded branch architecture, curved intersecting textured
  needle sprays, geometric rounded birch or lobed maple leaves, separate bark
  and irregular snow deposits. Spruce, fir, pine, winter birch, golden birch,
  maple, dead snags and fractured crowns retain distinct recipes and variants.
- **Mid:** the same major branches, cluster anchors and snow locations, with
  reduced branch tubes, two bowed sprays plus two small interior fills per
  conifer cluster, or fewer folded broadleaves. There is
  no whole-tree cone or crossed-tree mesh. `manifest.json` owns actual counts
  and comparison counts from the hashed production catalog.
- **Far:** a two-triangle card with eight azimuth views baked from the exact
  near GLB. Separate object-space normal and canopy-role atlases support
  directional lighting and retain wood/foliage ownership. The isolated shader
  blends adjacent views, reconstructs edge color from coverage, and uses a
  stable 0.35 silhouette cutoff with separate dithering for the LOD overlap.
- **Shadow:** independent derivative, at most 1,400 triangles. Its material
  retains foliage cutouts; it is separate from visible near/mid source geometry.

`geometry.py` is the editable deterministic recipe; `blends/` contains baked
editable meshes for all three visible tiers plus the shadow. `models/` provides
portable self-contained GLBs. `impostors/` contains the eight-view atlas triplets.
Source recipes are original work; the existing needle and bark derivatives and
colorful leaf maps retain their provenance through `manifest.input_hashes`.
The purchased generator is neither required by these recipes nor distributed.

## Material and coordinate contract

Blender uses Z up, GLB uses Y up, in metres. Near/mid have three explicit portable
surfaces: `PremiumTree_Wood`, `PremiumTree_Foliage`, `PremiumTree_Snow`.
RGB vertex colors are linear; alpha is opaque. Conifer foliage uses a core glTF
MASK material, while geometric broadleaf, wood and snow remain opaque. UV0 holds
material coordinates; UV1 carries twelve-group branch tags and inverse pivot
height. The portable far GLB embeds the first view as a MASK texture; the native
review shader uses the full sidecar atlases to select directions dynamically.

Atlas frames are 512 square pixels, eight horizontally. `ortho_scale` and
`center_z` define the shared square card framing. Normals encode Godot object XYZ
as `normal * .5 + .5`; canopy is white for foliage/snow and black for wood.
The bake uses binary-alpha cutouts with transparent black outside the silhouette.
Filtering associates RGB with coverage; `far.gdshader` removes that association
before lighting and normal decoding. Do not RGB-dilate these particular atlases
without changing that sampling contract. The portable first-view texture is
converted to straight RGB during finalization.

The silhouette cutoff avoids a noisy fringe on distant crowns; the thinnest
subpixel needles and twigs can disappear below it. The preview uses mipmapped
images without production BC7 packaging. Atlas and
geometry counts are asset-cost evidence, not GPU frame time or physical VRAM.
Eight azimuths remain an approximation at elevated viewpoints; inspect the
elevation stress capture. A production converter must preserve the one-surface
wood/foliage/snow role mask, branch response, visibility assistance, normalized
grounding, motion bounds and selected LOD distances before runtime acceptance.

## Build and inspect

Run from the repository root with the installed Blender 5.2 and pinned Godot.
The wrapper owns Exclusive admission; do not nest another guard around it.

```powershell
./art_source/trees/premium_lod_v1/prepare.ps1 -Mode Build
./art_source/trees/premium_lod_v1/prepare.ps1 -Mode Bake
./art_source/trees/premium_lod_v1/prepare.ps1 -Mode Review
./art_source/trees/premium_lod_v1/prepare.ps1 -Mode Audit
python art_source/trees/premium_lod_v1/report.py
```

Build refuses to replace existing sources unless `-Replace` is explicit and
their recorded hashes still match. `-Asset forest_spruce_02` selects one source;
`-Sample` selects the three medium conifers for an initial inspection.
`-Resume` retains only matching recipe/output identities. Rebuild all sources
after changing the geometry recipe. Bake seals actual native source/output
hashes, then binds portable far materials and updates the editable source hashes.
Run Review afterward to obtain captures against the sealed final manifest.

Independent Blender inspection and GLB reimport:

```powershell
./scripts/run_guarded.ps1 -FilePath 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe' -Arguments @('--background','--factory-startup','--disable-autoexec','--python-exit-code','1','--python','art_source/trees/premium_lod_v1/audit_blender.py') -Label premium-tree-roundtrip -WorkloadMode Exclusive -TimeoutSeconds 600
```

The native project under `artifacts/premium_tree_review/native_project/` has no
game scene, autoloads, collision, preferences or race state. Review outputs live
under `artifacts/premium_tree_review/native/`; the generated `review.html` gathers
family comparisons, close detail, mixed forest depth, distant slope, elevated
and backlit views, and the two real dense-forest transition bands. Near/mid/far
use crown-surface distances of 12/64 m with a ±5 m complementary dither overlap.
The review uses a 60 FPS cap and individual instances. No gameplay FPS claim is
made from that scene. Production timing requires a separately installed,
identity-matched, capture-free forest comparison under FpsCritical admission.

Runtime conversion, production wind/contact response, visibility assistance,
residency, whole-mountain lighting/performance and human skiing acceptance remain
separate from the source preparation and rendered review delivered here.

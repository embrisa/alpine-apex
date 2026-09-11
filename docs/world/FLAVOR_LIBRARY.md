# Mountain curiosities, version 1

Twelve reusable assets extend the existing library: two structural timber gates,
a small alpine refuge, a carved marmot monument, a garden gnome, a wet-floor
sign, a Victorian armchair, a picnic table, a stone fire pit, an expedition
radio, a supply crate and an oversized rubber duck.

The library is integrated into normal v10 mountains and custom races. The default
mountain contains 12 discovery sites with 16 props, and **Mountain Sprint** in
**Create / Shared Races** lets you try the collidable start and finish arches
immediately. See [the integration guide](FLAVOR_INTEGRATION.md) for placement,
race compatibility and full-mountain verification. The hut is an exterior
landmark with a closed door; its interior is not playable. Small props use
conservative box obstacles.

## Asset catalog

| Asset | Suggested placement | Source |
| --- | --- | --- |
| Start gate | Green timber arch at a prepared start pad | Authored in Blender |
| Finish gate | Red timber arch with matching proportions | Authored in Blender |
| Little alpine refuge | Rare sheltered ledge or finish-side shelter | Image reference → Meshy 7 |
| Marmot of the summit | Carved mascot on a secluded viewpoint | Image reference → Meshy 7 |
| Summit guardian | A small gnome watching an improbable ridge | [Poly Haven garden gnome](https://polyhaven.com/a/garden_gnome) |
| Caution: mountain | Wet-floor sign beside a vast snow slope | [Poly Haven wet-floor sign](https://polyhaven.com/a/WetFloorSign_01) |
| The best seat | A lone armchair overlooking a dramatic drop | [Poly Haven armchair](https://polyhaven.com/a/ArmChair_01) |
| Lookout picnic table | An occasional rest spot near the refuge | [Poly Haven picnic table](https://polyhaven.com/a/wooden_picnic_table) |
| Expedition fire pit | A deserted camp; bury the lower rim slightly | [Poly Haven fire pit](https://polyhaven.com/a/stone_fire_pit) |
| Lost expedition radio | On a crate in a tiny abandoned camp | [Poly Haven radio](https://polyhaven.com/a/vintage_radio_transceiver) |
| Buried supplies | Partly buried alongside a shelter or route | [Poly Haven crate](https://polyhaven.com/a/wooden_crate_01) |
| The powder duck | An oversized yellow duck on an unlikely perch | [Poly Haven rubber duck](https://polyhaven.com/a/rubber_duck_toy) |

The table gives additional authoring ideas. Normal mountains use the sparse,
seeded placement rules described in the integration guide.

## Browse and ski

```powershell
./scripts/play_flavor_gallery.ps1
./scripts/play_flavor_gate_course.ps1
```

The gallery has a clickable asset list, orbit/zoom, Left/Right navigation,
L for near/mid/far detail and S for the added snow treatment. The custom hut,
marmot and gates include authored snow in their base appearance, so S does not
remove that baked or modeled snow. All dimensions shown are actual metres.

The second scene is an unranked 4 m terrain fixture using the production skier,
input router and independent 120 Hz ski simulation. Ski through the green START
and red FINISH gates. A/D steer, W tucks, S brakes, Space prepares/releases a
hop, R restarts, C changes camera, P pauses, and Esc closes. It creates no
RunSession, personal best, race, mountain recipe or saved player preferences.

## Use in Godot and Blender

- Drag a scene from `assets/graphics/flavor_v1/scenes/` into an authored scene.
  These scenes include PBR/snow materials, automatic distance detail and solid
  Godot/Jolt collision. The bare GLBs contain portable base materials and geometry.
- Open `art_source/blender/flavor_v1/flavor_collection.blend` for the complete
  collection. Its objects are marked for Blender's Asset Browser with catalogs
  for gates, structures, camp and discoveries. Individual editable `.blend`
  sources have packed textures; the user's already-open Blender is untouched.
- `assets/graphics/flavor_v1/manifest.json` records dimensions, exact collider
  boxes, triangle counts, source, license, export SHA-256 and round-trip results.
  Origins are bottom-centered, runtime axes are Y up and scale is baked.

### Ski collision contract

The ski solver does not use Godot physics nodes during normal skiing. The
library therefore provides a `PropCollisionSurface` adapter in
`scripts/world/prop_collision_surface.gd`. It delegates terrain sampling,
support normals and loose-snow depth unchanged, then selects the earliest
contact from terrain obstacles and the registered oriented prop boxes.

```gdscript
var skiing_surface = preload("res://scripts/world/prop_collision_surface.gd").new(terrain)
var gate = preload("res://assets/graphics/flavor_v1/scenes/start_gate.tscn").instantiate()
add_child(gate)
gate.position = placement
gate.bind_surface(skiing_surface)
# Normal gameplay uses world.ski_surface; standalone scenes can use this adapter:
sim.step(1.0 / 120.0, intent, skiing_surface)
```

Call `gate.sync_collision()` explicitly after changing the bound prop's transform.
Removal unregisters its solver collision. Godot colliders track the scene transform
normally. All LODs use the same collisions. Do not wrap the surface recursively.

The adapter uses the existing rider height of 1.6 m and a conservative 0.7 m-wide
upright box. Slab sweeps prevent tunneling; rotated/tilted box expansion remains
conservative. Contacts report world-space position, normal and within-step
fraction to the unchanged impact/resolution code. Static bodies use layers 1
and 4 (bitmask 9), including the production ragdoll's collision layer contract.

Both gates have a **10 m nominal clear width and 4.5 m overhead clearance on a
level pad**. The two feet, two posts, crossbeam and roof each have separate box
shapes. No convex hull or trigger fills the opening. Terrain slope and uneven
ground can reduce clearance, so place the feet on a suitable pad and check it.
Overhead parts stop an airborne rider; supports spend impact reserve through
the standard impact model. The gate names do not themselves start/finish a race.

Normal gameplay now binds these props through `world.ski_surface`. Layout version
1 and race schema 3 separate the new collidable environment and gate timing from
earlier custom races. The laboratory's original obstacle layout remains intact.

## Source and budgets

Eight props and the gate timber maps are Poly Haven CC0 sources. Attribution,
download URLs, published MD5 verification and local SHA-256 are retained in
`art_source/flavor_v1/polyhaven_sources.json` and `gate_material_source.json`.
See [Poly Haven's license](https://polyhaven.com/license).

The refuge and marmot use built-in image generation references followed by
Meshy 7 image-to-3D, with 2K PBR textures and GLB output. The two jobs consumed
30 credits each, **60 total**, against the bounded 60-credit plan. Exact task IDs,
settings and account balance checks are in `art_source/flavor_v1/credit_ledger.json`;
the prompts and references are alongside it. Generated models are identified
separately from CC0 assets; the applicable Meshy account terms govern those outputs.
No keys or signed download URLs are retained in the source ledger.

Each asset has near, mid and far GLBs. Near detail is bounded to 24k triangles;
the gates are about 7k triangles each. Automatic transitions are 45 and 120 m,
with a 450 m draw limit. These distances suit sparse authored discoveries, not
a dense prop population. Identical external textures are reused across distance
levels; mipmaps and VRAM compression are enabled on those shared textures.
The portable GLBs retain embedded textures for independent reuse.
Geometric seam duplicates are welded before distance simplification; UV seams
remain in face-corner data. Far detail is intended for distances beyond 120 m
and loses small fittings and fine texture alignment when inspected close up.

## Rebuild and verification

Run generation and imports sequentially. Fetching is free; rebuilding never
calls Meshy or spends credits. It requires the retained generated raw GLBs.

```powershell
python scripts/art/fetch_flavor_sources.py
& 'C:\Program Files\Blender Foundation\Blender 5.2\blender.exe' --background --factory-startup --disable-autoexec --python-exit-code 1 --python scripts/art/build_flavor_library.py
python scripts/art/configure_flavor_library.py
./godotw.ps1 --headless --editor --import
python scripts/art/configure_flavor_library.py
./godotw.ps1 --headless --editor --import
python scripts/art/configure_flavor_library.py
./godotw.ps1 --headless --editor --import
./godotw.ps1 --headless --script tests/flavor_asset_suite.gd
./godotw.ps1 --headless --script tests/physics_suite.gd
./godotw.ps1 --headless --script tests/runtime_suite.gd
./scripts/play_flavor_gallery.ps1 '--' --capture
./scripts/play_flavor_gate_course.ps1 '--' --capture
```

Reports and captures live under `artifacts/flavor_v1/`. The asset suite checks
all export hashes/triangle counts, binding lifecycle, clear passages in both
directions, edge clearance, support/overhead impacts, rotated placements, Jolt
rays and real-solver passage at initial speeds of 0, 108 and 216 km/h.

Automated checks, rendered inspection, hardware frame-time performance and the
user's physical-control/skiing acceptance are separate. Gallery/course screenshots
do not establish the full mountain's 4K 90–120 FPS target. The source assets do not
change the terrain or ski solver. Race integration and its separate record
identities are covered in the integration guide.

### Library-only verification on 7 September 2026

- Blender 5.2.1: all 36 GLBs reimported independently with matching triangle
  counts and packed textures. The collection contains 12 editable source assets.
- Godot 4.7.2: **188/188** library/collision checks passed, including all export
  hashes and all imported material references using the shared texture paths.
- Existing regression suites: **56/56 physics**, **93/93 runtime** passed.
- Rendered on the RX 9070 using D3D12 Forward+ at **1600 × 1000**: inspected
  near and far previews of all 12 assets plus rear views of both gates and both
  generated models. The course used the real skier at 120 Hz and crossed both
  gates without a crash; it creates no record session. Captures are under
  `artifacts/flavor_v1/gallery/` and `artifacts/flavor_v1/course/`.
- Full-mountain 4K frame-time/memory benchmarking and user-controlled skiing
  acceptance have not been performed for this library increment.

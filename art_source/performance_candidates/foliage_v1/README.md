# Foliage v1: isolated low-cost source candidates

This is a **source-only comparison pack**. `.gdignore` keeps it out of Godot's
production import scan. Nothing here changes the current grass or plant libraries,
loader, placement, shader, terrain, collision, graphics settings, weather clock,
skier influence or 120 Hz simulation. The 4 m terrain heightfield remains the only
terrain authority. The existing vegetation-only placement and terrain seating
rules would have to be preserved by any later experiment.

The editable `foliage_candidates.blend` contains four original vegetation
silhouettes in green and lightly dusted finishes at three geometry levels.
The four green LOD0 specimens are visible in a spaced gallery; unhide another
finish or LOD in the Outliner to edit its local-root mesh.
`models/` contains 24 independent Y-up GLBs, and `previews/grass.png` and
`previews/plants.png` label each finish and LOD. The preview has **no ground mesh**:
every specimen starts at its local ground pivot. The Blender file contains only
24 mesh objects and one material; camera, light and labels are temporary render
objects and are not saved or exported.

| Shape | Intended form and approximate envelope | LOD0 / LOD1 / LOD2 triangles |
| --- | --- | ---: |
| `alpine_blade` | Short sheltered alpine blades, ~0.20 m wide × 0.25 m high | 108 / 44 / 12 |
| `meadow_tuft` | Broader curved clump for visible snowy edge coverage, ~0.33 m wide × 0.36 m high | 144 / 56 / 16 |
| `alpine_rosette` | Radial broad leaves and a low, clear silhouette, ~0.30 m wide × 0.16 m high | 20 / 14 / 8 |
| `fern_spray` | Upright fronds with paired leaflets, ~0.39 m wide × 0.41 m high | 45 / 21 / 15 |

Each finish has the same geometry and triangle count. LOD0 retains near silhouette
and bend shape; LOD1 reduces whole blades, leaves or fronds; LOD2 preserves a
coarse distant outline. These are **source variants**, with no authored runtime
switch distances or density changes. Compare actual coverage and transitions at
the existing 18–26 m grass blend before considering substitution. The present
production grass has 288–396 triangles for green LOD1 and 80–110 for green LOD2;
fewer triangles here do not imply equivalent coverage, appearance or frame time.

## Material and motion-source policy

- One shared `FoliageVertexOpaque` PBR material slot per mesh; opaque,
  double-sided geometry. Each GLB has one opaque primitive, zero alpha-tested or
  transparent surfaces, and zero external/embedded texture dependencies.
- `COLOR_0` carries green and limited white snow on selected tips or upper leaves.
  Dusted assets retain visible green bases. Snow is vertex color on vegetation,
  with no separate snow card or mineral geometry; no alpha mask or microtexture.
- UV0.y increases from root toward tip for possible reuse of existing weather-wind
  and swept-skier deformation intent. Root pivots are at ground level, vertices
  stay above that plane, and the broad LOD silhouettes keep similar envelopes.
  This data does not implement motion, alter the 1.25-second recovery boundary or
  feed any gameplay state. A future import must verify vertex colors are enabled.
- Grass, rosette and fern shapes have **no rocks, pebbles, gravel, terrain chunks,
  pedestals, supports, or collision**. No flora is attached to a mineral mesh.

`manifest.json` records every GLB's triangle count, one material slot, opaque and
alpha-tested surface counts, texture dependencies, bounds, bytes and SHA-256,
plus the editable source and preview hashes. `build.py` is the full deterministic
mesh recipe. These are newly authored procedural polygons informed by the current
Alpine Apex vegetation brief and terrain-grass source contract; no vendor model,
scan, previous foliage mesh, rock-generator mesh or texture was copied. Blender
5.2.1 exported the GLBs. The builder refuses an existing pack unless given
`--rebuild`, and then checks prior output hashes before replacement.

`meadow_tuft` in both finishes is the **one candidate suitable for later
measurement** because its broader opaque silhouette is the most plausible
coverage-preserving grass comparison at 144/56/16 triangles. Suitability means
only that the source is worth testing. The existing grass result was small and
noisy, with no established tail improvement, and the plant path has no isolated
plant-only control. An integration decision would need matched visual ground
coverage, LOD/snow stability and current-source measured evidence; this pack
makes no FPS or skiing-acceptance claim.

## Rebuild and audit

Run from the repository root. Blender generation, preview and roundtrip import
must acquire `artifacts/validation.lock` through the guard; do not nest guards.

```powershell
./scripts/run_guarded.ps1 -FilePath 'C:\Program Files\Blender Foundation\Blender 5.2\blender.exe' -Arguments @('--background','--factory-startup','--python-exit-code','1','--python','art_source/performance_candidates/foliage_v1/build.py','--','--rebuild') -Label foliage-candidate-build -WorkloadMode Exclusive -TimeoutSeconds 600
python art_source/performance_candidates/foliage_v1/audit.py
./scripts/run_guarded.ps1 -FilePath 'C:\Program Files\Blender Foundation\Blender 5.2\blender.exe' -Arguments @('--background','--factory-startup','art_source/performance_candidates/foliage_v1/foliage_candidates.blend','--python-exit-code','1','--python','art_source/performance_candidates/foliage_v1/audit_blender.py') -Label foliage-candidate-audit -WorkloadMode Exclusive -TimeoutSeconds 300
```

The structural audit checks GLB hierarchy, attributes, index triangle counts,
opaque double-sided material, zero textures and absence of animation, skin or
camera data. The Blender audit checks the editable source and reimports all 24
GLBs. The labelled previews are isolated art renders, not gameplay screenshots,
benchmarks or human/controller acceptance.

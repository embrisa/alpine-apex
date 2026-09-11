# Detailed skis, bindings and poles

The active equipment uses three separate Meshy 7 source models, fitted and
optimized in Blender. The skier body, boots, skeleton, ski contacts, input,
120 Hz solver and replay identity retain their existing behavior.

| Runtime model | Triangles per item | Copies |
| --- | ---: | ---: |
| `assets/graphics/models/ski_detailed_v1.glb` (right) | 6,000 | 1 |
| `assets/graphics/models/ski_detailed_v1_left.glb` (mirrored left) | 6,000 | 1 |
| `assets/graphics/models/binding_detailed_v2.glb` | 11,548 | 2 |
| `assets/graphics/models/pole_detailed_v1.glb` | 6,000 | 2 |

The pair totals 47,096 equipment triangles, replacing 992. Left and right skis
have distinct mirrored meshes and share the same material/texture resources.
Bindings and poles share both geometry and materials. Each asset retains albedo, normal and
metallic/roughness textures at 2K; Godot generates automatic mesh LODs.
The original `ski.glb`, `binding.glb` and `pole.glb` remain available for comparison.

## Design and attachment

The dark graphite, lime and orange design continues the original equipment
palette. The ski has a rounded shovel, steel edges, sidewalls, graphics and wear.
The binding has separate toe and heel mechanisms, screws and springs. Its toe
and heel mounting faces sit directly on the ski, with no riser. Poles have a straight carbon shaft,
molded grip, wrist strap, basket, ferrule and tip.

Each export contains one mesh with baked transforms. Godot extracts the Mesh
resource directly, so a scene-level corrective rotation would be lost. GLB uses
metres, Y up and +Z forward. Ski fore/aft extent remains -1.02 to +1.15 m relative
to its existing origin. Its base is -0.016 m; the shovel curve is presentation
geometry beyond the unchanged 1.8 m physical support. Binding and boot offsets
are `(0, 0, -.15)` and `(0, .017, -.15)`, defined in `skier_equipment.gd`.
See [the binding correction](BOOT_POSTURE_CORRECTION.md) for the matching visual
body lowering and original-source preservation. The pole grip stays at the origin,
with its shaft extending down Y and its tip near -1.18 m.

The left ski is a baked X reflection of the right ski, with its UVs kept attached
to the reflected vertices. This mirrors the color pattern into a matching pair.
The ski Node transforms, boot and binding handedness remain untouched. Creating
this derivative required no additional image generation or Meshy credits.

Generated open/thin surfaces require two-sided rendering. `EquipmentV1` materials
use `equipment_lit.gdshader`; the ordinary textured shader retains back-face
culling. Both use the same unchanged lighting/PBR shader body. This avoids
discarded patches on the ski topsheet, shafts and straps while preserving cloud
lighting. Equipment stays attached during crashes. Straps and binding mechanisms
are static geometry; this update adds no release or cloth simulation.

## Source and spending

The built-in image generator created one isolated reference per asset. References,
the exact prompt set, requests, task IDs and credit ledger are retained in
`art_source/meshy/equipment_v1/`. All three requests explicitly used `meshy-7`,
Ultra, PBR, 4K textures and GLB output. Each cost 35 credits: **105 / 1,000 used,
895 authorized credits unused**. Account balance reconciled from 3,925 to 3,820.

Raw GLBs and original texture maps remain under that directory's `raw/` folder.
The raw meshes contain 1,300,340 ski, 3,075,936 binding and 818,778 pole triangles.
The four `art_source/blender/equipment_v1_*.blend` files are editable, packed
sources. `runtime_qa.json` records exported hashes, bounds, counts and independent
GLB reimport checks. Rebuilding locally makes no network or paid generation calls.

```powershell
& 'C:\Program Files\Blender Foundation\Blender 5.2\blender.exe' --factory-startup --background --python scripts/art/prepare_equipment_v1.py
& 'C:\Program Files\Blender Foundation\Blender 5.2\blender.exe' --factory-startup --background --python-exit-code 1 --python scripts/art/prepare_binding_v2.py
./godotw.ps1 --headless --editor --import
./godotw.ps1 --headless --script tests/equipment_asset_suite.gd
./godotw.ps1 --script tests/equipment_gallery.gd
./godotw.ps1 --script tests/equipment_playtest.gd '--' --test-lab --graphics-quality=high --terrain-gi=off
./godotw.ps1 --script tests/equipment_playtest.gd '--' --test-lab --graphics-quality=high --terrain-gi=off --timing
```

## Acceptance evidence

- Automated: physics 56/56, runtime 93/93, equipment assets 29/29, ski attachment
  20/20, skier motion 19/19, rider lifecycle 17/17 and native graphics 29/29 pass.
  Attachment error remains below 0.5 mm, matching the original equipment baseline.
  Mirrored ski UV landmarks and shared runtime material references are checked.
- Rendered: isolated native asset views plus matched before/after close-ups,
  chase, first person, carve, hop and a controlled physical crash handoff are in
  `artifacts/equipment_v1/`. All gameplay harness runs are unranked. Snow can
  obscure portions of the skis through the existing burial/terrain behavior;
  the isolated gallery and airborne view check the complete mesh silhouette.
- Performance: `artifacts/equipment_v1/visual/performance_reverse.json` records the
  final mirrored set's bounded 4K High comparison, including asset hashes, actual
  pixels, p95/p99, CPU/GPU render times and
  engine memory. This is a laboratory equipment comparison, not a complete
  mountain benchmark. Existing applications remain running, and cached baseline
  and detailed assets both contribute to the recorded memory counters.
- User skiing: physical input, preferred visual appearance and a full mountain
  playtest remain unverified by the user.

Pre-existing forest resource UID warnings resolve through their stored file
paths during the native harnesses; they are retained in the logs.

### 4K measurements on RX 9070

Actual output was 3840x2160, High, FSR2 at 75% / 2880x1620 internal, 120 FPS cap,
SDFGI off. Each case measured 720 frames after 240 warmup frames without captures.
The first comparison predates the mirrored left ski. The final comparison uses
the mirrored pair, reverses the order (`--reverse-equipment-order`), and is saved
with the four runtime asset hashes as `performance_reverse.json`.

| Pass / equipment | Mean FPS | Frame p95 / p99, ms | Mean CPU render / GPU, ms |
| --- | ---: | ---: | ---: |
| First / original | 76.3 | 19.710 / 24.074 | 1.814 / 8.113 |
| First / detailed | 71.7 | 23.431 / 27.251 | 1.373 / 8.803 |
| Final reverse / detailed mirrored pair | 89.8 | 12.825 / 16.352 | 1.337 / 8.207 |
| Final reverse / original | 118.7 | 8.391 / 9.564 | 1.393 / 6.768 |

Both sets miss the project target in the first pass. In the final comparison,
the original meets the mean/p95/p99 targets, while the detailed set averages just
below 90 FPS and misses the 11.1 ms p95 budget; its p99 stays within 16.7 ms.
The final detailed set's worst frame is 26.809 ms. These measurements do not
establish performance acceptance for the new equipment or a full mountain run.
Two other Godot game instances were present after the first pass; none were
stopped for this work. Variable system load and sequential cases limit causal
attribution, so an isolated full-mountain comparison remains necessary before
claiming the performance target is met. Peak reported engine video memory was
about 2.53 GiB and engine static memory about 256 MiB.

# Mountain discoveries and race arches

The 12-asset [flavor library](FLAVOR_LIBRARY.md) now participates in normal
gameplay. Open **Create / Shared Races**, select **Mountain Sprint**, and press
**Race it** to try the new start and finish gates on the default mountain.
Use **Free ski current mountain** to explore the discoveries.

## What appears

The default mountain, seed **849205174 / v10**, contains **12 discovery sites
with 16 props**: two refuges, occasional camps and picnic tables, supply crates,
an expedition radio, carved marmots, gnomes, a lone armchair, a wet-floor sign
and one oversized rubber duck. All ten flavor families appear. A brief discovery
message appears when you come within 22 m of a site during free skiing, once per
site per loaded mountain. There is no checklist, reward or steering assistance.

Other v10 seeds use the same deterministic placement rules. Sites are at least
240 m apart, between 350 and 2,580 m from the summit. Footprint height variation,
slope, exposed rock and existing obstacles can reject a placement. Accessories
are attempted beside camps and huts only when their own footing is suitable.
The duck appears at most once and is omitted on seeds divisible by three.
Five tested seeds produced 11–12 sites and 13–16 props each.

Huts sit on stone foundations fitted to the sampled snow. Other props are
slightly buried in the downhill side of their footprint. Small terrain-fitted
snow drifts blend their bases with the existing surface. Hut doors are closed;
interiors are not playable. Discovery objects are solid obstacles, so ski around
them. These are sparse static props; there is no dynamic furniture simulation.

## Race behavior

Start and finish are marked by one broad translucent beam in the centre of each
gate: lime at the start and warm amber at the finish. Each beam rises 800 m with
a 12 m soft halo and a fade over its upper 200 m. Shimmer, rising light flecks,
spiralling ribbons and low swirling mist animate inside it. A snow-fitted halo
rotates around the base. Motion pauses with racing and respects Reduced Motion.
Beam visibility is independent of the arches' 450 m detail cutoff. Terrain occludes
them and ordinary weather fog applies. The same presentation marks laboratory
gates; the exact timing stripe and all physical gate rules remain unchanged.
See [sky-beam implementation and validation](RACE_BEAMS.md).

Both arches have a nominal 10 m opening and 4.5 m overhead clearance. Separate
feet, posts, roof and beam colliders leave the passage open. Uneven terrain gets
short stone foundations beneath the supports. Authoring rejects overly uneven
ground and endpoints too close to obstacles or discoveries.

The start is a stationary spawn under its arch, facing locally downhill. The
120 Hz clock begins with the run. The finish requires crossing the stripe and
arch plane, from either direction, with the rider inside the opening. Passing
beside or above the gate does not finish. Swept intersection provides the exact
fraction of the final simulation tick. Routes remain open between endpoints.

Only the active race binds its two arches to skiing collision. Survey/library
previews have no active collision. Retry replaces the pair cleanly; free skiing
removes it. The built-in Mountain Sprint needs no library save. Other v10 seeds
receive a suggested race if the search finds a suitable endpoint pair; this is
endpoint validation, not a guarantee of difficulty or a route optimizer.

Race schema **3** pins both gate headings, dimensions and **prop layout version
1**. Definitions use `user://races_v3/`, and custom results use
`user://race_records_v3/`. Previous circular-finish races must be recreated;
their files and times remain untouched and are not mixed into new records.
The laboratory benchmark, archived physical terrain and mountain height/tree
fingerprints retain their existing identities. See [RACES.md](RACES.md).

## Runtime boundaries

- `world/flavor_layout.gd` produces data without changing terrain or existing
  obstacle arrays. The default placement fingerprint is
  `fcebf326396120a3e19daa9fddae172381abb9156ff41b3f110396d447a6341d`.
- `world/mountain_flavor.gd` instantiates the reusable scenes, foundations and
  contact snow and tracks local discovery announcements.
- `world/prop_collision_surface.gd` delegates support queries to the same 4 m
  heightfield. A 48 m spatial index limits swept oriented-box tests to nearby
  solids. The independent ski solver receives frozen geometry, not Nodes.
- The same boxes form Godot static bodies for crash ragdolls. Graphics quality
  changes detail distances only: Low 25/75 m, Balanced 35/100 m, High 45/120 m,
  with a 450 m prop draw limit. Collider registration survives all LOD changes.
- Prop materials participate in the existing cloud/daylight registry; removal
  unregisters them. The snow-contact helper and existing rock textures are
  reused. This integration spends no additional Meshy credits.

## Verification

Godot 4.7.2 headless checks passed: **188 asset/collision**, **62 integration**,
**56 physics**, **113 runtime**, **50 race**, **64 competitive/ghost**, and
**27 summit-return** checks. The seed tests cover 0, 42, 13579, 849205174 and
2147483647. The summit-return checks verify fractional finish ordering against
the mountain boundary and ensure that aborted runs cannot overwrite a PB.

`tests/flavor_world_playtest.gd` exercises the actual default main scene with
bounded ordinary steering/tuck input. It completes Mountain Sprint without a
crash in approximately **14.829 s**, checks retry/free-ski collision lifecycle,
and captures every flavor family on the real mountain. It is unranked and
does not save personal bests or display preferences. Captures and the hardware
report live in `artifacts/flavor_integration/world/`.

The hardware measurement uses native **3840 × 2160** output on the RX 9070,
High at 75% FSR2 (**2880 × 1620** internal), with a 120 FPS cap and SDFGI off.
It compares 360 warmed frames of the same static hut view with props visible
and hidden; screenshots are outside the sample interval. The JSON report records
frame p95/p99, viewport GPU/render-CPU time, VRAM and Godot static memory.
The isolated near-hut sample measured **8.376 ms p95 / 8.499 ms p99**, GPU p95
**6.466 ms** and render-CPU p95 **0.913 ms**. The same view with props hidden
measured 8.385 / 8.555 ms and GPU p95 6.382 ms. Both views were effectively
at the 120 FPS cap. Resident rendering memory was **3.74 GiB** and Godot static
memory **464 MiB**; hiding props leaves their resources resident, so this pair
isolates drawing cost rather than asset-loading memory cost.
The isolated report is retained as `world/isolated_performance.json`. This sample
precedes the final change to reuse the exact terrain material on contact snow;
that appearance correction is checked separately in the 1280 × 720 material
preview. A later full-scene review encountered a Jolt job-capacity warning while
moving the crash-collision patch between distant art views. Static art inspection
now disables Jolt after the functional race and does not move that invisible
patch. The completed race checks and isolated sample above come from the earlier
successful full-scene runs; the interrupted review is retained in
`world_review_retry.log`.
This bounded scene comparison does not establish the frame-time target across
every descent, weather setting or camera motion. Automated race passage and
rendered inspection are separate from player-controlled skiing acceptance.

```powershell
./godotw.ps1 --headless --script tests/flavor_integration_suite.gd
./godotw.ps1 --headless --script tests/flavor_asset_suite.gd
./godotw.ps1 --headless --script tests/physics_suite.gd
./godotw.ps1 --headless --script tests/runtime_suite.gd
./godotw.ps1 --headless --script tests/race_suite.gd
./godotw.ps1 --headless --script tests/competitive_suite.gd
./godotw.ps1 --headless --script tests/summit_return_suite.gd
./godotw.ps1 --script tests/flavor_world_playtest.gd
```

Run the native capture/measurement alone, after headless suites finish, to avoid
making the hardware comparison compete with other game instances.

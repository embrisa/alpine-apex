# Player-generated mountains

Choose **Generate / Saved Mountains** on the title, pause, crash or finish menu. New mountains use the full-summit **v4** generator.

1. Enter a seed or choose **Random Mountain**. The survey shows the whole mountain, with north at the top, 50 m contours, slopes and physical obstacles.
2. Name the mountain, then **Save Locally**, **Export File**, or **Ski This Mountain**. Imported `.apexmountain` files reconstruct and save locally; no account or network service is involved.
3. Free skiing starts at the **actual highest point**. **A/D, arrows or the left stick** rotate the chosen heading through 360°. **W, Enter or the right trigger** drops into that face. The summit overview shows the terrain ahead before committing.
4. Explore any side. Reaching the foot of the mountain ends the free-ski descent in every direction; **R** returns to the summit to choose another face. Free skiing has no personal-best comparison or ghost.
5. Pause and open **Create / Shared Races** to place endpoints on any face. Race starts must be on a summit rim or farther downhill, because a stationary rider on the exact high point has no downhill acceleration. Authored races retain their own record and ghost identity.
6. **Copy Seed** includes the version: `Mountain Seed: 849205174 / v4`. Bare numbers select v4. Versions v1, v2 and v3 still reconstruct their original basin terrain; saved files do not change shape after this update. Re-enter a bare number to try its new full mountain.

The example file `examples/mountains/summit-360-v4.apexmountain` reconstructs the current example. The original files remain compatibility fixtures. **Original Test Face** returns to the unchanged laboratory. Loading a mountain preserves graphics, weather, time of day and modified physics settings, including their unranked status.

## Terrain and summit entry

`generated_mountain.gd` implements `alpine-drainage` version 4 as renderer-independent data. A local seeded RNG chooses face pitch, six to eight radial spurs, their bends, relief, treeline and six optional takeoff/drop placements. A rounded summit feeds steep faces on **all azimuths**. The spurs widen into ridges; the hollows between them form broad bowls. Integrated radial pitch changes provide rolls and compressions before a gentler foot. Low-amplitude noise supplies detail beneath these macroforms.

The physical surface is **6,144 × 6,144 m**, roughly **37.7 km²**, at the existing **4 m spacing**. The six tested seeds have about **2,001–2,122 m** of summit-to-foot vertical. Trees form lower forest patches, rocks collect near exposed spurs, and takeoffs have clear approach/landing fans. This is one constructed radial mountain family, not erosion simulation, arbitrary terrain editing, overhangs, frozen rivers or infinite streaming.

The exact summit is at (0, 4300, 0). Free-ski staging holds the player there while choosing a heading; it does not advance the clock. Drop-in selects a point 16 m away on the summit rim, less than 4 m below the high point, with zero velocity. This is a visible session setup action, not a movement force. From that point the unchanged ski solver handles gravity, contact, steering, braking, jumps and landings. There is no racing-line attractor or speed cap. The player is free to change direction during the descent.

Free-ski progress is radial, and the foot is reached at a 2,850 m radius. Timed custom races use their authored finish instead. Collision bounds, survey panning, zoom, snow picking and endpoint validation use the whole field. The rectangular surface continues beyond the free-ski foot, so the base is reached before the world boundary on every side.

## Rendering and generation cost

The authoritative float32 grid contains **2,362,369 vertices** and **4,718,592 base triangles**, drawn in **576 chunks**. Ski contact, snow tracks, physical obstacles, endpoint picking and crash collision use this same surface. The built-in mesh renderer remains the sole terrain path.

For v4, distant chunks can select coarser 16 m / 32 m interior index buffers through [Godot's ArrayMesh LOD support](https://docs.godotengine.org/en/stable/classes/class_arraymesh.html#class-arraymesh-method-add-surface-from-arrays). Every 4 m boundary segment remains present at every LOD, closing seams between different detail levels. The base mesh remains intact for exact crash trimeshes. LOD changes presentation only. Old mountains retain their existing renderer geometry.

The adjoining 8.192 km decorative landscape is centred around the summit. Its analytic collar is stitched to the physical edges. Terrain materials receive the actual scenery origin instead of assuming the old basin offset. Scrub distribution covers the lower mountain in every quadrant.

Library generation and reconstruction run on an owned worker thread so controls and the busy state continue rendering. Terrain data, RNG and noise are local to that job; no scene Nodes cross threads. Closing the scene joins an outstanding worker. Preview sampling is bounded independently of physical grid size. World mesh/asset construction still occurs synchronously when loading the mountain. Typical observed example data generation was about 6 s and world construction about 5 s on the development machine; this is not a streaming world.

The current target is 4K output at 90-120 FPS on the Ryzen 5 5600X / RX 9070 PC, separately from the 120 Hz ski solver. Earlier MacBook results below describe the former policy. Measurements must name actual resolution, weather, device and capture overhead. Headless tests do not establish visual feel or hardware performance.

## Compatibility and storage

`mountain_definition.gd` owns schema 1. Compact JSON recipes contain the name, generator/version, physical/scenery seed and version, exact Godot version and SHA-256 fingerprints of heights and explicit binary obstacle fields. Files are typically below 1 KB and capped at 4 KB. Invalid fields, versions and mismatched fingerprints cannot silently load different terrain. Names are metadata, not library paths or terrain identity.

The local library uses `user://mountains_v1/` with reference hashes as filenames. Saves/exports use temporary writes and rename; the same mountain with a new name updates its existing entry. Different generation versions coexist. Import preserves the playable world on failure.

`generators/drainage_v1.gd`, `drainage_v2.gd` and `drainage_v3.gd` retain old physical generation. Existing mountain files, shared race references, benchmark identities and records remain distinct from v4. Exact engine pinning and fingerprints detect reconstruction differences; cross-platform bit-identical generation is not promised. Recipes are not baked, engine-independent terrain snapshots.

## Validation

```sh
./godotw --headless --script tests/summit_mountain_suite.gd
./godotw --headless --script tests/mountain_library_suite.gd
./godotw --headless --script tests/summit_descent_playtest.gd -- --all-faces
./godotw --script tests/summit_view_playtest.gd
./godotw --script tests/summit_descent_playtest.gd -- --heading=0
./godotw --headless --script tests/generated_mountain_suite.gd
./godotw --headless --script tests/physics_suite.gd
./godotw --headless --script tests/runtime_suite.gd
./godotw --headless --script tests/race_suite.gd
./godotw --headless --script tests/jump_suite.gd
```

The summit suite checks the global maximum, exact reconstruction, all quadrants, eight real-solver entries per seed, connected descent to every side, vertical, portable recipes, old versions, arbitrary-direction races, radial progress and seam-preserving LOD indices. Its downhill connectivity graph does not prove every line is safe. The library suite exercises real summit controls, loading, restart, directional completion, remote survey picking, sharing, scene reloads and PB preservation. The older generator and jump suites deliberately retain their v3 fixtures.

The test-only descent pilot uses ordinary steering/tuck and brakes for the lower forests. All eight compass entries on the example reach the base, with peaks around 161–163 km/h and times of 106–118 s. Two fully unbraked attempts hit the same lower-forest tree; high speed does not remove the need to choose a line and brake. The pilot is never a player assist. Six tested seeds support all eight initial directions; this finite sweep does not certify every seed, line, landing or subjective fun.

The final south-entry rendered run finishes in **117.308 s**, reaches **163.50 km/h**, and records **0.68 s airtime**, without a crash. On **Apple M4 / Godot 4.7.2 / Forward+ Metal / Low / 1440×900 actual pixels / snowfall with High weather**, it averages **119.9 FPS**, **8.340 ms mean**, **9.396 / 10.624 ms p95 / p99**, and **82.5 FPS slowest-1% mean**. Timing contains 14,065 frames after 120 warmup frames, with no other game instance or screenshots during measurement; the base screenshot is taken afterward. This supports the approximately 60 FPS Low target for this tested route, device and configuration.

Final checks pass: **56 summit, 37 library, 100 archived-generator, 56 physics, 72 runtime, 51 race, 64 competitive and 6 scenery**, plus the retained jump suite. Native views were inspected for the summit, library preview, full mountain, opposite faces and completed descent. View-capture frame counters include startup work and are not performance measurements. Data generation is deterministic on the tested engine; cross-platform equivalence and every seed/line remain unproven.

Reports, rendered views and timings are under `artifacts/summit_mountain/`. Earlier measurements below are historical and describe their stated generator/model versions.

## Historical v1 measurement — 2026-09-06

The six-seed sweep (`0`, `1`, `42`, `12981`, `849205174`, `2147483647`) passes 83 generator/contract checks. It finds 550–642 m of summit-to-basin vertical, connected downhill branches, and clean 10-second entries with the actual ski solver. Data construction measured 390–424 ms during that suite. This finite sweep does not certify every seed or line.

The rendered eastern route on seed `849205174` finishes in 126.042 s with no crash and 60.70 km/h peak. The test pilot uses only ordinary steering/braking intent, pins a heading-zero entry for repeatable measurement, and keeps records unranked. That original pilot brakes above 58 km/h; its 60.70 km/h peak is not a terrain speed cap. It is test code, never a player steering assist. The optional western pilot attempt hits a rock; the test pilot is not a route planner or a proof that either side is safe at racing speed.

On Apple M4 / Godot 4.7.2 / Forward+ Metal, Low graphics, **1440 × 900 actual pixels**, snowfall with High weather quality, the full eastern descent records **120.0 FPS average**, **8.334 ms mean**, **9.674/10.524 ms p95/p99**, and **85.7 FPS slowest-1% mean**. The first 120 render frames are warmup; no screenshots are taken during measurement. This meets the approximately 60 FPS Low target for this route, speed and configuration. Other seeds, higher racing speeds, resolutions and platforms need direct measurements.

Reproduce the fixed test route with `./godotw --script tests/generated_descent_playtest.gd`; use `--headless` for its physics-only run. `-- --descent-captures` adds screenshots and makes the timing unsuitable for comparison with the screenshot-free report. The report is `artifacts/mountain_generation/descent_native.json`.

## Steeper v2 validation — 2026-09-06

The six-seed sweep finds 1,107–1,205 m of vertical, versus v1’s 550–642 m. Each seed launches above 60 km/h within ten seconds using the real solver, no steering and a 0.6 tuck input. More than half the sampled terrain exceeds 35°, and each has connected downhill space on both sides of the ridge. The connectivity graph permits slopes up to 48° for expert traversals; race endpoint placement remains capped at 40°. Sampled connectivity does not certify a complete high-speed line.

`tests/mountain_speed_playtest.gd` uses ordinary steering and 0.75 tuck with no braking by default. On seed `849205174`, the west and east entry biases complete in **62.0 / 63.6 s**, peak at **151.25 / 154.20 km/h**, and accumulate **0 / 0.87 s** airborne. On the same ordinary-input pilot, v1 reaches roughly 42 km/h after ten seconds; v2 reaches 78–80 km/h. The v1 attempts eventually collide with a rock/tree, so they do not provide comparable completion times. The solver, gravity, drag and equipment tuning are unchanged.

The pilot chooses a local downhill heading and looks ahead for obstacles; it is test code, never a player assist. Entry biases do not guarantee distinct routes on every seed. Exploratory unbraked runs can still lose balance on optional expert drops. The gentler snow-lip landing was adjusted after seed 0 exposed a balance failure; both entry attempts now finish that seed.

Reproduce the new example with:

```sh
./godotw --headless --script tests/mountain_speed_playtest.gd -- --both-routes
./godotw --script tests/mountain_speed_playtest.gd
```

Use `-- --descent-captures` for visual evidence; screenshot capture affects timing. `--seed=0`, `--version=1` and `--speed-limit=120` are optional test arguments; the default has no speed limit or automatic braking. Runs are unranked and do not write personal bests. Reports and captures live under `artifacts/mountain_generation_v2/`. The v1 harness and historical reports remain available. The example recipe `examples/mountains/849205174-v2.apexmountain` imports the new mountain; the original example file remains v1.

The final native eastern run on Apple M4 / Godot 4.7.2 / Forward+ Metal, **Low, 1440 × 900 actual pixels, snowfall / High weather**, records **120.0 FPS average**, **8.333 ms mean**, **9.842 / 10.909 ms p95 / p99**, and **84.0 FPS slowest-1% mean** over 7,630 frames after 120 warmup frames. No screenshots were taken during timing. It reproduces the headless 63.6 s completion, 154.20 km/h peak and 0.87 s airtime without crashing. This supports the approximately 60 FPS Low target for this route and configuration. Another open game instance was temporarily suspended during the benchmark and resumed afterward; the separate screenshot run includes concurrent rendering and must not be used as the isolated frame-rate result.

Final regressions pass **96 generator, 25 library, 56 physics, 72 runtime, 51 race, 64 competitive and 6 scenery checks**. The library suite also passes in the native renderer. Both v1 and v2 fingerprints are frozen, and old files, copied versioned seeds, generated races and the original laboratory retain their identities. The validation covers these fixtures and this device, not subjective fun or every seed/line.


## Technical Showcase — fixed south face, v6

Choose **Technical Showcase · South Face** in the mountain library, then **Ski
This Mountain**. Enter south from the original summit (the initial heading).
The fixed recipe is `Mountain Seed: 849205174 / v6`, also provided in
`examples/mountains/technical-showcase-v6.apexmountain`. Other showcase seeds
are rejected clearly; ordinary bare seeds and Random Mountain still use v4.

The first v5 face was rejected in riding feedback as too smooth and easy. V6
retains that recipe for exact reconstruction and replaces the current showcase
with much stronger physical relief: staggered rock spines alongside the rider,
large buttresses dividing the face, deep banked gullies, interrupted cliff
bands, uneven snow folds, clustered boulders and dense lower forest. This is a
70° sector below the summit, blended into the original surrounding mountain.
The two snow drainages turn around the ridges and through the forest. They have
an outlet from closed depressions and banked beds, while retaining changes in
pitch. Speed over convex terrain can release the skis. A separate optional 6 m
shelf drop has a pitched approach and landing fan.

`generators/technical_showcase_v6.gd` composes the unchanged v4 summit, builds
landforms and stand footprints as deterministic data, then bakes the combined
4 m heightfield. Rock spines have a spatial lookup used by shaping and exposure.
The localized 897 × 669 rock/snow mask has the same 4 m sampling and feeds the
terrain material and survey preview. It changes appearance, not friction.
Trees and boulders use the existing collision dimensions, spatial index and
MultiMesh renderer. Seeded stand placement maintains a 6 m minimum trunk spacing;
glades account for physical trunk widths. Limited family palettes reduce batches.
Quality, weather and camera choices cannot alter physical placement.

Schema 1 remains unchanged. Version-specific height and obstacle fingerprints
separate showcase races and records. V1–v5 recipes reconstruct their original
terrain. The original summit and radial completion behavior are preserved. The
Node-independent 120 Hz solver, tuning, input contract and shared contact remain
unchanged. Steering targets exist only in test scripts, never in runtime physics.

Validation commands:

```sh
./godotw --headless --script tests/technical_showcase_v6_suite.gd
./godotw --headless --script tests/technical_showcase_v6_hazards.gd
./godotw --headless --script tests/technical_showcase_suite.gd # archived v5 identity
./godotw --headless --script tests/mountain_library_suite.gd
./godotw --script tests/technical_showcase_playtest.gd -- --views
./godotw --script tests/technical_showcase_playtest.gd -- --side=-1 --weather=snowfall --pov-forest
./godotw --script tests/technical_showcase_playtest.gd -- --side=1 --weather=clear --captures
```

Current evidence belongs in `artifacts/technical_showcase_v6/`. Capture runs
include screenshot stalls and are visual evidence only. Screenshot-free native
runs report actual pixels, device, frame-time distributions and isolated solver
cost. All test descents are unranked. Archived v5 evidence, including its 118.3 FPS
run, belongs in `artifacts/technical_showcase_v5/` and does not validate v6.

This is a constructed showcase with heightfield cliffs, existing assets and
physical broad roughness. It has no overhangs, deformable snow or rock-specific
friction. Automated completion establishes feasibility, not riding enjoyment.
Repeated player attempts must establish readable hazards, improved line choice
and enjoyable execution before this approach is generalized to random seeds.

### V6 physical validation — 2026-09-06

The final face has **46 physical rock spines**, with a maximum added relief of
**213.3 m** above the original terrain where landforms overlap. It contains
**8,018 total obstacles**, including **6,368 trees inside the changed sector**;
minimum trunk spacing is **6.002 m**. Surrounding heights and obstacle order
remain exact, the summit remains the maximum, and angular boundary normal
changes stay below 0.018. The published recipe freezes both physical hashes.

Ordinary-input solver descents finish west/east in **372.042 / 372.200 s**, with
**70.64 / 79.55 km/h** peak speeds and **0 / 1.642 s** total airtime. Neither
crashes; the eastern rider's minimum balance is 0.694. Mean change in drainage
floor grade per 4 m sample is 0.091, so the snow passages retain physical pitch
variation. These conservative test pilots are not optimum race times or player
assistance. Test logic is never loaded by the runtime generator or solver.

The physics, runtime, mountain, generated-mountain, summit, race, jump, graphics,
mountain-library, archived-v5 and v6 hazard checks pass, along with 19 current
showcase checks: **546 checks in total**. Optional-drop entry fixtures at
40/55/70/95 km/h land without a crash; unbraked full descents fail on both snow
alternatives. Deliberate tree and rock impacts produce their expected crashes.
The fixed-entry fixtures test local hazards, not ideal whole-run approach speeds.
The source audit confirms unchanged solver, rider body, input, shared contact,
original generators and main lifecycle. Full results are in `results.json`,
`hazards.json`, `regressions.json` and `unchanged_authorities.json` under the v6
artifact directory.

The complete native western descent in **Low**, **Snowfall / High weather**,
**Godot 4.7.2 / Metal / Apple M4**, at **1440 × 900 actual pixels**, finishes in
372.042 s without a crash. Across **44,167 measured frames**, mean frame time is
**8.423 ms (118.7 FPS)**, with **9.769 / 11.083 ms p95 / p99** and **12.806 ms
slowest-1% mean**. The first-person forest section contains 8,846 frames: **8.737
ms mean**, **10.933 / 13.277 ms p95 / p99**, and **14.263 ms slowest-1% mean
(70.1 FPS)**. The run is isolated and foreground; it excludes 120 warmup frames
and screenshot capture. These measurements support the approximately-60-FPS Low
target for this configuration and route, including the dense forest.

World mesh construction takes 4.453 s. Reported peak video memory is about 882
MiB. Isolated solver steps average 0.291 ms, with 0.491 ms p99; this excludes
presentation and collision preparation. The report and its exact physical
fingerprints are in `artifacts/technical_showcase_v6/native_-1_snowfall.json`.
Clear and snowfall survey/chase/first-person captures are in the same directory.
Player evaluation of repeated attempts remains open; none of these metrics
claims that the revised face is fun.

## Technical Showcase v7: PC alpine treatment

The Technical Showcase button selects **849205174 / v7**. `examples/mountains/technical-showcase-v7.apexmountain` is the portable recipe. Bare seeds and Random Mountain remain v4. Old v1-v6 recipes keep their generator and physical fingerprints.

v7 keeps the v6 south-face arrangement: broken ridges, both banked drainages, interrupted cliff bands, rough apron, optional drop and dense lower stands. Angular buttress profiles and ledges are baked into the authoritative 4 m surface. Sheltered shoulders retain snow while exposed faces read as rock. Materials and asset geometry carry detail smaller than the grid. No shader displacement changes skiable height.

The pinned v7 height SHA-256 is `9f303aab12a3a3bc97b115b4040013303b04f562c2bb5a2486214602b822b560`; obstacle SHA-256 is `afeb8a384c013515344980dc3f913bc24bcfecffb18332ed7ce93f6ad199025a`. There are 7,947 physical obstacles and 46 terrain spines. Cosmetic asset selection is independently versioned. See `PC_ENVIRONMENT_IMPLEMENTATION.md` for measured acceptance and remaining limitations.

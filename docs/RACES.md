# In-world open-route races

The first race-authoring increment implements **start here, finish there, find the fastest route** on the playable laboratory and generated drainage-basin mountains. There are no checkpoints, gates between endpoints, route corridors, or steering assistance in an authored race. The surrounding generated mountains remain scenery outside the skiable test face.

## Create, race and share

1. Choose **Create / Shared Races** from the title, pause, crash or finish menu, or press **F4** while skiing. The rider and race clock pause while the survey camera explores the actual world.
2. Choose **Create in the world**. Click snow to place the start, then click snow to place the finish. **WASD / arrows** pan and the mouse wheel zooms. **Use skier position** places the selected endpoint at the current rider's surface position. Click an endpoint button to reposition it. Typing in the name/code fields does not trigger skiing shortcuts.
3. Enter a name and choose **Save race**. The saved library shows the mountain seed and both XYZ positions in metres. Back/Escape from a draft discards it; no race is saved until Save succeeds.
4. Choose **Race it**. The rider starts at rest at the selected start, facing the finish; the 120 Hz simulation clock starts with the run. **R** retries the same race from the same start and heading. Pause excludes time. The finish can be approached from any direction.
5. Choose **Copy to share** in the library and send that text to another player through your preferred channel. They paste the complete code into **Paste a shared race code here**, then choose **Import race code** and **Race it**. Import saves locally; no account or server is required. Importing an identical code is idempotent.
6. **Race the original test face** in the library returns from a custom race to the original benchmark, restoring its terrain seed when necessary.

Creation currently uses a keyboard and mouse. Standard gamepad skiing remains available when racing. Gamepad endpoint placement, race editing/deletion, downloadable file dialogs, public discovery and network leaderboards are not implemented. Local PB ghosts, automatic splits, visible history and retries are implemented in [the competitive loop](COMPETITIVE_LOOP.md).

## Definition and mountain reference

`scripts/racing/race_definition.gd` owns JSON schema **1**, independently of the mountain generator and ski model versions. The definition contains:

- `mountain`: playable generator (`laboratory` or `alpine-drainage`), generator version, playable seed, scenery seed/version, and exact Godot engine version.
- `race`: name, `open_route` type, start XYZ, start heading in radians, finish XYZ, finish radius and vertical extent.

The example mountain seed **849205174** identifies the playable laboratory's heightfield and obstacles. The existing decorative `--mountain-seed` option remains separate. Both seeds travel in the code, so a shared race restores both the physical terrain and its surrounding scenery. A different reference rebuilds the scene before the run; it never silently runs imported coordinates on the current mountain. This rebuild preserves graphics/weather settings, time of day, workbench values and their unranked eligibility. Generated mountain references additionally pin physical height and obstacle fingerprints; archived drainage v1 races reconstruct their original mountain while new mountains use v2; the same numeric seed cannot confuse the two generator types. See [mountain sharing](MOUNTAINS.md).

There is deliberately no required checkpoints field. Unknown rules are rejected rather than silently discarded. Checkpoints, gates, mandatory passages, checkpoint-width limits, equipment restrictions, weather and time presets can be introduced by explicit later schema versions without making them prerequisites for open-route races. Current weather and daylight are presentation only and are not race rules.

The finish is a finite cylinder centered on the saved finish XYZ: **12 m horizontal radius, ±16 m vertically**. Its ring follows the snow surface; the label remains readable from survey and chase views. The vertical bound prevents a pass arbitrarily far above the destination from counting. Entry from any side or vertically is accepted. The intersection of the swept horizontal interval and the vertical interval determines the exact fraction of the last tick; a fast skier cannot tunnel completely through the area. The start is an exact stationary spawn, rather than a separate rolling-start trigger.

## Validation and persistence

Codes are bounded to 16 KB. Import rejects incomplete schemas, unknown rules/types, unsupported generator/engine versions, invalid seed integers, nonfinite/wrong-type coordinates and headings, and names outside 1–60 printable characters. Endpoints must lie on the current generated snow, within a margin of the playable boundary, on a slope under 40°, with a small obstacle-free patch. They must be at least 40 m apart horizontally. This verifies practical endpoint placement; it does not prove a skiable route exists between every pair or rank its difficulty.

Races are individual JSON files in `user://races_v1/`, named by a SHA-256 of their canonical definition. Saving writes a temporary file and renames it after a successful flush. A malformed library entry is skipped with a visible warning. The race name is part of this identity, so a renamed race currently gets a separate entry and record identity.

Personal bests, the last 20 eligible results, PB splits and ghosts use schema-2 compressed documents in `user://race_records_v1/` (`<course-hash>_competition_v2.apexrun`). Legacy schema-1 JSON times are retained and migrated; see [competitive persistence](COMPETITIVE_LOOP.md#records-and-compatibility). Their identity includes the complete mountain/race definition, ski model version and default tuning-resource checksum. The original `user://benchmark_v1.json` and `laboratory-v3-physics-v4-default` identity remain unchanged. Modified physics, speed-lab and automated runs remain unranked. Tests use separate disposable directories and do not save benchmark times.

This is local, trust-based competition: there is no server validation, anti-tamper protection, cross-platform deterministic replay guarantee or terrain streaming. Exact engine-version pinning deliberately favors reproducibility over accepting possibly incompatible terrain samples.

## Code boundaries and validation

- `race_definition.gd`: portable data, canonical identity and supported-mountain/endpoint validation; no Nodes.
- `race_store.gd`: local library persistence and import loading.
- `race_workshop.gd`: survey camera, picking the existing triangulated snow, creator/library UI, sharing clipboard, and endpoint markers.
- `run_session.gd`: fixed-step finish intersection, timing, progress and isolated personal records.
- `main.gd`: paused authoring lifecycle, replaying the selected race, and full mountain reconstruction.

The ski solver, renderer-independent mountain data, plugin/autoload configuration and 120 Hz time step are unchanged. Survey ray sampling runs only during authoring. Custom races hide the benchmark corridor's markers and add only two endpoint markers, without introducing route-following logic.

Run the checks with:

```sh
./godotw --headless --script tests/physics_suite.gd
./godotw --headless --script tests/runtime_suite.gd
./godotw --headless --script tests/race_suite.gd
./godotw --script tests/race_suite.gd
```

The last command performs a native rendered playtest and captures creation, saved/shared race controls, chase-view racing and completion. The suite also reconstructs an imported mountain with different terrain/scenery seeds and returns to the original benchmark. Captures and results live in `artifacts/race_*`. This is functional and visual verification, not a frame-rate benchmark or a substitute for player assessment of route discovery.


On v4 full mountains, the survey covers every quadrant, can zoom out to the entire mountain, and places endpoints on any face. Free-ski summit staging is separate from timed race starts: put a race start on a summit rim (at least 12 m from the exact high point) or farther downhill, where gravity can start the rider. The finish remains the authored target in any direction; the radial free-ski base does not end a timed race. V1–v3 race terrain reconstructs from the archived generators.

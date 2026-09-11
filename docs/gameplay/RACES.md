# In-world open-route races

Current schema **3** uses the [shared summit-return zone](../world/WILDERNESS.md).
Generated summit endpoints must be at least 25 m inside the 2,850 m disk.
The survey draws its outline; skiing shows a warning only within the final 150 m.
Crossing aborts an unfinished race and returns to summit free skiing through a
brief fade. A finish strictly before the crossing remains valid; ties return
without a result. Earlier race formats are rejected and libraries start fresh
in `user://races_v3/` and `user://race_records_v3/`, without migration.

Open-route races implement **start here, finish there, find the fastest route** on the playable laboratory and generated mountains. There are no checkpoints, gates between endpoints, route corridors, or steering assistance in an authored race. The distant panorama remains unreachable scenery beyond the shared summit-return zone.

The default v10 mountain offers **Mountain Sprint** immediately in the race library. It uses validated clearings and the same open-route rules as a saved race; it does not create a library file until you import its shared code. Other v10 seeds receive a suggested race when a suitable pair of clearings is found.

## Create, race and share

1. Choose **Create / Shared Races** from the title, pause, crash or finish menu, or press **F4** while skiing. The rider and race clock pause while the survey camera explores the actual world.
2. Choose **Create in the world**. Click snow to place the start, then click snow to place the finish. **WASD / arrows** pan and the mouse wheel zooms. **Use skier position** places the selected endpoint at the current rider's surface position. Click an endpoint button to reposition it. Typing in the name/code fields does not trigger skiing shortcuts.
3. Enter a name and choose **Save race**. The saved library shows the mountain seed and both XYZ positions in metres. Back/Escape from a draft discards it; no race is saved until Save succeeds.
4. Choose **Race it**. The rider starts at rest beneath the start arch, facing locally downhill; the 120 Hz simulation clock starts with the run. **R** retries the same race from the same start and heading. Pause excludes time. Ski through the finish arch from either direction to stop the clock.
5. Choose **Copy to share** in the library and send that text to another player through your preferred channel. They paste the complete code into **Paste a shared race code here**, then choose **Import race code** and **Race it**. Import saves locally; no account or server is required. Importing an identical code is idempotent.
6. **Free ski current mountain** returns to summit free skiing and removes the race gates. In the laboratory the same button restarts its explicit test fixture.

Creation currently uses a keyboard and mouse. Standard gamepad skiing remains available when racing. Gamepad endpoint placement, race editing/deletion, downloadable file dialogs, public discovery and network leaderboards are not implemented. Local PB ghosts, automatic splits, visible history and retries are implemented in [the competitive loop](COMPETITIVE_LOOP.md).

## Definition and mountain reference

`scripts/racing/race_definition.gd` owns JSON schema **3**, independently of the mountain generator and ski model versions. The definition contains:

- `mountain`: playable generator (`laboratory` or `alpine-drainage`), generator version, playable seed, scenery seed/version, and exact Godot engine version.
- `race`: name, `open_route` type, start XYZ/heading, finish XYZ/heading, 10 m width, 4.5 m height and prop layout version 1. Headings use radians.

The mountain reference identifies the physical generator, version and seed; the decorative `--mountain-seed` option remains separate. Both seeds travel in the code, so a shared race restores both the physical terrain and its surrounding scenery. A different reference rebuilds the scene before the run; it never silently runs imported coordinates on the current mountain. This rebuild preserves graphics/weather settings, time of day, workbench values and their unranked eligibility. Generated references additionally pin physical height and obstacle fingerprints. Schema-3 races can reference archived physical generators without accepting the old race format; the same numeric seed cannot confuse different generator types. See [mountain sharing](MOUNTAINS.md).

There is deliberately no required checkpoints field. Unknown rules are rejected rather than silently discarded. Intermediate checkpoints, mandatory passages, equipment restrictions, weather and time presets can be introduced by explicit later schema versions without making them prerequisites for open-route races. Current weather and daylight are presentation only and are not race rules.

The finish is the finite plane through the timber arch, with **10 m nominal width and 4.5 m clearance** above its seated base. Separate solid feet, posts and overhead beams leave the opening clear. A narrow stripe marks the timing plane; elevated labels remain readable in survey and chase views. The swept rider root must cross that plane from either direction, with its 0.7 m width inside the posts and its 1.6 m height below the beam. Passing beside or above the arch, or moving along its plane, does not finish. Within-tick intersection prevents tunneling and gives the exact final fraction. The start remains an exact stationary spawn, rather than a rolling-start trigger.

## Validation and persistence

Codes are bounded to 16 KB. Import rejects incomplete schemas, unknown rules/types, unsupported generator/engine versions, invalid seed integers, nonfinite/wrong-type coordinates and headings, and names outside 1–60 printable characters. Endpoints must lie on the current generated snow, within a margin of the playable boundary, on a slope under 40°, with clearings large enough for both supports, away from trees, rocks and discovery props. Upright arches receive stone foundations on moderately uneven snow; overly uneven footprints are rejected. They must be at least 40 m apart horizontally. This verifies practical endpoint placement; it does not prove a skiable route exists between every pair or rank its difficulty.

Races are individual JSON files in `user://races_v3/`, named by a SHA-256 of their canonical definition. Saving writes a temporary file and renames it after a successful flush. A malformed library entry is skipped with a visible warning. The race name is part of this identity, so a renamed race currently gets a separate entry and record identity.

Personal bests, the last 20 eligible results, PB splits and ghosts use schema-2 compressed documents in the fresh `user://race_records_v3/` directory (`<course-hash>_competition_v2.apexrun`). Old race definitions and records are not loaded or migrated. Their identity includes the complete mountain/race definition, prop layout version, zone rules version, ski model version and default tuning-resource checksum. The separate laboratory benchmark and its legacy migration remain unchanged; see [competitive persistence](COMPETITIVE_LOOP.md#records-and-compatibility). Modified physics, speed-lab and automated runs remain unranked. Tests use separate disposable directories and do not save benchmark times.

This is local, trust-based competition: there is no server validation, anti-tamper protection, cross-platform deterministic replay guarantee or terrain streaming. Exact engine-version pinning deliberately favors reproducibility over accepting possibly incompatible terrain samples.

## Code boundaries and validation

- `race_definition.gd`: portable data, canonical identity and supported-mountain/endpoint validation; no Nodes.
- `race_store.gd`: local library persistence and import loading.
- `race_workshop.gd`: survey camera, picking the existing triangulated snow, creator/library UI, sharing clipboard, and endpoint markers.
- `run_session.gd`: fixed-step finish intersection, timing, progress and isolated personal records.
- `main.gd`: paused authoring lifecycle, replaying the selected race, and full mountain reconstruction.

The ski solver, renderer-independent mountain data, plugin/autoload configuration and 120 Hz time step are unchanged. Survey ray sampling runs only during authoring. Custom races hide the benchmark corridor's markers and add two collidable endpoint arches, without introducing route-following logic.

Run the checks with:

```sh
./godotw --headless --script tests/physics_suite.gd
./godotw --headless --script tests/runtime_suite.gd
./godotw --headless --script tests/race_suite.gd
./godotw --script tests/race_suite.gd
```

The last command performs a native rendered playtest and captures creation, saved/shared race controls, chase-view racing and completion. The suite also reconstructs an imported mountain with different terrain/scenery seeds and returns to the original benchmark. Captures and results live in `artifacts/race_*`. This is functional and visual verification, not a frame-rate benchmark or a substitute for player assessment of route discovery.


On full summit mountains, the survey covers every quadrant, can zoom out to the entire mountain, and places endpoints on any face inside the zone. Free-ski summit staging is separate from timed race starts: put a race start on a summit rim (at least 12 m from the exact high point) or farther downhill, where gravity can start the rider. The finish remains the authored target in any direction; crossing the 2,850 m boundary aborts an unfinished attempt. Archived physical generators remain available to schema-3 definitions, independently of the rejected earlier race formats.

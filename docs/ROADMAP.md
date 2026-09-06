# Development gates

## Current: playable movement laboratory

Milestone 1 is implemented as a prototype candidate, with initial Milestone 2 presentation. Acceptance still needs a human assessment of control and skiing feel. Automated tests measure behavior and guard against regressions; they cannot establish that skiing is fun.

Suggested first playtest:

1. Make a no-tuck run, then a tucked run. Compare braking distance and anticipation needed.
2. Compare a sequence of shallow turns to abrupt corrections; use F3 to observe slip and acceleration.
3. Use the F2 speed lab at 30, 60, 90, 120, 150, 165 and 200 km/h. Evaluate steering authority and near-object speed cues with and without instruments.
4. Take the optional right-side terrain transition around x=88 m, z=740 m and compare contact/landing behavior. A small hop on the main slope is also useful for checking landing response.
5. Repeat with a DualShock 4 and DualSense, wired and wireless where possible. Check dead zone, analog trigger range, vibration and restart mapping.

Record the speed range, input device, tuning changes and terrain location with feedback. Prioritize a controllable and rewarding high-speed carve over additional systems.

## Next: finish the speed-feel pass

- Tune steering onset, countersteering, grip saturation and small-slip energy loss through repeated player runs.
- Compare four-metre support filtering against a finer terrain/contact model; evaluate active compression absorption without adding propulsion exploits.
- Weather and arcade wind cues are implemented as presentation only. Playtest the four presets and V/quality options; listen-test the rain and gust mix alongside contact feedback.
- Listen-test the new contact/edge/landing mix, refine nearby-object rush cues, assess the lower chase/first-person cameras with V on/off, and test haptics on real hardware.
- Measure at 60/120/144+ display refresh with input capture; collect frame-time distributions on Windows/Linux and lower-end GPUs.
- Improve skier pose and snow readability only where it helps control and feedback. No excessive blur or camera shake.

## Milestone 3: procedural mountains — first bounded increment implemented

The `alpine-drainage-v2` generator builds physical seeded ridges, offset bowls, a branching spur, gully, optional drop, forest patches and a lower runout. Players can generate random mountains, reconstruct seeds, preview, name/save/load mountains, and import/export compact versioned files. Generated mountains support the existing race creator. The 4 m shared triangle surface and existing terrain renderer remain authoritative; see [MOUNTAINS.md](MOUNTAINS.md).

Next: player assessment across more seeds, more geological/topology families and presets, selected free-ski spawn points, background generation with bounded mesh upload, portable baked snapshots and version migration. Add streaming/LOD only when measurements justify it. Frozen rivers and overhangs are not implemented.

## Milestone 4: author a race in the world — first increment implemented

The laboratory and generated mountains support in-world survey → mark start → mark finish → name/save → race → instant retry → copy/paste share. Start and finish are the only required spatial rules. The versioned definition references both playable and scenery seeds; imports validate finite surface positions, supported engine/generator versions, bounds and clear endpoint patches. Records are isolated by the complete race/mountain and physics/tuning identity. See [RACES.md](RACES.md).

Next increments can add gamepad authoring, edit/delete controls, rolling starts and optional checkpoints, gates, mandatory passages, width limits, equipment/weather/time rules. None should make checkpoints compulsory for the open-route race type. General procedural mountain authoring, network discovery, leaderboards and replay compatibility remain separate work.

## Milestone 5: compete with yourself — implemented locally

The benchmark and saved races now record 120 Hz inputs and 30 Hz pose samples, preserve a local PB ghost, compare three automatic approach splits and display the last 20 completed eligible runs. R / △ restarts the rider, clock, recorder and comparisons together. Replay compatibility pins course, engine, model, tuning and tick rate; legacy best times migrate without fabricated ghosts. The ghost is read-only presentation and cannot affect the ski solver. See [COMPETITIVE_LOOP.md](COMPETITIVE_LOOP.md).

Next: player assessment of route discovery and visual ghost readability, optional remote ghosts/leaderboards, and replay-based verification. The competitive increment runs on the benchmark and authored races on either bounded terrain type.

The end-to-end target remains: generate → discover → create a race → race → improve → beat a best → share.



## Graphics and terrain foundation added

The current implementation includes textured terrain, a skinned skier, modeled equipment, regional tree LODs and baked far silhouettes. The built-in terrain renderer is the sole path; the optional Terrain3D integration was removed after it failed to establish a useful advantage in the bounded-course comparison. A separately seeded mountain-data generator produces float32 heights and environment masks while preserving every original lab vertex. See [GRAPHICS.md](GRAPHICS.md).

The first generated terrain contract is now playable. Continue assessing ski/contact behavior across seeds, route quality and generation/upload work on target hardware. Vegetation suitability masks must feed a deterministic placement contract that keeps visible trunks and collision footprints synchronized. The current decorative seed is not a new benchmark course. Streaming and replay compatibility remain separate milestones. The authoring/sharing UI is available on both the bounded laboratory and generated basins.


## Technical mountain showcase — opt-in increment

The current v6 south face replaces the overly smooth v5 fixture with stronger
rock spines, rough snow folds and banked gullies through offset
cliff crags, an optional drop, a boulder apron and dense forest stands with
meandering glades. The library exposes it separately from random v4 mountains.
Next: player assessment of both snow alternatives, braking and hazard visibility;
then generalize successful landform relationships to seeded faces. Passing an
automated descent is not acceptance of riding fun. See [MOUNTAINS.md](MOUNTAINS.md).

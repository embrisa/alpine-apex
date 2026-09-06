# Competitive loop — Milestone 5

The benchmark and saved open-route races now support **race → inspect splits → refine the line → beat a personal best → retry → share the race**. This extends the existing world authoring, seed restoration and copy/paste race-sharing flow. The playable mountain remains the bounded seeded laboratory; general playable mountain generation is still Milestone 3.

## Player flow

- Finish a timed run with default physics to set a personal best. A faster finish celebrates **Personal Best** and shows the difference from the best at the start of the attempt.
- **R / △** immediately restarts the selected race at rest, with the original start heading. The run clock, partial recording, split times, camera and effects reset together. The latest PB ghost starts on the same clock.
- The **cyan ghost** follows your own best recorded line. **G**, or the switch in the record panel, hides it. It is a lightweight silhouette with no collision, forces, snow tracks or sound. It fades when overlapping the player and disappears after its recorded finish.
- **25%, 50% and 75% approach splits** show cumulative times and signed differences from the PB at the start of the run. Negative is ahead; positive is behind. Differences are also labeled in words. Pause excludes time and freezes both recording and ghost playback.
- Choose **Personal Best / Run History**, or press **F6**, to inspect the best, cumulative split comparisons and the last 20 completed eligible runs. History includes UTC date, time, difference from the current PB and peak speed. Escape returns to pause; R starts another attempt immediately.
- **F4 / Create / Shared Races** retains the existing save, copy, import and race workflow. Share codes contain the mountain/race definition; your personal times and ghost remain local.

Free ski, crashes, abandoned attempts, modified-physics runs, speed-lab runs and autoplay do not enter the completed-run history or replace the PB/ghost. Ghost comparison remains available for an unranked timed attempt, and the HUD marks that attempt unranked. The current history intentionally records completed eligible runs rather than every restart or crash.

## Splits preserve open-route racing

There are no checkpoint requirements. The three invisible split planes span the entire world, perpendicular to the horizontal axis from start to finish. Their offsets are 25%, 50% and 75% of the horizontal distance from the start to the near edge of the finish area. The benchmark uses its existing finish plane.

Each split records only the first forward passage, interpolated within the physics tick. Backtracking cannot overwrite it, several splits can be crossed in one tick, and no split changes finish eligibility. The planes do not constrain lateral position, altitude or the player's steering. Their percentages describe approach along this axis, not distance actually skied. An exploratory detour may cross a split early and lose time later; the finish time remains the competitive result.

The PB split reference is frozen at restart. Beating the PB at the finish updates the stored best but leaves that attempt's comparisons against the previous best intact. The next restart selects the new splits and ghost. Older records without split data display an em dash, not a fabricated comparison.

## Recording and playback

`racing/run_replay.gd` is a Node-free recorder and interpolator. It retains steer, tuck, brake and jump at **120 Hz** in a compact float32 input buffer. It samples position, heading, edge angle, tuck, surface normal and grounded state at **30 Hz**, with an initial sample and a final sample at the exact sub-tick finish intersection.

Playback reads these snapshots using a binary search, interpolated positions and shortest-arc heading interpolation. It does not re-run the ski solver, avoiding accumulated re-simulation drift. The ghost uses the same previous/current simulation-time interpolation interval as the player. Pausing and resuming synchronize those intervals; restarting replaces the unfinished recorder and resets the timeline. Future input replay validation can use the retained inputs, but authoritative verification and cross-platform bitwise deterministic re-simulation are not implemented.

Recording is capped at **10 minutes**: exceeding the cap releases its buffers while the race clock continues. Such a run can still set a best time and save history, with an explicit indication that its ghost is unavailable. Only a completed new PB promotes its recorder to the saved ghost. Slower, tied, crashed, restarted, modified and automated attempts cannot replace it.

The renderer uses twelve low-detail meshes with a shared translucent cyan material. Shadows, GI contribution, particles and collision are disabled. It is hidden within 1.2 m of the player, fades to full opacity at 4 m, and is culled beyond 750 m. Ghost rendering and its visibility switch never feed into the ski solver, input or terrain contracts.

## Records and compatibility

`racing/competitive_record.gd` writes schema **2** as one Zstandard-compressed JSON document. Best time, PB splits, last 20 completed results and the matching replay commit together: write a temporary file, close it, then rename it into place. A failed save is shown to the player; the in-memory result remains available for the session. The record reader limits decompressed data to 8 MiB and validates numeric fields, sample ordering, input size and replay compatibility.

New files sit beside the old records:

- Benchmark: `user://benchmark_v1_competition_v2.apexrun`.
- Custom races: `user://race_records_v1/<course-hash>_competition_v2.apexrun`.

The old JSON files remain untouched. If no valid schema-2 file is available, a valid schema-1 best and completed times are migrated in memory, then written in the new format on the next save. Unknown historical dates, speeds and splits stay unknown. A legacy PB has no invented ghost: beat it to record one.

Replay schema **1** pins the course identity, engine version, ski model version, default tuning checksum and 120 Hz tick rate. A different race or mountain receives a different course identity through the existing race definition. Incompatible/malformed ghosts are rejected while valid stored times remain visible, with an explanation in the record view. JSON numeric normalization is deliberate; JSON's float representation must not make an otherwise compatible replay fail to load.

This is local competition. Files are not tamper-proof, and the retained input stream is not an anti-cheat system. Network leaderboards, remote ghosts, replay sharing, history deletion and general mountain generation remain separate work. The original benchmark identity and physical trajectory are unchanged.

## Code and verification

- `core/run_session.gd`: timing, free-route splits, frozen PB reference, recorder lifecycle and record promotion.
- `racing/run_replay.gd`: bounded capture, validation and snapshot lookup.
- `racing/competitive_record.gd`: atomic records and legacy migration.
- `presentation/personal_best_ghost.gd`: read-only silhouette rendering.
- `ui/competitive_panel.gd`: PB, split and history view.
- `main.gd`, `ui/hud.gd`, `core/input_router.gd`: lifecycle, immediate feedback and controls.

Run:

```sh
./godotw --headless --script tests/physics_suite.gd
./godotw --headless --script tests/runtime_suite.gd
./godotw --headless --script tests/race_suite.gd
./godotw --headless --script tests/competitive_suite.gd
./godotw --script tests/competitive_suite.gd
./godotw --script tests/competitive_suite.gd -- --profile-full-competition
```

The competitive suite uses disposable record directories and checks that both of the user's benchmark files remain unchanged. It covers PB replacement and retention, history bounds, migration, compatibility rejection, save failure, first-passage splits, exact finish samples, interpolation, pause/resume, restart, camera views, ghost toggling and physics independence. The native suite captures title, history, chase/first-person ghosts, a new PB and its split comparison.

The full profile runs the complete laboratory through snowfall at Low, with the PB ghost disabled and enabled. Timing stays unranked; a separate discarded recorder measures the normal recording work. It excludes the first 120 rendered frames and screenshot overhead during each descent. Reports include actual pixels, device/backend, weather quality, average FPS, p95/p99 and slowest-1% FPS. See [VALIDATION.md](VALIDATION.md) for measured results and their limits.

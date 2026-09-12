# Mountains, races and records

## Mountain library

[MountainDefinition](../scripts/world/mountain_definition.gd),
[MountainStore](../scripts/world/mountain_store.gd) and
[MountainLibrary](../scripts/ui/mountain_library.gd) own generation, preview,
naming, local files and seed/file sharing. Settings/recipe/cache behavior is in
[World](WORLD.md). Seed-only entry selects Standard; canonical physical settings
travel with saved/shared definitions. Do not reconstruct coordinates against a
different recipe because its seed happens to match.

The entire physical field is ready before skiing. Preview cancellation preserves
the prior draft; a different selected/imported reference rebuilds the world while
retaining relevant preferences. Summit staging is free skiing, separate from an
authored race's stationary start. Library controls and virtual text entry belong
to the existing UI owners, not a new persistence layer.

## Race authoring

Open-route racing means start here, finish there, find the fastest route.
No intermediate gate, corridor, checkpoint or line-following assistance is
required. [RaceWorkshop](../scripts/racing/race_workshop.gd) owns survey, snow
picking, endpoint markers, name/code entry and save/import/share actions.
Survey pauses rider/session time and covers every mountain quadrant. Endpoint
placement remains pointer-based; menu navigation must not imply gamepad terrain
picking. Draft Back/Escape discards without saving.

Creating a race immediately releases drawer focus for WASD/arrow survey panning.
Survey keys are consumed before GUI focus navigation. Focusing a drawer control
or leaving the window stops panning; right-clicking terrain resumes it without
placing a gate. Left-click places an endpoint, and the wheel zooms only outside
the drawer. Controller navigation still owns menu focus, not survey translation.

[RaceDefinition](../scripts/racing/race_definition.gd) is Node-free and owns
schema/validation/canonical identity. [Current versions](ARCHITECTURE.md#current-identity)
are independent of storage directory suffixes: the current race schema is 4,
while [RaceStore](../scripts/racing/race_store.gd) still uses `user://races_v3`.
The mountain reference includes generator/seed/engine, physical settings and
height/obstacle fingerprints; laboratory/scenery references retain their own
identities. Import rebuilds a differing reference before running it.

Definitions contain the name, `open_route`, start/finish positions and headings,
fixed gate dimensions and prop version. Names are 1–60 printable characters;
codes are bounded to 16 KiB. Reject unsupported/unknown rules, malformed types,
nonfinite coordinates, invalid seeds/versions and mismatched fingerprints.
Endpoints need supported snow below 40° slope, clear gate footprints, at least
40 m horizontal separation and zone margins. Summit starts need distance from
the exact high point so gravity can start the rider. These checks establish
endpoint practicality, not a traversable route between every pair.

Saving is temporary-write/flush/rename. Identical imports are idempotent; the
name participates in canonical identity, so renaming creates another race and
record identity. Malformed library entries produce warnings. Sharing transmits
the definition, not PB times or ghosts; it requires no server/account.

## Gates, timing and splits

Only active gate pairs collide; previews do not. Marker cleanup remains owned
by `race_workshop.gd::_clear_markers`. Central beacons are presentation children
of its marker owner, depth-tested/unlit/translucent with fog, no shadow/GI.
Keep their timing stripe and physical opening independent.

The finish is a finite plane in a 10 m wide arch with 4.5 m clearance. The swept
0.7 m wide/1.6 m tall rider must cross from either direction inside the opening.
Passing beside/above or along the plane does not finish. Feet/posts/overhead
beams remain solid around the opening. [RunSession](../scripts/core/run_session.gd)
uses the exact fraction of the crossing tick; start is a stationary spawn, not
a rolling trigger. Pause excludes time; restart resets the same start/heading.
The shared return-zone crossing can abort a run as described in [World](WORLD.md#zone-discoveries-and-background-boundary).

Approach splits at 25/50/75% span the whole world perpendicular to the horizontal
start-to-finish axis. They record the first forward crossing within a tick,
including multiple planes in one tick. Backtracking cannot replace a split and
missing splits cannot invalidate a finish. Percentages measure axial approach,
not distance skied. Freeze PB comparison data at restart; a new best only becomes
the comparison reference for the next attempt. Missing comparisons remain unknown.

## Recording and ghosts

[RunReplay](../scripts/racing/run_replay.gd) retains eight float32 intent fields
at 120 Hz, snapshots every fourth tick (30 Hz), the initial pose and the exact
sub-tick finish. Field order, joint/frame layout and numeric validation belong
to that file. Playback binary-searches/interpolates snapshots; it does not
resimulate inputs. Player and ghost share the same session-time interpolation.

Recording is bounded to ten minutes. Overflow frees recorder buffers while the
race clock continues; a time can still save with an explicit unavailable ghost.
Only a completed eligible new PB promotes a recorder. Ties, slower runs,
crashes/restarts, modified physics and automation cannot replace the PB ghost.
[PersonalBestGhost](../scripts/presentation/personal_best_ghost.gd) is a cyan
silhouette with no collision, forces, tracks, sound, shadow or GI. It fades near
the player and disappears after its finish. Visibility never affects eligibility.

## Records and compatibility

[CompetitiveRecord](../scripts/racing/competitive_record.gd) stores best time,
PB splits, last 20 eligible results and matching replay together in an atomic
Zstandard JSON document. Readers bound decompression to 8 MiB and validate
numbers, sample ordering, input dimensions and compatibility. Save failure is
visible; the in-memory result remains available.

Custom records use `user://race_records_v3/<course-hash>_competition_v2.apexrun`.
The separate laboratory benchmark uses `user://benchmark_v1_competition_v2.apexrun`.
Its existing schema-1 time migration remains implemented; it supplies no invented
dates/splits/ghost. This retained code is not a requirement to add future migrations.
Follow the early-development policy in [AGENTS](../AGENTS.md).

Course identity includes complete mountain/race definition, prop/zone versions,
physics model and default tuning checksum. Replay additionally pins engine and
tick rate. A matching replay format alone does not establish compatibility.
Malformed/incompatible ghosts are rejected while valid stored times can remain
visible with an explanation. JSON numeric normalization must not reject otherwise
valid recordings. Tests use disposable stores and stay out of personal records.

## Future competition

Implemented competition is local/trust-based. Eligibility flags/checksums are
compatibility boundaries, not anti-cheat or public MMR. Preserve responsive local
skiing and offline solo play; keep account/transport concerns outside equipment
input and physical calculation.

Candidate progression is local mastery/cosmetics, friend leaderboards/ghosts,
shared asynchronous cups, private group skiing, then funded public rated play.
These are options, not implementation authorization. Steam is a candidate,
not a committed service or movement backend. Keep rules/course identity separate
from results, remote presentation separate from the local input owner, and public
rating separate from personal records/private host claims.

Before trusted submissions, measure canonical headless input-replay reliability,
drift and cost. Snapshot playback or plausible speeds cannot establish validity;
even reproducible inputs cannot prove a human played in real time. Movement
servers require a separate demand/funding/operations decision. Do not build
speculative networking, matchmaking, backend abstractions or compatibility paths
as part of ordinary local gameplay work. Current acceptance is in [Validation](VALIDATION.md#race-and-player-acceptance).

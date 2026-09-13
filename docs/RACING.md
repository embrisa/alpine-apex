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
use race schema 6 and [RaceStore](../scripts/racing/race_store.gd)
uses `user://races_v6`. Older schemas are rejected without migration.
The mountain reference includes generator/seed/engine, physical settings and
height/obstacle fingerprints; laboratory/scenery references retain their own
identities. Import rebuilds a differing reference before running it.

Definitions contain the name, `open_route`, start/finish positions and headings,
fixed gate dimensions, prop version and strict `race.recovery`:
`{rules:1, anchor:"crash_start", clock:"running", speed:"rest"}`. Recovery rules
participate in canonical race/record identity independently of physics and
weather. Canonical `conditions` contains `weather`,
`time` and `rules` (currently 1): six presets including Snowstorm/Thunderstorm,
and Dawn/Day/Dusk/Night. New and suggested races default to Clear/Day. These
fields appear in shared JSON, creator controls and library details and participate
in race and record identity. Unknown/malformed conditions or rules are rejected.
Names are 1–60 printable characters;
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

Personal [session navigation points](PRESENTATION.md#session-navigation-map) use
the survey independently. Their placement needs supported playable terrain,
without gate footprint, endpoint slope, separation or 25 m endpoint margins.
They never change race definitions, collision, timing/splits, eligibility,
recordings or records. Race preview/cleanup/retry does not own their lifetime.

## Gates, timing and splits

Only active gate pairs collide; previews do not. Marker cleanup remains owned
by `race_workshop.gd::_clear_markers`. Central beacons are presentation children
of its marker owner, depth-tested/unlit/translucent with fog, no shadow/GI.
Keep their timing stripe and physical opening independent.

Finish beacons rise 2,000 m above the anchor and fade over 1,600–2,000 m;
start beacons retain 800 m height and 600–800 m fade. Both retain their 6 m
radius, 8 m burial, green start/amber finish distinction and snow-fitted halo.
Natural terrain occlusion, fog and close fade remain; camera clipping is unchanged.
These dimensions do not establish useful visibility at a particular distance.

`race_beams.gd` keeps mesh placement, shader height/fade and true bounds consistent,
with separate materials per marker. `build(center, finish, support_surface)`
selects race styles. Other visual owners use `visual_style(finish)` and
`build_styled(center, style, support_surface)`; `base_enabled=false` removes
halo/support-grid work. This shared API creates no gate, timing plane or identity.
Native producers are in [Validation](VALIDATION.md#beacon-and-navigation-producers).

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

## Crash-location recovery

RESPAWN HERE continues the same attempt at rest near the frozen authoritative
crash-onset position; TRY AGAIN resets the whole attempt. `RunSession` accounts
for the onset tick once, then advances inactive crash ticks at 120 Hz without
skiing, splits or finish sweeps. Time continues through crash subpages and the
ragdoll's settle cap. Explicit Pause and focus loss hold it. Recovery preserves
elapsed time, first-crossing splits, frozen PB/ghost references, eligibility and
any practice reason. An eligible recovered finish may set a PB. Recovery cannot
restore eligibility, and no fixed time penalty is added.

`core/crash_recovery.gd` tries onset, nearby last support, then 2/4/6/8 m rings:
at most 34 candidates within 8 m horizontally, 2 m below or 6 m above onset.
It requires <=40° support, <=25% rock, a clear minimum 2.5 by 1.1 m ski footprint
and <=.25 m tangent-plane variation, expanded for actual equipment. A separate
simulation dry-primes contacts using the same tuning/surface before live reset;
both contacts and the body must initialize. Active race props use the shared
obstacle adapter. Ordinary skiing only copies last support, with no search.

Connected paths use <=1 m steps and reject obstacles, steep support and >.6 m
local tangent departure. Placement cannot gain race-axis progress, move beyond
an unearned split or cross the finish plane; it retains 1 m finish and 2 m
zone/bounds margins. Free skiing likewise rejects forward downhill gain. Failure
leaves an explicit unavailable reason and full restart. Search counters include
explicit queries and dry primes; native natural-mountain cost remains to be measured.

Recovery restores impact reserve and zero motion through reset/priming, retaining
peak speed, total airtime and solver tick count. Gravity and newly armed input act
on following ticks. Session/pose histories rebase without a swept teleport.
Attempt/surface tokens reject stale or repeated actions; restart, finish,
world/race changes and boundary return invalidate the anchor. UI and transient
cleanup belong to [Presentation](PRESENTATION.md#crash-recovery-controls).

## Recording and ghosts

`racing/run_replay.gd` format 7 records nine float32 intent fields at 120 Hz:
steer, tuck, brake, jump release, air pitch, air yaw, grab, limited tilt and
`jump_held`. Physical snapshots occur every fourth tick (30 Hz), with initial,
exact fractional finish and explicit crash/recovery boundary samples. Completed
pole phase/intensity/power survive, with wrap-aware phase interpolation.

`presentation/ghost_pose.gd` also captures the final root, 24 local bone poses,
both skis, both poles and evaluated per-ski track data after production fitting.
Every physical sample needs its matching production pose. Playback interpolates
those records through the existing final writer without running skiing or
resampling action clips. Missing/incompatible poses are rejected without migration.
Inactive tick kinds and closed crash intervals share session time; the decoder
cross-checks intervals, zero inactive input and physical/production boundaries.
A ghost hides during its own crash, then resumes from a fresh interpolation/track
origin. Other selected ghosts continue during the player's unpaused crash.

Recording is bounded to ten minutes, 256 crash intervals and the payload limits
below. Overflow frees recording buffers while the clock continues; an eligible
time can save with an explicit unavailable-ghost notice. Every eligible finished
recording can enter the fastest-ten archive, including ties and slower-than-PB
runs that qualify. Abandoned, practice or automated runs cannot replace it.
PB comparison stays frozen independently of the selected competitors.

`ghost_field.gd` snapshots the selected roster at start/retry. Each
`personal_best_ghost.gd` owns a fully equipped production visual, private materials
and an independent bounded track history over shared immutable meshes. Ghosts
have no collision, input, force, ragdoll, audio, spray, shadow or GI. Distance
opacity remains .15–.72, never zero solely because of overlap or distance; depth
occlusion still applies. Each hides at its own finish while retained marks remain.
Pause, visibility, backward time, gaps and recovery prevent connecting strokes
across discontinuities. Track composition belongs to [Rendering](RENDERING.md#snow-presentation),
selection controls to [Presentation](PRESENTATION.md#ghost-selection).

## Diagnostic test cases

`scripts/diagnostics/test_cases.gd` owns an opt-in, isolated diagnostic session.
It installs `case_simulation.gd` and `case_surface.gd` around the production
120 Hz solver and shared 4 m terrain. The explicit `case_policy.gd` keeps speed,
immunity and obstacle categories independent. It does not use the stress driver.
Ordinary skiing has no installed diagnostic policy. Diagnostic sessions disable
competitive capture, personal-record eligibility and preference writes; exit
restores ordinary ownership. Every take starts at the selected summit face.

`case_recorder.gd` records launch state, tuning, resolved F64 input fields, ordered
accepted controls, completed contact/impact telemetry, source and engine hashes,
mountain reference, rig identity and presentation configuration. Render observations
contain timestamp, completed tick, interpolation fraction, frame duration, skier,
equipment and camera transforms, appearance context, weather and track footprints.
Crash poses read the actual Jolt bodies. Capture continues through the existing
15-second aftermath; manual save can stop it earlier. Pause/focus loss freezes the
clock. Recovery, restart and transitions finalize before changing the scenario.

`case_store.gd` publishes new `.apexcase` files under `user://test_cases_v1` using a
unique filename and same-directory temporary-file rename. Format 1 and input
layout 1 have indexed Zstandard channels, 64-row chunks, raw/compressed SHA-256
checksums, bounded metadata and decoding without objects. Limits are 72,000 ticks
(ten minutes), 256 MiB of uncompressed channels, 1 MiB per chunk/header. A limit
saves completed coverage with its endpoint reason; failed publication retains the
capture for retry. Existing files are never overwritten. No earlier-format import
or migration is supported. Keep these files separate from competitive archives.

A clip has one tick-aligned interval and retains all input/control rows from
launch through Out, plus selected visual frames and up to 30 seconds of earlier
track context. It preserves original timestamps and capture provenance, adds notes
and its parent SHA-256, and opens on the selection without requiring its parent.
Further trimming stays inside that selection. The original remains available.

Playback uses captured transforms through the existing skeleton writer, with live
skiing and ragdoll stepping disabled. Seeks rebuild bounded track history and reset
temporal effects. These files preserve pose/camera evidence, not pixel-identical
video or recorded audio. Physics edits alone do not reject visual evidence;
unsupported format, rig/assets or mountain reconstruction fail visibly. Agent
commands and comparison interpretation belong to [Validation](VALIDATION.md#recorded-bug-cases);
player controls belong to [Presentation](PRESENTATION.md#test-cases).

## Records and compatibility

`racing/competitive_record.gd` archive 4 stores PB time/splits, last 20 eligible
results, fastest-ten ghost metadata and next-attempt selection in an atomic JSON
manifest. Ordering is ascending time, date, then stable run ID. Payloads are
immutable Zstandard-compressed binary replays named by their SHA-256; write/flush/
rename publishes payloads before the manifest. Unreferenced evicted payloads are
removed only after a successful manifest commit. A failed transaction cleans its
new staged blobs and preserves prior records; save failure remains visible.

All serialized result times/splits and replay crash endpoints use
`record_clock.gd`: exactly 16 lowercase hexadecimal characters containing
little-endian IEEE754 float64 bytes. Loaded/session APIs remain numeric.
Decimal JSON parsing cannot guarantee an exact clock round trip on this engine.
The binary replay duration owns loaded duration and must exactly match result
metadata and final sample/pose timestamps. Crash boundaries must identify exact
recorded endpoints. Tick-grid comparisons retain their bounded arithmetic
tolerance; stored clock identity does not use that tolerance.

Manifest reads are bounded to 256 KiB; decompressed payloads to 32 MiB each and
320 MiB aggregate. Listing metadata does not decompress all ten recordings.
Selected payloads load at attempt reset and validate hashes, lengths, numeric/layout
bounds, completed poses and compatibility. `ghost_replay_cache.gd` retains up to
ten validated immutable replay objects per Session, bounded to 320 MiB of declared
raw payload bytes. Scope includes the normalized manifest path and full replay
compatibility identity. Each retry reads and hashes the bounded compressed bytes;
only unchanged bytes, raw hash/length and exact finish time reuse a decoded object.
New bytes still undergo bounded decompression and the complete decoder. Selection
and eviction prune cached references; race/identity changes, explicit metadata
reload and free skiing clear them. Active competitors remain frozen independently.
Valid current PB/history can survive malformed or unavailable ghost entries with an explanation. Invalid selected IDs
are removed with notice; an explicitly empty manual selection remains empty.

Headers are bounded to 16 KiB, ticks to 72,000 and physical/production samples
to 18,514 including boundaries. Raw Zstandard decompression uses the validated
manifest byte count as its destination bound. A normal ten-minute replay has
about 24.4 MiB of raw channels by layout calculation. Ten decoded selections,
a staging buffer and old active references add memory beyond compressed disk.
The cache bound is raw payload accounting, not total heap or process memory.
Measured maximum-duration cold loading remains a material latency concern; warm
retry reuse does not solve first load. Measurements and the separate completed-pose
capture/native cost limits are in [Validation](VALIDATION.md#crash-recovery-and-ghost-producers).

Custom manifests use
`user://race_records_v6/<course-hash>_competition_v4.apexrun`; laboratory records
use `user://benchmark_v1_competition_v4.apexrun`. Each has a sibling
`*_competition_v4_payloads/` directory. Earlier archive/record namespaces and
pose formats are not read or migrated. No schema-1 time migration remains.

Course identity pins full mountain/race data, prop/zone/recovery rules, physics
model and default tuning checksum; replay additionally pins engine and tick rate.
Format number alone is insufficient. Tests use disposable stores; ordinary free
skiing has neither a PB archive nor competitive ghosts. These local compatibility
checks are not anti-cheat or proof that a human produced a run.

Each authored attempt starts at the exact preset/hour with fronts and daylight
held. Gusts, lightning and cloud displacement derive from canonical race identity
and elapsed session time; retries reset to zero, pauses spend no schedule time.
Changing weather/time, enabling either cycle, or Weather FX Off latches practice
until a fresh valid retry. Returning controls to their original values cannot
restore eligibility. Low/High FX and Full/Reduced/Off lightning are permitted.
Main checks conditions before a physics tick can save a result; RunSession clears
the recorder and preserves the practice reason. Existing automation/physics/lab
restrictions still apply. Visibility rules do not enter the movement solver.

Main suspends the initial complete free-ski weather snapshot through races,
retries, finishes and world reconstruction. Leaving, boundary return and failed
race loads restore it. Race weather controls do not write personal weather/time
fallbacks. Quality/accessibility preferences can be saved independently. Old
race files and records remain on disk in their earlier namespaces.

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

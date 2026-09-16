---
id: "AA-20260916-084511-reduce-finish-crash-restart-hitches"
title: "Take archive commits, crash placement search and roster hashing off the frame"
status: done
priority: P2
depends_on: []
created: "2026-09-16T08:45:11Z"
updated: "2026-09-16T19:34:15Z"
source_thread: null
---

# Take archive commits, crash placement search and roster hashing off the frame

## Outcome

Eliminate the single-frame stalls at finish, at crash onset and at attempt
restart so results, crash menus and retries appear without a visible freeze,
while keeping atomic saves, exact clocks and integrity checks.

## Current state and evidence

Source inspected at Dev 43 / `a9c2acb` (2026-09-16); magnitudes are analytic
unless stated.

- Finish: [`run_session.gd:224-234`](../../scripts/core/run_session.gd)
  `finalize_capture` runs `save_record` in the same frame as
  `hud.show_result`. [`competitive_record.gd:201-279`](../../scripts/racing/competitive_record.gd)
  `_save_transaction` reloads the record, serialises the replay
  ([`run_replay.gd:237-255`](../../scripts/racing/run_replay.gd) `to_bytes`
  copies every row through a temporary `PackedFloat32Array` for up to 18,000
  rows), hashes with SHA-256, compresses with ZSTD, stringifies JSON and
  writes/flushes/renames, all on the main thread. Expect a 100-500 ms stall
  for long runs.
- Crash onset: [`main.gd:642-652`](../../scripts/main.gd) calls
  `crash_recovery.resolve` synchronously on the crash tick.
  [`crash_recovery.gd:45-152`](../../scripts/core/crash_recovery.gd) tests up
  to 34 candidates, each with nine footprint samples, nine obstacle sweeps,
  six segment sweeps and a path check, and for each connected candidate
  constructs a fresh `Simulation`, resets it and primes contacts. Docs note
  the natural-mountain cost remains unmeasured.
- Restart: `run_session.gd:61, 235-246` `_freeze_ghosts` re-reads and SHA-256
  hashes every selected ghost payload (`competitive_record.gd:146-196`) on
  each attempt, and `begin_capture` hashes `config/ski_default.tres`
  (`run_replay.gd:37`) each attempt. Integrity is intentional; the cost per
  retry scales with roster size.
- Cold archive loading is owned by
  [the cold archive task](../tasks/AA-20260912-132147-reduce-cold-ghost-archive-load.md);
  this task owns the save, crash and restart paths only. Contracts:
  [Racing](../../docs/RACING.md) (atomic saves, exact clocks, integrity),
  crash recovery in [Physics](../../docs/PHYSICS.md).

## Agreed decisions and scope

Own `scripts/core/run_session.gd` finalize/reset paths,
`scripts/racing/competitive_record.gd` save transaction,
`scripts/racing/run_replay.gd` `to_bytes`/`key`, `scripts/core/crash_recovery.gd`
scheduling and the crash tick in `scripts/main.gd`. Preserve byte-identical
archive output, atomic rename semantics, hash coverage and the exact result
clock. Off-thread work may only touch immutable copies; the manifest commit
and any scene mutation stay on the main thread. Crash placement may be spread
over frames because the crash menu is shown before the placement is needed;
the placement result must be the same as today.

## Implementation approach

1. Measure the three stalls with `Time.get_ticks_usec` around each path on a
   long timed run, a forest crash and a ten-ghost retry; record them.
2. Serialise, hash and compress the replay in a `WorkerThreadPool` task from an
   immutable snapshot; store samples as one preallocated `PackedFloat32Array`
   so `to_bytes` is a single `to_byte_array`; commit the manifest and rename on
   completion, and keep the result screen responsive meanwhile.
3. Run `crash_recovery.resolve` as a bounded per-frame job (or deferred until
   the ragdoll is visible), reusing one probe `Simulation` per session.
4. For retries, compare file size and modification time before re-hashing,
   or hash on a worker while the previous roster stays active until verified;
   cache the tuning file hash per process.

## Acceptance and verification

- [ ] Measured finish, crash and restart stalls fall to a few milliseconds of
  main-thread time; archive bytes and manifests are identical to the
  synchronous path for the same run.
- [ ] `tests/race_suite.gd`, `tests/competitive_suite.gd`,
  `tests/ghost_archive_suite.gd`, `tests/ghost_retry_cache_suite.gd`,
  `tests/exact_clock_suite.gd`, `tests/crash_recovery_suite.gd`,
  `tests/crash_replay_suite.gd`, `tests/physics_suite.gd` and
  `tests/runtime_suite.gd` pass, including interrupted-save recovery.
- [ ] Rendered check that the result screen, crash menu and retry appear
  without a visible freeze.
- [ ] Update [Racing](../../docs/RACING.md) persistence wording; commit/push
  with a development note and Dev ID.

Human acceptance: none beyond the rendered check; behaviour is identical.

## Open questions

None

## Completion record

### Delivery, 2026-09-16: measured; retry roster verification parallelised (Fable, macOS checkout)

Implemented manually; no scheduled claim. New `tests/session_stall_probe.gd`
(headless, Standard mountain) records a synthetic 150 s eligible run
(3001 samples, 3001 poses, 4.48 MB payload, 0.82 MB compressed) and times the
three paths on the Apple M4 MacBook:

| Path | Measured before | After |
| --- | --- | --- |
| Finish: `Records.save` with one new ghost | 16.9 ms (`to_bytes` 1.3, SHA-256 11.7, Zstandard 3.2, write/manifest ~1) | unchanged |
| Crash: `crash_recovery.resolve`, five points along the descent | 0.29-0.63 ms when a candidate is found (1-6 candidates); 3.7 ms worst case (33 candidates rejected, unavailable) | unchanged |
| Retry: `Records.selected`, ten cached ghosts (read + hash 8 MB) | 20.3 ms | 9.1 ms |
| Retry: ten uncached ghosts (read, hash, decode) | 1384 ms | 1028 ms |

`Records.selected` now reads, hashes and (on a cache miss) decodes stored
payloads on `WorkerThreadPool` workers from immutable inputs; cache lookups,
`compressed_bytes_read`/`decodes` accounting, stores, discards and the roster
order stay on the calling thread in the original order, so results and the
integrity rules (hash the current compressed bytes before reuse, full decoder on
every new byte sequence) are unchanged. Cold decoding scales poorly across
workers because `Replay.from_bytes` is GDScript-bound; that path belongs to the
cold archive task.

Not changed, with reasons: the finish transaction stays synchronous. Its
measured cost is 17 ms for a 150 s run (about 70 ms for a 10 minute run),
dominated by SHA-256 of the payload, and moving it to a worker would make
`save_error` and the saved record appear later than `finalize_capture`, a
contract the racing suites assert. The analytic 100-500 ms estimate did not
reproduce. Crash placement is 0.3-3.7 ms, so spreading it over frames or reusing
a probe `Simulation` is not warranted. Size/mtime shortcuts for retries are
excluded by the cache contract (a same-length replacement must still hash).
Rows carrying an in-memory `replay` are re-serialised and re-hashed by every
save while they wait for their first commit (113 ms for ten such rows in the
probe); in the game only the new run carries one, so the finish pays once.

Automated (macOS, Godot 4.7.2): ghost_retry_cache_suite 37/37, ghost_archive_suite 119/119, race_suite 51/51, exact_clock_suite 95/95, crash_replay_suite 36/36, crash_recovery_suite 82/82, physics_suite 56/56, runtime_suite 192/192, interface_suite 83/83; competitive_suite 51/53 with both remaining failures (resume clock alignment, PB celebration title) identical on 26f033c before any of this day's Fable work. Its third failure, the finished race's split comparison read from the hidden HUD label, was a regression from Dev 67's hidden-instrument early return and is fixed here: personal-best and split text stay change-gated but update while menus hide them. Rendered check of the result
screen, crash menu and retry remains a follow-up.

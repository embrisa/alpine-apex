---
id: "AA-20260916-084511-reduce-finish-crash-restart-hitches"
title: "Take archive commits, crash placement search and roster hashing off the frame"
status: ready
priority: P2
depends_on: []
created: "2026-09-16T08:45:11Z"
updated: "2026-09-16T08:45:11Z"
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
  [the cold archive task](AA-20260912-132147-reduce-cold-ghost-archive-load.md);
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

Pending implementation. Record measured stalls before/after, identity
evidence, tests, guide updates and commit/push references.

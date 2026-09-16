---
id: "AA-20260912-132147-reduce-cold-ghost-archive-load"
title: "Reduce first-load stalls for long ghost archives"
status: ready
priority: P1
depends_on: []
created: "2026-09-12T13:21:47Z"
updated: "2026-09-16T21:59:44Z"
source_thread: null
---

# Reduce first-load stalls for long ghost archives

## Current disposition — 16 September 2026

Independent of the selector UI work: use the existing frozen ten-run roster.
Fable delivered parallel bounded payload read/hash/decode in `competitive_record.gd`
at `6586650a`. Its current-format 150-second synthetic fixture measured ten-ghost
loading at 1,384 to 1,028 ms cold and 20.3 to 9.1 ms cached. This is progress,
not resolution of first-load stalls. Attribute the remaining decoder/validation
work; do not repeat the already-delivered worker conversion or treat the old
47.6-second replay6 maximum as the current baseline. Runtime payload validation
and content invalidation remain required; manual source hash audits do not.

## Outcome

Load selected long recordings without the measured long first-attempt stall while retaining complete validation and fast retries.

## Current state and evidence

The historical replay 6/archive3 maximum of ten 600-second payloads took47.6 seconds cold versus 17.2 ms cached. This is not a current replay 7/archive4 timing claim. Current format small-cache 37 and exact-clock/archive/crash checks pass; cache hits rehash compressed content and share validated immutable data.

Originating tasks: [AA-20260911-220556-animated-ghost-snow-tracks](../blocked/AA-20260911-220556-animated-ghost-snow-tracks.md). Evidence: `artifacts/orchestration_20260912/ghost/RETRY_CACHE_HANDOFF.md`, `ghost/STATUS.md`, and `artifacts/ghost/retry_cache_results.json`. Measurements are from2026-09-12; private proposals and frozen captures are local, ignored evidence, not shipped dependencies. Recheck live source before applying a candidate.

## Agreed decisions and scope

The user explicitly requested this remaining work be saved for later, after stopping excessive agent/test usage. Authoring does not dispatch. Start with one worker and the smallest sufficient check; batch compatible checks, use the existing validation guard, and stop expanding coverage once the named criteria pass. Preserve120 Hz simulation,4 m terrain authority, personal records/preferences and current replay identities.

Primary owners: `scripts/racing/competitive_record.gd`, `run_replay.gd`, `ghost_replay_cache.gd`, `record_clock.gd`; `RunSession._freeze_ghosts()` and `tests/ghost_retry_cache_suite.gd`.

## Implementation approach

Profile the current format with the smallest representative existing compatible fixture first. Reuse compatible maximum data read-only; do not repeatedly regenerate ten maximum recordings or edit identity hashes to reuse obsolete data. Attribute I/O, decompression, parsing and validation before choosing a bounded optimization. Preserve ten entries,32 MiB per payload/320 MiB declared aggregate, identity/content invalidation, atomic saves, frozen attempt selection, exact clocks and rejection of malformed/old data. Threading or loading orchestration must keep Nodes/resources on their owning thread.

## Acceptance and verification

- [ ] Matched current-format cold and warm measurements identify and materially reduce the verified bottleneck; do not label cached retries a cold-load fix.
- [ ] Existing cache/archive/exact-clock/crash-replay checks pass, including same-size content changes, eviction/reset and malformed bounds.
- [ ] Memory/work remain bounded, missing fixtures fail honestly, and docs record actual remaining first-load latency.
- [ ] Record exact changed-source verification and commit/push the owned work with updated authoritative documentation.

Human acceptance: actual controller feel, listening and subjective visual approval remain separate follow-ups, not an unattended worker completion gate. Do not revive the cancelled broad player-acceptance task or claim the user tested these features.

## Open questions

None

## Completion record

Pending implementation. Record actual results, remaining limits, source/provenance and commit/push references. No worker is dispatched by this authoring change.

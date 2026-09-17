---
id: "AA-20260917-160840-use-scoped-benchmark-metadata"
title: "Use scoped metadata for production benchmark receipts"
status: done
priority: P2
depends_on: []
created: "2026-09-17T16:08:40Z"
updated: "2026-09-17T16:08:40Z"
source_thread: "01a0a5df-19c3-7783-81dc-eca18c340e4a"
---

# Use scoped metadata for production benchmark receipts

## Outcome

Production benchmark bookkeeping follows the economical metadata policy. The
user explicitly selected this idea for immediate work on 17 September, advancing
it ahead of the remaining backlog. No FPS baseline is required for this tooling.

## Current state and evidence

The prior `benchmark_pc.ps1` recursively read and hashed broad source folders
before/after each run and hashed the selected executable. The benchmark now
records sizes/mtime for an explicit runtime scope plus its producer dependencies,
trace, engine/worker and adjacent DLLs. Git branch/commit/status and current
model/world/replay/race versions provide context. Runtime compatibility is intact.

## Agreed decisions and scope

- Keep gameplay, replay/cache identity, effective settings, trace and focus gates.
- Detect scoped added/changed/deleted inputs; permit an already-dirty candidate.
- Unrelated Git changes are context, not automatic timing failures.
- Add a read-only launch plan; require existing FpsCritical/full-mountain admission
  for actual runs and fresh labels to prevent stale receipt reuse.
- Metadata is an ordinary-edit detector, not byte identity. Same-size edits with
  restored modification times are outside its guarantee.

## Implementation approach

`scripts/benchmark_metadata.py` owns snapshots and comparison;
`config/benchmark_metadata_scope.json` declares roots/fixed paths. Git enumerates
only those roots, and assets are statted rather than opened or hashed. Selected
test dependencies are read from literal test references. Explicit
`-MetadataPaths` supports dynamic inputs; custom scopes must cover their workload.
The engine resolver has an explicit metadata-only benchmark selection mode.
`rendering_baseline_report.py` accepts the new schema2 contract while keeping
historical receipts readable without rehashing source files.

## Acceptance and verification

- [x] Eight metadata/PowerShell fixtures pass: add/edit/delete/missing inputs,
  dirty starts, unrelated commits, trace/engine/DLL changes, literal scope paths,
  unchanged launch arguments and engine selection without binary hashing.
- [x] Fourteen receipt tests pass, including current metadata, historical receipts,
  drift/missing inputs, failed/partial runs, focus/endpoint/cache rejection.
- [x] Read-only live scope capture confirms actual model35/world17/replay7/race6
  and selected console/worker/SDK paths. No Godot workload or GPU baseline.
- [x] Performance skill and Validation guide updated; scoped milestone checked.

## Open questions

None.

## Completion record

Dev99 milestone. Commands:
`python -m unittest discover -s tests -p test_benchmark_metadata.py -v` and
`python -m unittest discover -s tests -p test_rendering_baseline_report.py -v`.
Compact evidence: `artifacts/scoped_benchmark_metadata/summary.json`.
No measured FPS or turnaround improvement is claimed. No new ideas were needed.

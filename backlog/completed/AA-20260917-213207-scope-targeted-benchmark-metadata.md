---
id: "AA-20260917-213207-scope-targeted-benchmark-metadata"
title: "Use scoped metadata in the local targeted benchmark"
status: done
priority: P2
depends_on: []
created: "2026-09-17T21:32:07Z"
updated: "2026-09-17T21:32:07Z"
source_thread: "01a0a5df-19c3-7783-81dc-eca18c340e4a"
---

# Use scoped metadata in the local targeted benchmark

## Outcome

Local component benchmarks use the existing production metadata helper instead
of recursively hashing source/assets and hashing the engine before/after runs.
The user explicitly selected this idea for immediate implementation, overriding
the backlog's normal phase order for this item.

## Current state and evidence

At Dev105, `tests/targeted_performance.gd` hashes scripts, graphics and config,
and `scripts/benchmark_targeted.ps1` compares that older schema. The production
helper `scripts/benchmark_metadata.py` already captures scoped paths, versions,
Git context and file size/mtime without content hashing.

## Agreed decisions and scope

Reuse that helper and its scope. Keep settings, fixture identity, ordinary input,
focus, native timing and runtime compatibility gates. Keep old saved results as
historical evidence. Metadata detects ordinary edits, not byte identity. This is
tooling overhead, not a demonstrated game-FPS bottleneck.

## Implementation approach

The native producer calls the common helper outside setup/measurement, retaining
original before/after/comparison sidecars. The wrapper selects the engine in
metadata-only mode, validates schema 2, rejects changed scoped inputs and checks
successive trials using original integer timestamps. Godot's parsed JSON is not
the authority for nanosecond comparisons. Both owning skills route to the updated
[validation contract](../../docs/VALIDATION.md#targeted-rendering-and-fps-maps).

## Acceptance and verification

- [x] No recursive source/asset or engine content hash in the targeted producer/wrapper.
- [x] Shared helper detects scoped edits/additions/removals and ignores unrelated documentation.
- [x] Synthetic wrapper rejects changed/missing/historical receipts and changed map/settings/pixels; focus/timing failures still reject.
- [x] Capture summaries remain non-performance evidence; default quality/admission/input plan is preserved.
- [x] Headless production metadata bridge and derived pole-cost producer parse pass.
- [x] Maintained guide/skills, idea destination, scoped development note and delivery checks included in this milestone.

## Open questions

None.

## Completion record

Eight shared-helper tests and four synthetic wrapper tests pass. The latter
include nine invalid-receipt subcases. A guarded headless metadata bridge on the
actual project records 6,777 scoped files with unchanged metadata and no failures;
it does not load the gameplay scene or measure FPS. The inherited pole cost
producer parses with the new base. No gameplay/rendering behavior changed and no
new baseline was recorded. Evidence: `artifacts/targeted_metadata_20260917/`.
Delivery is the commit containing this completed record and its Maintenance note.
No separate idea was added.

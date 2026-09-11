---
id: "AA-20260911-153900-baseline-acceptance-index"
title: "Refresh the current baseline and acceptance index"
status: "retired"
priority: "P1"
depends_on: []
created: "2026-09-11T15:39:00Z"
updated: "2026-09-11T19:06:07Z"
source_thread: "01a090fe-2a8c-7fe0-8b5b-fa6446206ea9"
---

# Refresh the current baseline and acceptance index

## Outcome

Make the project's entry-point documentation accurately describe the current game and outstanding acceptance work, so later agents start from current evidence.

## Current state and evidence

The imported [roadmap](../../docs/ROADMAP.md) and [documentation index](../../docs/README.md) still describe default mountain v14 and race schema 3. During backlog setup, [project guidance](../../AGENTS.md) and [validation](../../docs/VALIDATION.md) use v15; live ski simulation declares model 28 and race_definition.gd declares schema 4. These are inspection findings from 2026-09-11, not permanent version assumptions. Verify them again.

## Agreed decisions and scope

This is a documentation-only reconciliation of existing work. Update docs/README.md, docs/ROADMAP.md and docs/VALIDATION.md as needed; link maintained subsystem evidence instead of duplicating reports. Preserve player acceptance as open wherever it remains unverified. Do not change game behavior or claim fresh performance measurements.

## Implementation approach

Read current startup/generation, scripts/core/ski_simulation.gd, scripts/racing/race_definition.gd and scripts/racing/run_replay.gd. Resolve contradictory version/acceptance summaries against those sources and newer subsystem docs. Add a compact current acceptance checklist linking the imported backlog work. Keep historical measurements clearly dated rather than overwriting their original identities.

## Acceptance and verification

- [x] Entry-point default/version claims match the inspected live sources.
- [x] Historical results and outstanding player/controller acceptance remain distinct.
- [x] Relevant Markdown links resolve; run the backlog validator and git diff --check.
- [x] Commit/push the documentation and completion record; include inspected source commit references.

No game suites or new gameplay measurements are required for this documentation-only task. Human acceptance remains a follow-up, not a gate for this documentation task.

## Open questions

None.

## Completion record

Completed 2026-09-11. Documentation milestone
[`2ecd606d0cfc49a1b53c1773ef280a08e25b8321`](https://github.com/embrisa/alpine-apex/commit/2ecd606d0cfc49a1b53c1773ef280a08e25b8321)
was committed and pushed to `origin/main`; this completion record is the follow-up checkpoint.

Inspected source snapshot:
[`f7b44ed8cb71a5591dd45cdd70336340fc25cf3f`](https://github.com/embrisa/alpine-apex/commit/f7b44ed8cb71a5591dd45cdd70336340fc25cf3f).
Verified the project/main scene, startup, mountain definition, v15 generator/cache,
generation settings, ski simulation, race definition and replay files match that
commit byte-for-byte. Normal startup is seed 849205174 / v15 / Standard; physics
is model 28, replay is v5 with eight input fields, and race schema is 4.

Updated the documentation index, roadmap and validation guide; the
[current acceptance checklist](../../docs/VALIDATION.md#current-acceptance-checklist)
links all six imported follow-ups. Historical v13 routes, the dated v14/model-26
FPS comparison, model-28 short-route timings and v15 generation/scene diagnostics
remain distinct from current full-descent and player acceptance.

Verification: all 107 local Markdown links and heading anchors in the three
entry pages and this task resolve; source-constant checks pass;
`./scripts/backlog.ps1 validate` passes. Whitespace checking uses
`git -c core.whitespace=cr-at-eol diff --check` to recognize the existing Windows
line endings while preserving file bytes outside edited content.
No game suites, rendered runs or new performance measurements were required or
performed. Player/controller, listening, all-face skiing and current complete-descent
performance acceptance remain open in the linked follow-ups.

## Retirement

Retired at the user's request on 2026-09-11 after successful completion.
The completion record and evidence above remain valid. This task will not be
dispatched again; its satisfied prerequisite was removed from remaining tasks.

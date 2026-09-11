---
id: "AA-20260911-153900-baseline-acceptance-index"
title: "Refresh the current baseline and acceptance index"
status: "ready"
priority: "P1"
depends_on: []
created: "2026-09-11T15:39:00Z"
updated: "2026-09-11T15:39:00Z"
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

- [ ] Entry-point default/version claims match the inspected live sources.
- [ ] Historical results and outstanding player/controller acceptance remain distinct.
- [ ] Relevant Markdown links resolve; run the backlog validator and git diff --check.
- [ ] Commit/push the documentation and completion record; include inspected source commit references.

No game suites or new gameplay measurements are required for this documentation-only task. Human acceptance remains a follow-up, not a gate for this documentation task.

## Open questions

None.

## Completion record

Imported from the existing roadmap during backlog setup. Pending implementation. Any worker follow-up ideas belong in `backlog/ideas/` for the user's review.

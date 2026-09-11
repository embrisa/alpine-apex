---
id: "AA-20260911-153905-race-loop-acceptance-audit"
title: "Refresh race authoring and retry-loop acceptance evidence"
status: "ready"
priority: "P2"
depends_on: []
created: "2026-09-11T15:39:00Z"
updated: "2026-09-11T19:06:07Z"
source_thread: "01a090fe-2a8c-7fe0-8b5b-fa6446206ea9"
---

# Refresh race authoring and retry-loop acceptance evidence

## Outcome

Verify the current route-discovery, custom-race, retry, split and ghost loop and prepare a focused ordinary-player acceptance checklist.

## Current state and evidence

[The roadmap](../../docs/development/ROADMAP.md) leaves the usefulness of the racing loop open. [Competitive loop](../../docs/gameplay/COMPETITIVE_LOOP.md), [races](../../docs/gameplay/RACES.md), scripts/racing/ and tests/race_suite.gd describe current foundations. Race schema is declared in source and must be verified rather than copied from the old index.

## Agreed decisions and scope

Audit existing local/offline behavior. Preserve open-route racing, responsive input and test exclusion from personal bests. No leaderboard, networking, new race rule or persistence migration work. Test harness adjustments for current contracts are permitted; game behavior changes require a separate task.

## Implementation approach

Inspect session, race and replay identities and the harness before running it. Run the existing race suite in its required rendered/headless mode with isolated test saves, plus physics/runtime suites for the inspected input/session integration. Inspect the rendered authoring -> start -> retry -> finish/ghost transitions using current fixtures. Document exact gaps and repro steps rather than silently expanding features.

## Acceptance and verification

- [ ] Current race/session/replay identity and relevant suite results are recorded.
- [ ] Start/retry/splits/finish/ghost behavior has scoped rendered evidence or a precise blocker.
- [ ] Test runs do not create or replace personal bests.
- [ ] Update maintained race documentation and provide a short player checklist.
- [ ] Commit/push the evidence, any necessary test-only corrections, and the completion record.

Ordinary-player usefulness remains a separate user follow-up. Failed required checks need a blocker/reproducer rather than an unapproved game fix.

## Open questions

None.

## Completion record

Imported from the existing roadmap during backlog setup. Pending implementation. Any worker follow-up ideas belong in `backlog/ideas/` for the user's review.

## Satisfied prerequisite history

On 2026-09-11, [AA-20260911-153900-baseline-acceptance-index](../archive/AA-20260911-153900-baseline-acceptance-index.md) was retired at the user's request after completion. Its satisfied dependency was removed; this task's scope and acceptance requirements are unchanged.

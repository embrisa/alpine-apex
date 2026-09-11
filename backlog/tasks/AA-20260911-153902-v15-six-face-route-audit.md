---
id: "AA-20260911-153902-v15-six-face-route-audit"
title: "Establish current v15 route coverage on all six faces"
status: "ready"
priority: "P1"
depends_on: []
created: "2026-09-11T15:39:00Z"
updated: "2026-09-11T19:06:07Z"
source_thread: "01a090fe-2a8c-7fe0-8b5b-fa6446206ea9"
---

# Establish current v15 route coverage on all six faces

## Outcome

Replace reliance on historical v13/v14 route evidence with a reproducible default-v15 six-face survey and honest pilot coverage report.

## Current state and evidence

[Validation](../../docs/development/VALIDATION.md) still carries forward a v13 pilot completing one face while crashing or stalling on others. Existing tests/alpine_v13_route_survey.gd and tests/alpine_v14_routes.gd target historical identities; they do not establish current v15 coverage.

## Agreed decisions and scope

Use seed 849205174, current v15 Standard generation, and all six faces. This first audit is limited to the default seed. Preserve the shared 4 m support surface and normal rider inputs; do not alter terrain, hazards or ski physics to make the pilot pass. Additional seeds remain future user acceptance work.

## Implementation approach

Inspect the current generation and route-survey helpers. Add the smallest current-v15 test harness needed rather than modifying historical fixtures into misleading comparisons. Reuse MountainDefinition.generate(849205174, 15) or the validated v15 cache. Record per-face continuity, branch/rejoin coverage and support/obstacle checks. Attempt at most one bounded ordinary-input pilot run per face; report crashes/stalls as limitations. Keep route search outside any timing measurement.

## Acceptance and verification

- [ ] Reproducible survey output identifies current source hashes, generator/model, seed and settings.
- [ ] All six faces have explicit surveyed and pilot-completion statuses.
- [ ] Pilot failure is reported without equating it with proof of an unskiable mountain.
- [ ] Update docs/development/GENERATION_V15.md and the route acceptance summary with the result.
- [ ] Validate any new harness and run required regressions if its scope grows into input/session changes; commit/push the task evidence.

The audit may complete with documented pilot limitations if every face was investigated and no harness failure is hidden. User skiing of the faces and other seeds remains a separate acceptance task.

## Open questions

None.

## Completion record

Imported from the existing roadmap during backlog setup. Pending implementation. Any worker follow-up ideas belong in `backlog/ideas/` for the user's review.

## Satisfied prerequisite history

On 2026-09-11, [AA-20260911-153900-baseline-acceptance-index](../archive/AA-20260911-153900-baseline-acceptance-index.md) was retired at the user's request after completion. Its satisfied dependency was removed; this task's scope and acceptance requirements are unchanged.

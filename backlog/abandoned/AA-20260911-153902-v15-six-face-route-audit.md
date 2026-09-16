---
id: "AA-20260911-153902-v15-six-face-route-audit"
title: "Establish current v15 route coverage on all six faces"
status: retired
priority: P1
depends_on: []
created: "2026-09-11T15:39:00Z"
updated: "2026-09-12T08:37:43Z"
source_thread: "01a090fe-2a8c-7fe0-8b5b-fa6446206ea9"
---

# Establish current v15 route coverage on all six faces

## Outcome

Replace reliance on historical v13/v14 route evidence with a reproducible default-v15 six-face survey and honest pilot coverage report.

## Current state and evidence

Before this audit, [Validation](../../docs/VALIDATION.md#check-selection) carried forward a v13 pilot completing one face while crashing or stalling on others. Existing tests/alpine_v13_route_survey.gd and tests/alpine_v14_routes.gd did not establish current v15 coverage. The retained planner and pilot are now explicitly reused as test-only algorithms on the current v15 field; historical bake receipts are not reused.

## Agreed decisions and scope

Use seed 849205174, current v15 Standard generation, and all six faces. This first audit is limited to the default seed. Preserve the shared 4 m support surface and normal rider inputs; do not alter terrain, hazards or ski physics to make the pilot pass. Additional seeds remain future user acceptance work.

## Implementation approach

Inspect the current generation and route-survey helpers. Add the smallest current-v15 test harness needed rather than modifying historical fixtures into misleading comparisons. Reuse MountainDefinition.generate(849205174, 15) or the validated v15 cache. Record per-face continuity, branch/rejoin coverage and support/obstacle checks. Attempt at most one bounded ordinary-input pilot run per face; report crashes/stalls as limitations. Keep route search outside any timing measurement.

## Acceptance and verification

- [x] Reproducible survey output identifies current source hashes, generator/model, seed and settings.
- [x] All six faces have explicit surveyed and pilot-completion statuses.
- [x] Pilot failure is reported without equating it with proof of an unskiable mountain.
- [x] Update docs/WORLD.md and the route acceptance summary with the result.
- [x] Validate any new harness and run required regressions if its scope grows into input/session changes; commit/push the task evidence.

The audit may complete with documented pilot limitations if every face was investigated and no harness failure is hidden. User skiing of the faces and other seeds remains a separate acceptance task.

## Open questions

None.

## Completion record

Completed manually on 2026-09-11. Implementation and evidence were committed and
pushed to main in `8bd07ea` ("Audit default v15 routes and bounded pilots on all
six faces"). The closure also makes the receipt producer emit LF consistently.

- Added [the current-v15 harness](../../tests/alpine_v15_route_audit.gd) and
  [receipt producer](../../tests/report_v15_route_audit.py). The
  [committed receipt](../../docs/V15_ROUTE_AUDIT_RESULTS.json) identifies seed
  849205174, generator 15, Standard settings, model 28, 71 source hashes, engine
  and terrain identities, the validated cache and detailed artifact hashes.
- All six faces returned two sampled paths with zero production tree/mineral
  sweep hits: 13,962 finite support samples and 11,126 swept segments. Branch
  alternatives and graph rejoin counts are reported with their sampling limits.
- Exactly one normal-launch, ordinary-input pilot ran per face. Face labels
  1–4 and 6 completed; face 5 (index 4) stalled without crashing at 72.05% maximum
  radial progress. This limits pilot coverage and does not prove unskiability.
  Alternate paths and deliberate branch/rejoin skiing were not piloted.
- The guarded parse check and full audit passed, with no engine/harness errors
  and stable source hashes. Receipt validation, local guide links/anchors and
  the 17 backlog helper tests passed; backlog metadata/dependencies validate.
  The scope remained test/evidence/documentation only, so production
  physics/runtime regressions and rendered checks were not required or rerun.
- [World](../../docs/WORLD.md#default-v15-route-audit) owns the result and exact
  reproduction commands; [Validation](../../docs/VALIDATION.md#mountain-evidence)
  now points to current evidence. Detailed outputs remain ignored under
  `artifacts/v15_route_audit/` and `artifacts/guarded/v15-route-audit/`.

No terrain, hazard, input/session or ski-physics implementation was changed.
Rendered/performance and human/controller acceptance were not established.
User skiing of all faces and other seeds remains separate acceptance work.

## Satisfied prerequisite history

On 2026-09-11, [AA-20260911-153900-baseline-acceptance-index](AA-20260911-153900-baseline-acceptance-index.md) was retired at the user's request after completion. Its satisfied dependency was removed; this task's scope and acceptance requirements are unchanged.

## Retirement

Retired at the user's request on 2026-09-12 after recorded completion.
The completion evidence, delivery history and unresolved findings above remain
retained. Retirement does not establish additional performance, visual, listening
or human/controller acceptance. No replacement implementation task is needed
for this completed scope; satisfied dependencies are retained as history in
remaining tasks.

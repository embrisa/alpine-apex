---
id: "AA-20260911-155000-agent-backlog-system"
title: "Install the Alpine Apex agent backlog and authoring skill"
status: "retired"
priority: "P1"
depends_on: []
created: "2026-09-11T15:00:00Z"
updated: "2026-09-12T08:37:43Z"
source_thread: "01a090fe-2a8c-7fe0-8b5b-fa6446206ea9"
---

# Install the Alpine Apex agent backlog and authoring skill

## Outcome and agreed decisions

Install file-based task authoring, scheduled grooming and independent implementation
handoff for the existing project. The user chose a fresh manager every 30 minutes,
Astra High for management and Astra Extra High for workers, local main-branch
work, ready-on-save authoring, broad backlog editing, and manager failure-only
notifications. Blocked work may be set aside once the checkout is safe. Only
scheduled workers use ownership; manual agents retain their normal workflow.

The authoring skill investigates and asks material questions in an ordinary chat,
then writes when settled, without requiring explicit Plan Mode or another save
approval. Active mode restrictions still apply if Plan Mode is selected.
Worker suggestions go into a separate ideas folder for the user's decision and
are never automatically promoted or dispatched.

## Implementation and scope

- Project-local `$alpine-backlog` skill, task and idea templates, and AGENTS routing.
- Backlog conventions, bounded manager and worker prompts, and recovery instructions.
- Python standard-library ownership/validation helper with a PowerShell entrypoint.
- Six ready imported evidence tasks and one blocked human acceptance task; completed
  or superseded animation handoffs remain references.
- Standalone local native automation, activated after verification. Machine-specific
  configuration and test receipts are kept in ignored local output.

No game behavior, subagent configuration, existing task ownership or user settings
were changed. This installation does not implement the queued gameplay audits.

## Acceptance and verification

- [x] All 17 isolated helper integration tests pass, including simultaneous claims,
  stale/uncertain ownership, task-content changes, dependency validation, pushed
  completion, manual-start races, dirty checkout gates and idea exclusion.
- [x] Skill validator, interface metadata and both template YAML checks pass.
- [x] Backlog metadata and local Markdown links validate; Git whitespace checks pass.
- [x] A live production preflight skips the active out-of-bounds implementation.
- [x] A native independent Astra Extra High task completes the isolated documentation
  fixture, pushes to its local bare origin, records done and releases ownership.
- [x] The native automation is saved with the chosen project, model, reasoning,
  cadence and notification policy, then activated through the scheduling tool.

The live worker was `01a09125-7f30-7021-860b-e356e4727626`; its fixture delivery was
`5b215d90a6cc97ca96b450f3fa174525bb02c5b1`. The inspected state records a null claim
and matching done receipt, with fixture HEAD equal to origin/main. Evidence is
local under `artifacts/backlog_setup/live-smoke-20260911/`. This establishes native
orchestration and documentation handoff, not game quality or rendered performance.
Automatic timed firing itself has not yet been observed at installation completion.

## Open questions

None.

## Completion record

Source, skill, imported tasks and tests were committed and pushed in `71e16fe`.
This archived completion and the linked idea are the closure documentation milestone.
All checks above describe the implemented behavior and inspected evidence.

Production dispatch remains intentionally conditional on live activity and a clean
checkout. Four pre-existing untracked UID companion files were preserved; their
source files exist and are tracked. They prevent dispatch after other active work
ends until resolved. The remaining manual-start race and recent-list limit are
documented in [operations](../OPERATIONS.md).

Next-step idea for the user's review:
[resolve the existing untracked UID companions](../ideas/archive/IDEA-20260911-155000-uid-companions.md).

## Retirement

Retired at the user's request on 2026-09-12 after recorded completion.
The completion evidence, delivery history and unresolved findings above remain
retained. Retirement does not establish additional performance, visual, listening
or human/controller acceptance. No replacement implementation task is needed
for this completed scope; satisfied dependencies are retained as history in
remaining tasks.

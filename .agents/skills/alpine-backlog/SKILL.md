---
name: alpine-backlog
description: Investigate Alpine Apex ideas, discuss requirements and tradeoffs with the user, and write or refine actionable backlog task files. Use when the user wants to turn a vision, feature, bug, or improvement into work for a later agent, including requests to plan something for the backlog. Task implementation and scheduled backlog management are separate workflows.
---

# Alpine backlog authoring

Read [AGENTS](../../../AGENTS.md) and [task conventions](../../../backlog/README.md).
Authoring investigates, settles material decisions and saves a task; it does not
implement, dispatch, configure scheduling or groom unrelated work.

1. Inspect current source, tests, owning guides and relevant evidence. Search
   active/archived tasks and ideas for overlaps or superseded work. Refine an
   existing task when appropriate; never rewrite a worker-owned task. Use bounded
   read-only probes and the project workload guard.
2. Establish the player outcome, scope, constraints, ownership/interfaces,
   implementation direction and observable acceptance. Discuss material product
   or architecture choices in small rounds; reuse prior answers. Routine choices
   belong to the implementer. Verify code facts directly. An unanswered essential
   question remains open; continue independent investigation while awaiting it.
3. Once settled, save without another approval round. `ready` authorizes later
   dispatch after dependencies complete. Use `draft` only when the user asks to
   preserve unfinished discussion; never promote unresolved choices. Specify
   whether human playtesting is a completion gate or separately pending acceptance.
4. Use [the template](assets/task-template.md) and stable UTC
   `AA-YYYYMMDD-HHMMSS-short-slug.md` in `backlog/tasks/`; append a numeric suffix
   on collision. Preserve existing IDs/intent. Record current source evidence,
   agreed boundaries, exact repro/verification, known originating task ID (else
   null), dependencies and a worker completion section. Planned checks stay planned.
5. Read back, remove ready-task placeholders/open decisions, validate with
   `./scripts/backlog.ps1 validate`, then commit/push under project policy. Report
   the saved file, status and any blocker; end authoring.

Selecting a worker idea starts investigation, not automatic queue promotion.
Read its origin; mark it accepted with a link only after the resulting task
exists. Record rejection only on the user's decision. Preserve rationale and
follow [idea archival rules](../../../backlog/ideas/README.md).

In Plan Mode or another write-forbidden mode, finish the decision-ready proposal
in the conversation and explain that saving requires a write-enabled mode. Do
not bypass this through another tool or delegate. A later instruction to save
authorizes the agreed task file, not feature implementation.

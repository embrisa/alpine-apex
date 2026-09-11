---
name: alpine-backlog
description: Investigate Alpine Apex ideas, discuss requirements and tradeoffs with the user, and write or refine actionable backlog task files. Use when the user wants to turn a vision, feature, bug, or improvement into work for a later agent, including requests to plan something for the backlog. Task implementation and scheduled backlog management are separate workflows.
---

# Alpine backlog task authoring

Turn the user's vision into a task another agent can complete without the planning
conversation. Investigate, discuss, then save when the important questions are
settled. Use an ordinary chat; explicit Plan Mode is not required. Authoring a
task does not include implementing it or launching a worker.

Use this project-local skill from the Alpine Apex repository. Read the current
[project guidance](../../../AGENTS.md) and [backlog conventions](../../../backlog/README.md).
Treat the user's answers and decisions from this conversation as established;
do not ask them to approve the same choices again.

When the user selects a proposal from `backlog/ideas/`, read it and its originating
task as investigation context. Selection authorizes discussing that idea, not
silently copying it to the ready queue. Settle any material open questions as
usual, then save the resulting task. Mark the idea `accepted` and link the saved
task only after it exists. Record rejection only when the user rejects the idea.
Unselected ideas remain for user review; do not convert them on your own.

## Investigate before asking

- Find the current implementation, relevant tests, and maintained subsystem docs.
  Inspect the actual behavior and architecture that the proposed change touches.
  Use the applicable project skill when specialized investigation needs it.
- Search the backlog, its archive if present, and `docs/tasks/` for overlapping,
  completed, or superseded work. Inspect relevant newer evidence before treating
  an old handoff as unfinished. If the same task exists, refine it instead of
  creating a duplicate; do not rewrite a task an implementation worker owns.
- Keep investigation bounded to the idea. Use read-only inspection and useful
  non-mutating probes; follow the project's validation guard for any test run.
  Record concrete findings and their source paths. Distinguish observed behavior,
  historical measurements, and hypotheses. Recheck relevant live versions instead
  of copying dated generator or model numbers into the task.
- Discover facts in the codebase rather than asking the user where code lives or
  which established component to use. An obvious ambiguity in the request itself
  may need a question before useful investigation is possible.

## Discuss the decisions that matter

Use a conversation, not a fixed questionnaire. Start with a brief account of what
exists and the choices the investigation exposed. Ask focused questions in small
rounds, then investigate further when an answer changes the approach.

- Settle the intended player/user outcome, observable success, scope, constraints,
  and important tradeoffs. Preserve concrete visual feedback and gameplay wording.
- Next settle the implementation approach, affected interfaces and ownership,
  dependencies, meaningful failure cases, and how the result will be verified.
  Scale technical detail to the change; leave routine coding decisions to the
  implementer, but do not leave product choices or major architecture undecided.
- Prefer the available question tool when permitted by the current mode. Offer
  meaningful alternatives and a recommendation when comparing options helps.
  Use free text for a vision that cannot be expressed usefully as choices.
- Ask questions that change the task or resolve an important unknown. Reuse
  answers already supplied; do not manufacture questions to fill a quota. A broad
  vision requires discussion, not silently choosing its scope and saving a plan.
- An unanswered essential question remains unresolved. Continue independent
  investigation while awaiting the answer; elapsed time is not an answer. State
  reasonable low-impact defaults explicitly instead of turning them into more
  approval gates.

## Decide when the task is ready

Save once the conversation establishes a coherent outcome, bounded scope,
implementation direction, acceptance criteria, and verification method, with no
unresolved decisions that would materially change the work. Do not add a final
"Should I save this?" or "May I proceed?" round: the request to create the backlog
task already authorizes saving it when these conditions are met.

Use `ready` for an agreed, actionable task. This status authorizes a future
dispatcher to implement it without another approval step. Concrete dependencies
may be listed without changing it to a draft; dispatch must wait for them.
Use `draft` only when the user asks to preserve an unfinished discussion. Keep its
open questions explicit. Do not silently mark an unsettled idea `ready`.

Human playtesting can be part of the acceptance plan without making the design
unsettled. Specify which evidence the worker can produce and which acceptance
remains for the user, including whether that acceptance is required to finish the
task. A user decision needed before implementation belongs in the open questions.

**Respect the active mode.** If Plan Mode or another higher-priority instruction
forbids file writes, complete the decision-ready proposed plan in the conversation
and explain that saving needs a switch to a mode that permits writing. Do not
write through another tool or delegate the write to bypass the restriction. When
the user switches modes to save, write only the agreed backlog task; do not start
implementing the feature as a side effect.

## Write and hand off

1. Read [the task template](assets/task-template.md) when preparing the file.
   Follow any newer established backlog format; otherwise use this template.
2. Save under `backlog/tasks/`. Create that directory if needed. Use a stable ID
   and filename `AA-YYYYMMDD-HHMMSS-short-slug.md`, with the timestamp in UTC.
   Check for collisions before creating; append a numeric suffix if necessary.
   Preserve the ID and original intent when refining an existing task.
3. Make the task self-contained: summarize investigation findings, record agreed
   decisions and boundaries, link relevant source/docs, and give concrete expected
   behavior and verification. Use repository-relative references for portability.
   Include exact repro steps or measurements when they establish the problem.
   Link the source conversation by its known ID; use `null` if unavailable.
4. Include applicable project validation requirements without copying all of
   `AGENTS.md`. Separate automated, rendered, performance, and human acceptance.
   Describe planned checks as planned; never mark unperformed verification passed.
   Include a completion record for the worker's evidence and commit references.
5. Read the saved file back. Check that metadata matches the body, dependencies
   resolve, references are correct, and no template placeholders or material open
   questions remain in a `ready` task. Run `./scripts/backlog.ps1 validate`.
   Keep the writing proportionate to the work.
6. Follow the project's Git policy for the task-file milestone, preserving other
   agents' edits. Report the saved file with a clickable absolute path, its status,
   and any material unresolved issue or push blocker. End the authoring task.

Do not create unrelated tasks, import the whole roadmap, reprioritize other work,
configure scheduling, or dispatch an implementation task merely because this
skill was invoked. Those actions require their own user request.

# Alpine Apex backlog

Use `$alpine-backlog` to turn an idea into a task for a later implementation agent.
The [authoring skill](../.agents/skills/alpine-backlog/SKILL.md) investigates the
codebase, discusses important choices with you, then saves the task when settled.

For example: "Use $alpine-backlog to plan better visibility during heavy snow."

Use an ordinary chat: the skill saves as soon as the important questions are
settled, without a separate save-approval round. Explicit Plan Mode is optional;
if selected, its write restriction still applies until you leave it. Saving a
ready task authorizes later dispatch but does not immediately launch a worker.

The [manager](MANAGER.md) runs every 30 minutes and hands one task to an independent
[worker](WORKER.md) when the project is idle and its checkout is clean. See
[operation and recovery](OPERATIONS.md) for ownership, commands, scheduling and
limitations, and [the initial import](IMPORT.md) for the source of the first tasks.
Workers can propose follow-ups in [ideas for your review](ideas/README.md). These
stay outside the executable queue until you choose which to turn into tasks.

## Task files

Tasks live in `backlog/tasks/`, created when the first task is saved. The bundled
[template](../.agents/skills/alpine-backlog/assets/task-template.md) defines the
initial format: YAML metadata followed by the outcome, evidence, agreed scope,
implementation approach, acceptance, open questions, and completion record.

IDs and filenames use `AA-YYYYMMDD-HHMMSS-short-slug`, based on UTC creation time.
Keep IDs stable. `depends_on` contains task IDs, including archived IDs where
applicable. Timestamps are quoted ISO 8601 UTC strings. `source_thread` is the
known originating Codex task ID or `null`; do not invent one.

Metadata uses one field per line: JSON-quoted strings and UTC timestamps, a JSON
array for dependencies, and `null` for an unknown source. Status/priority may be
bare tokens. Multiline YAML scalars, aliases, extra keys and comments inside the
frontmatter are not supported by the dependency-free validator. Put discussion
and additional context in the Markdown body. Run `./scripts/backlog.ps1 validate`
before committing a new or revised task.

| Status | Meaning |
|---|---|
| `draft` | Preserved unfinished discussion; not authorized for dispatch. |
| `ready` | Agreed and actionable; authorized for implementation when dependencies are done. |
| `in_progress` | Claimed by an implementation worker; authoring agents must not rewrite it. |
| `blocked` | Implementation cannot proceed; the reason and remaining work are recorded. |
| `done` | The defined completion criteria are met, with evidence and commit references. |
| `retired` | Superseded or no longer useful; the reason and any replacement are recorded. |

Use priorities `P0` (urgent correctness/blocker), `P1` (high), `P2` (normal), or
`P3` (low). Default new tasks to `P2` unless the discussion or evidence establishes
a different priority. The authoring skill does not reprioritize unrelated work.

Move completed or retired tasks out of `backlog/tasks/` into `backlog/archive/`.
Preserve IDs, status, reasons and completion evidence, and update incoming and
outgoing relative links. Archived IDs remain available to dependency validation.
When retiring a completed prerequisite, remove its already-satisfied dependency
from remaining tasks and retain a history link so their eligibility is preserved.
Closed ideas use the separate `backlog/ideas/archive/` folder; see
[idea conventions](ideas/README.md). Do not treat old `docs/tasks/` handoffs as
ready work without checking their status and newer evidence.

A ready task must contain no unresolved decisions that materially change its
implementation. Record routine assumptions explicitly. Keep automated verification
and human acceptance separate, and specify any required human completion gate.

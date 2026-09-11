# Backlog contract

Use [alpine-backlog](../.agents/skills/alpine-backlog/SKILL.md) to investigate and
save agreed work for a later agent. A ready task authorizes later dispatch;
authoring does not launch it. Scheduled agents use [operations](OPERATIONS.md)
and their [manager](MANAGER.md)/[worker](WORKER.md) role. Manual agents use AGENTS.
Worker proposals stay in [ideas](ideas/README.md); [IMPORT](IMPORT.md) records the
initial queue's origin.

## Task files

Use [the task template](../.agents/skills/alpine-backlog/assets/task-template.md)
in `backlog/tasks/`. IDs/filenames are stable `AA-YYYYMMDD-HHMMSS-short-slug`
using UTC creation time. `depends_on` lists task IDs, including archived IDs;
`source_thread` is the known origin ID or null.

The dependency-free parser accepts one field per line: JSON-quoted strings/UTC
timestamps, JSON-array dependencies and null; status/priority may be bare tokens.
No multiline YAML, aliases, extra keys or frontmatter comments. Put context in
the body. Keep the template's metadata and outcome/evidence/scope/approach/
acceptance/open-questions/completion sections. Validate every revision:

```powershell
./scripts/backlog.ps1 validate
```

| Status | Contract |
|---|---|
| `draft` | User-requested unfinished discussion; no dispatch authorization |
| `ready` | Agreed actionable scope; dispatch waits for completed dependencies |
| `in_progress` | Worker-owned; authoring agents must not rewrite |
| `blocked` | Record blocker and remaining work; no automatic retry |
| `done` | Defined completion criteria met, with evidence/commit references |
| `retired` | Record reason and replacement, if any; not a completed prerequisite |

Priorities: P0 urgent correctness/blocker, P1 high, P2 normal (default), P3 low.
Ready tasks have no material unresolved decisions; explicitly distinguish worker
verification from human acceptance and identify any human completion gate.

Move done/retired tasks to `backlog/archive/`, retaining IDs, status, reasons and
completion records; repair incoming and relative outgoing links. Archived IDs
remain dependency-valid. If retiring an already completed prerequisite, remove
its satisfied dependency coherently and retain a history link so eligibility is
preserved. Closed ideas have a separate archive and never enter the task queue.

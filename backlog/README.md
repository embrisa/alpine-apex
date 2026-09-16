# Backlog contract

Use [alpine-backlog](../.agents/skills/alpine-backlog/SKILL.md) to investigate and
save agreed work for a later agent. A ready task authorizes later dispatch;
authoring does not launch it. Scheduled agents use [operations](OPERATIONS.md)
and their [manager](MANAGER.md)/[worker](WORKER.md) role. Manual agents use AGENTS.
Worker proposals stay in [ideas](ideas/README.md); [IMPORT](IMPORT.md) records the
initial queue's origin.

Start with the grouped [current queue](QUEUE.md). Task files are authoritative;
the index is a navigation aid, not a second status store.

## Task files

Use [the task template](../.agents/skills/alpine-backlog/assets/task-template.md)
in `backlog/tasks/`. IDs/filenames are stable `AA-YYYYMMDD-HHMMSS-short-slug`
using UTC creation time. `depends_on` lists task IDs from any task folder;
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

| Folder | Contents |
|---|---|
| [tasks/](tasks/) | `draft`, `ready`, `in_progress` work |
| [completed/](completed/) | `done` work, including completed investigations with a rejected candidate |
| [blocked/](blocked/) | `blocked` work with the blocker, remaining scope and explicit resume condition |
| [abandoned/](abandoned/) | `retired` work: cancelled, superseded or consolidated; preserve the reason and replacement |

Keep IDs and filenames stable when moving records; repair incoming and relative
outgoing links. The helper loads all four folders, validates folder/status
agreement and reserves all possible destinations for a worker-owned task.
Only `done` satisfies a dependency. A blocked or abandoned record never becomes
eligible merely because it moved. To resume blocked work, resolve its recorded
blocker or obtain an explicit retry decision, then update its scope/status and
move it back to `tasks/`. Never mark cancelled work successful to free dependents.

When consolidating, retain the original record and link the task that owns each
remaining outcome. Preserve dated failed experiments and separate human acceptance
from delivered implementation. Historical milestone notes remain immutable even
when their old task paths move; resolve those paths by the stable task ID.
Closed ideas keep their separate `ideas/archive/` and never enter the task queue.

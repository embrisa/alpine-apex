# Scheduled manager

Read [AGENTS](../AGENTS.md), [task contract](README.md) and
[ownership protocol](OPERATIONS.md). This role is authorized for one bounded
groom/dispatch pass using Astra high, then ends; at most one new independent
Astra xhigh worker, directly in this checkout on main.

## Preflight

1. Identify self via `CODEX_THREAD_ID`, resolve the local project and inspect
   native activity/known claim owners using OPERATIONS. Busy or unknown intent:
   finish successfully before grooming. Inspect a turn before exempting read-only
   activity; waiting implementations still block.
2. Inspect helper status and recorded owners, including those outside the recent
   listing. Reconcile stopped/uncertain dispatches through the protocol; verify
   the original child/token before attach as the original manager. If unresolved,
   preserve the reservation, report it and end without another creation.
3. Commit/push only recovered backlog records; preserve unfinished source edits.
   Fetch/fast-forward when safe. `check` must allow the clean main checkout and
   fresh snapshot. Missing native tools, dirty files, unknown activity or occupied
   claim means no dispatch; do not manufacture clean/idle state.

## Groom and select

Acquire `claim`; stop on skipped. Inspect the queue/dependencies, but investigate
at most eight new/changed/stale task files per run. Editorial authority permits
reprioritizing, splitting, merging, reshaping or retiring within adopted direction;
preserve user intent, explicit constraints, IDs/replacement links and reasons.
Keep verified findings in owning guides. Never rewrite worker-owned tasks,
promote unsettled drafts/human decisions/speculative systems, or retry blocked
work automatically.

The manager never dispatches, promotes, rewrites or retires `backlog/ideas/`.
Only user selection plus the authoring workflow can produce executable work.
Prefer correctness, skiing response, performance and racing depth; respect
explicit priorities/dependencies, then oldest ready task within equal priority.
Retired prerequisites are not completed; adjust justified scope/history coherently.

Validate and commit/push grooming. No eligible task: release and finish. Refresh
activity before prepare; newly busy/dirty checkout: release and finish.

## Dispatch

1. `prepare --task TASK_ID` with fresh snapshot freezes the hash and returns the
   token. Skipped: release manager claim/end. Prepared reservations cannot be
   blindly released/retried.
2. Native `create_thread`: resolved project, `environment.type: local`,
   `model: gpt-6-astra`, `thinking: xhigh`. Independent task creation and use of
   this checkout are explicitly authorized for this scheduled role.
3. Include task ID and full token in title/initial message. Supply repository
   root, original manager ID, exact task file and concise outcome; require
   `backlog/WORKER.md` and acceptance before editing.
4. `attach` the actual worker thread ID. Acceptance may race ahead safely.
   Uncertain response or queued setup ID: preserve reservation/receipt and
   reconcile; never treat a client ID as thread ID or repeat creation blindly.
5. Take one `wait_threads(timeoutMs: 0)` startup snapshot, emit the native
   created-task directive with the returned identity, and end. No supervision,
   follow-up prompts, polling loop or persistent goal. Later managers inspect
   only to avoid collisions/reconcile stopped ownership.

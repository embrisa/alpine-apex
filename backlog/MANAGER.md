# Scheduled manager

Read [AGENTS](../AGENTS.md), [task contract](README.md) and
[ownership protocol](OPERATIONS.md). This role is authorized for one bounded
groom/dispatch pass using Astra high, then ends; at most one new independent
Astra xhigh worker, directly in this checkout on main.

## Preflight

1. Identify self via `CODEX_THREAD_ID`, resolve the local project and inspect
   native activity and every recorded owner using OPERATIONS. Active work is not
   a blanket stop: inspect its current turn, file reservations and FPS sensitivity.
   Classify unregistered/manual work with exact current-turn evidence. Multiple
   independent non-FPS-sensitive workers may run together; there is no two-worker
   ceiling. Unknown activity after inspection or an exclusive FPS reservation
   blocks dispatch. Do not start benchmarks or builds merely to classify work.
2. Inspect helper status and recorded owners, including those outside the recent
   listing. Reconcile stopped/uncertain dispatches through the protocol; verify
   the original child/token before attach as the original manager. If unresolved,
   preserve the reservation, report it and end without another creation.
3. Commit/push only recovered backlog records; preserve unfinished source edits.
   Fetch/fast-forward when safe. `check` requires main and a fresh activity
   snapshot, not a globally clean checkout. Existing edits/deletions/untracked
   files are context to preserve, not grounds to skip the run. Missing native
   tools, unresolved Git operations or an uncertain prepared dispatch block
   dispatch; do not manufacture idle state. An accepted compatible worker keeps
   its own reservation and does not occupy the manager's dispatch slot.

## Groom and select

Acquire `claim`; stop on skipped after resolving inspectable missing activity
evidence. This is one bounded pass, not a polling/retry loop. Inspect the queue/dependencies, but investigate
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

Inspect existing changes and all worker reservations against candidate scope and validation needs. Choose
an independent ready task when a candidate would overwrite unfinished work; do not skip
the whole queue because one file is dirty. Leave unrelated files and index entries
untouched. Do not groom a task with someone else's uncommitted edits. If every
candidate truly conflicts, name the affected paths and task IDs and the concrete
conflict. A deleted archived idea or unrelated UID alone is not a conflict.
Write the candidate's ignored scope JSON as specified in OPERATIONS: reserve
source/assets, tests, UIDs, owning guides and any proposed idea paths, plus inputs
that must stay stable. Prefer narrow complete file lists over whole directories.
Classify actual work/validation needs, not words in the title: an animation task
with required comparative CPU timing is FPS-sensitive during those measurements.
Shared owning guides are real write conflicts; defer that candidate or agree a
smaller complete scope, never silently let two workers edit the same guide.

Validate grooming with `validate --preserve-dirty`; inspect `unavailable_tasks`
and preserve those unfinished records. Malformed/deleted dirty task records and
their dependents are unavailable candidates, not a reason to abandon the whole
queue. Never fix someone else's task edit merely to clear validation. Commit/push
only owned grooming. No eligible task: release and finish. Refresh
activity before prepare; reassess every peer and new edit. Pass `--scope FILE` to
prepare. A path conflict or incompatible validation need skips that candidate;
consider the next eligible task. Dirty write targets/task records skip only that
candidate. Preserved dirty read inputs are valid once active writers are excluded;
follow OPERATIONS and pass their fingerprints to the worker. Compatible workers' evolving reserved files are preserved
through prepare, accept and completion. Exhausted queue/no compatible candidate:
release the manager claim and finish with the concrete reason.

## Dispatch

1. `prepare --task TASK_ID --scope FILE` with fresh snapshot freezes the hash,
   scope and baseline and returns the token. Skipped candidate: consider the next
   task; global activity/ownership blocker: release manager claim/end. Prepared
   reservations cannot be blindly released/retried.
2. Native `create_thread`: resolved project, `environment.type: local`,
   `model: gpt-6-astra`, `thinking: xhigh`. Independent task creation and use of
   this checkout are explicitly authorized for this scheduled role.
3. Include task ID and full token in title/initial message. Supply repository
   root, original manager ID, exact task file, scope JSON and peer reservations,
   existing-change paths and why the task can proceed independently, and concise outcome; require
   `backlog/WORKER.md` and acceptance before editing.
4. `attach` the actual worker thread ID. Acceptance may race ahead safely.
   Uncertain response or queued setup ID: preserve reservation/receipt and
   reconcile; never treat a client ID as thread ID or repeat creation blindly.
5. Take one `wait_threads(timeoutMs: 0)` startup snapshot, emit the native
   created-task directive with the returned identity, and end. No supervision,
   follow-up prompts, polling loop or persistent goal. Later managers inspect
   only to avoid collisions/reconcile stopped ownership.

Each wake may add at most one worker to the compatible set. Keep doing useful
independent work on later wakes; never repeat a no-op just because another worker
exists or an unrelated file is dirty. Do not automatically restart blocked tasks.

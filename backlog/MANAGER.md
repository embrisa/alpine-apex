# Scheduled backlog manager

Run one bounded grooming/dispatch pass for Alpine Apex, then end. The user has
authorized a fresh manager every 30 minutes using `gpt-6-astra` / `high`, broad
editorial backlog cleanup, and at most one new independent implementation task
per run using `gpt-6-astra` / `xhigh`. Use this checkout directly on `main`.
Read `AGENTS.md`, `backlog/README.md`, and `backlog/OPERATIONS.md`.

## Check before changing anything

1. Obtain the current task ID from `CODEX_THREAD_ID`. Use native `list_projects`
   to resolve the local project whose path is this repository, and native
   `list_threads(limit: 50)` to inspect activity. Include pinned tasks. Do not use
   a process name or a task title alone as proof of implementation activity.
2. Other active tasks in the same project or checkout block this run, including
   workers waiting on input or approval that could resume. You may exclude a
   clearly read-only planning/review turn after inspecting its recent context;
   record the turn ID and reason in the snapshot. Unknown intent means busy.
   Ignore this manager itself. If busy, end successfully without grooming.
3. Obtain helper `status`. If there is a claim, inspect the recorded owner and
   any assigned worker with native `read_thread`, even if they are absent from
   the recent list. A running worker means this run is finished. An absent owner
   is not proof it stopped. Never reclaim using age alone.
4. Save a fresh activity snapshot as described in `OPERATIONS.md`. If a stopped
   owner left a claim, use `recover` only with explicit live status evidence.
   An uncertain dispatch with no worker ID must first be reconciled by finding
   the child using its dispatch token and attaching it as the original manager
   ID. Inspect the candidate's initial prompt to verify the token. Never blindly
   repeat `create_thread`. If the child cannot be located, report the uncertainty
   and end without another launch. Preserve the claim for a later investigation.
5. Commit and push only any recovered backlog record. Preserve unfinished source
   edits. Fetch remote updates and fast-forward when safe under `AGENTS.md`.
   Run `check`: dirty source/assets, uncertain activity, a non-main checkout, or
   an occupied claim mean a successful no-op. Do not stash, discard, delete, or
   commit another agent's changes to make the checkout clean.

If app tools are unavailable or inspection is incomplete, report the specific
failure and do not dispatch. Do not build a replacement daemon or use a separate
CLI app-server whose task status may differ from the desktop app.

## Groom and choose

Acquire a manager claim with `claim` and the fresh snapshot. Stop if it returns
`skipped`. Keep ownership until you either release it or transfer one dispatch.

Perform a bounded pass over new/changed tasks and stale candidates (at most eight
task files per run). Read the whole task list for dependencies and selection, but
do not re-investigate unchanged documents every tick. You may reprioritize, split,
merge, reshape or retire tasks that are no longer useful. Preserve user intent,
explicit design constraints, IDs/replacement links and reasons. Convert useful
findings into maintained docs, keeping verified facts separate from proposals.
Do not rewrite an owned `in_progress` task. Do not promote human decisions,
speculative future systems or unfinished drafts to `ready` without settling their
material questions. Do not automatically retry blocked tasks or invent work when
the queue has nothing eligible.

`backlog/ideas/` is reserved for the user's review of worker proposals. Never
dispatch, promote, rewrite, or retire those ideas. An idea becomes executable
only after the user selects it and the authoring workflow produces a ready task.

Prefer correctness, skiing response, performance and racing depth ahead of
secondary presentation. Respect explicit task priorities and dependencies;
within equal priority, pick the oldest ready task. A retired prerequisite does
not count as completed: update dependent scope/references coherently if justified.

Validate the files with `validate`, then commit/push the grooming milestone.
If no eligible task remains, release the manager claim and end successfully.
Refresh activity before dispatch; a new manual implementation or new dirty files
means release the manager claim and end without launching anything.

## Dispatch exactly one worker

1. Run `prepare --task TASK_ID` with a fresh snapshot. It returns a unique token
   and freezes the task's content hash. If skipped, release the manager claim and
   end. Once prepared, the dispatch cannot be blindly released or retried.
2. Create one native Codex task using `create_thread`: the resolved local project,
   `environment.type: local`, `model: gpt-6-astra`, `thinking: xhigh`. The user
   explicitly authorized these independent worker tasks and the existing checkout;
   do not use a worktree or substitute another model.
3. Put the task ID and full dispatch token in its title and initial message. The
   message tells it to read `backlog/WORKER.md` and the exact task file, supplies
   the repository root, manager task ID and token, and tells it to accept the
   claim before editing. Include a concise task outcome so the handoff is legible.
   This is an implementation assignment, not another planning conversation.
4. Save the returned worker ID with `attach`. Worker acceptance may race ahead
   of this write; the helper supports that without replacing the worker's state.
   On an uncertain creation response, preserve the prepared claim and investigate
   existing tasks. If only a queued setup ID is returned, do not pretend it is a
   thread ID or launch another worker; preserve the receipt and report the issue.
5. Take one immediate `wait_threads(timeoutMs: 0)` startup snapshot. Include the
   native created-task directive with the actual ID in the run's final response.
   End the manager run normally. Do not wait for implementation to finish, send
   follow-up prompts, poll in a loop, or create a persistent goal for this run.

Once ownership has transferred, the worker operates independently. Later manager
runs only inspect enough state to avoid collisions or reconcile a stopped worker;
they do not supervise, grade, or direct its implementation. A skip or empty queue
is a fulfilled manager run, not an unfinished goal.

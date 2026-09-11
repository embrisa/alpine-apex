# Backlog operation and recovery

The production manager is a standalone local Codex automation, every 30 minutes,
using Astra High. Workers use Astra Extra High in this checkout on `main`.
Manager notifications are configured to failures only in the automation settings;
workers retain normal task reporting. Keep the computer on and the app running.

The manager finishes after skipping, finding no work, or confirming one worker's
startup. Ordinary automation completion is sufficient; it does not create a
persistent goal or supervise the worker. Pause/resume the automation through
Codex's native scheduling tool or Scheduled UI. Reuse its saved ID from the local
installation receipt, and inspect existing automations before creating a duplicate.

## Helper commands

Requires Python 3.10+ and Git on PATH; no Python packages, services, API keys, or
additional plugins are required. Run from the repository root:

```powershell
./scripts/backlog.ps1 validate
./scripts/backlog.ps1 status
./scripts/backlog.ps1 check --snapshot backlog/.runtime/activity.json
./scripts/backlog.ps1 claim --snapshot backlog/.runtime/activity.json
./scripts/backlog.ps1 prepare --task TASK_ID --snapshot backlog/.runtime/activity.json
./scripts/backlog.ps1 attach --token TOKEN --worker WORKER_THREAD_ID
./scripts/backlog.ps1 accept --token TOKEN --snapshot backlog/.runtime/activity.json
./scripts/backlog.ps1 record --token TOKEN --outcome done --record backlog/.runtime/completion.md
./scripts/backlog.ps1 release --token TOKEN
./scripts/backlog.ps1 recover --snapshot backlog/.runtime/activity.json
```

The caller defaults to `CODEX_THREAD_ID`; `--owner ID` allows explicit ownership
when necessary. `attach` uses the original dispatching manager ID even during
recovery by a later manager. Only do that after verifying the actual child/token.
`--root PATH` selects a different exact Git root for isolated fixtures; production
commands use the default repository root. `record` also accepts `--outcome blocked`.
A manager with no prepared dispatch releases without a token.

Commands return JSON. Exit 0 with `status: skipped` is a successful no-op, not
permission to ignore the reported condition. Exit 2 with `status: error` needs
investigation. `validate` checks metadata, unique IDs, dependency references/cycles
and ready-task open questions. `check` is the no-dispatch preflight; it does not
claim or change task files. Helper status reads may create the ignored mutex file.

## Fresh activity receipts

Use native app `list_projects` to find this checkout's project ID and native
`list_threads(limit: 50)` for a fresh listing. Parse the tool's JSON text content.
If a claim references another owner, also call `read_thread` for its current
thread metadata. Save the following JSON to ignored
`backlog/.runtime/activity.json`, using the tool output as data:

```json
{
  "observed_at": "2026-09-11T12:00:00Z",
  "project_id": "THE_LIVE_LOCAL_PROJECT_ID",
  "listing": {
    "threads": [],
    "pinnedThreads": [],
    "unavailableHosts": [],
    "unavailableSources": []
  },
  "known_threads": [],
  "read_only": []
}
```

Replace the entire `listing` with the real native listing, not these example empty
arrays. `observed_at` is the actual UTC observation time. `known_threads` contains
the `thread` objects from exact reads in this same inspection. Do not manufacture
idle statuses or recycle stale reads. Receipts expire after two minutes; refresh
them just before claim, prepare, acceptance and recovery.

An active planning/review conversation may be explicitly exempted with an entry
`{"thread_id":"ID","turn_id":"CURRENT_TURN_ID","reason":"Evidence of read-only intent"}`
in `read_only`, after reading that turn. Titles alone are insufficient. An active
implementation waiting on input/approval still blocks. Never exempt an implementation
worker just because it owns different files, except a specifically authorized
isolated test fixture during setup.

The desktop listing is limited to 50 recent non-pinned tasks. Known scheduled
owners are always checked explicitly, even beyond that limit. Manually started
agents do not participate in ownership, so detecting them is best effort. Fresh
checks before dispatch and worker acceptance reduce the remaining race; they
cannot prevent a manual implementation starting afterward. Unknown or unavailable
activity prevents dispatch. These receipts are operational evidence supplied by
the agent, not an independent security or multi-machine locking boundary.

## Ownership and recovery

Ignored `backlog/.runtime/state.json` holds a versioned claim and last dispatch
receipt. A short OS file lock serializes each atomic state update; the durable
claim survives process exits. Do not commit or manually delete this local state.
Claim states are manager, prepared dispatch, then worker. `prepare` creates a
unique token and freezes task content; `accept` verifies the token and file hash.
Two managers cannot claim at once, and two workers cannot accept the same token.
Late `attach` after a fast worker completes preserves the finished receipt.

The mutex file normally remains on disk; its existence does not mean it is held.
Neither claim age nor absence from the recent listing proves an owner stopped.
Recovery requires an explicit native idle/notLoaded/systemError status. Unknown
dispatch results retain the reservation until the original child can be identified.

Recovery preserves unfinished edits and marks stopped unfinished work blocked.
A previously explicit done record is retained as done only with clean committed
delivery matching upstream. It does not derive success from an idle task.
Commit/push any recovery record before another dispatch. Unrelated dirty files,
including untracked `.uid` files, still prevent dispatch; nothing automatically
stashes, deletes or commits them. A blocked task is eligible again only after an
explicit retry decision or new user information resolves its blocker.

If no ready task has completed dependencies, release a manager claim and finish.
Do not invent replacement work to keep the scheduler occupied. Broad grooming
authority applies within the project's adopted direction and explicit task
constraints, not to overriding user design decisions or starting speculative
backend/engine work.

## Validate or reinstall

```powershell
python tests/test_backlog.py
./scripts/backlog.ps1 validate
```

The tests use isolated Git fixtures and a local bare test remote. They exercise
real command concurrency, task transitions, pushed completion, dirty-workspace
gates, recovery, and duplicate/uncertain dispatches without starting game workloads.
Real app dispatch is checked separately with a bounded documentation fixture.
Local installation and live-test receipts belong in `backlog/.runtime/` or
`artifacts/backlog_setup/`; maintain portable behavior here rather than embedding
machine-specific automation or worker IDs in tracked instructions.

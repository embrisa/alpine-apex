# Scheduled ownership protocol

Production: fresh local manager every 30 minutes, `gpt-6-astra` / `high`; one
independent worker at `xhigh`, same checkout on main. Existing manager notification
settings are failures-only. Manager ends after skip/no work/one startup snapshot;
no persistent goal or supervision. Manage the existing automation with native
scheduling tools using its local receipt, not a duplicate installation.

## Helper commands

Python 3.10+ and Git on PATH; no third-party packages. Run at repository root:

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

Caller defaults to `CODEX_THREAD_ID`; use `--owner ID` when necessary. Recovery
`attach` uses the original manager ID only after verifying the child/token.
`--root PATH` selects an exact Git root for isolated fixtures. `record` also
accepts `--outcome blocked`; an unprepared manager releases without a token.
JSON exit 0 + `skipped` is a no-op, never a bypass; exit 2 + `error` requires
investigation. `check` is read-only preflight; status may create an ignored mutex.
`validate` checks metadata, IDs, dependencies/cycles and ready-task open questions.

## Activity receipts

Use native `list_projects`, `list_threads(limit: 50)` including pinned tasks,
and exact `read_thread` for recorded owners beyond the listing. Parse native tool
JSON; process names, titles and a separate CLI app-server are not substitutes.
Save `backlog/.runtime/activity.json`:

```json
{
  "observed_at": "ACTUAL_UTC_TIME",
  "project_id": "LIVE_LOCAL_PROJECT_ID",
  "listing": {},
  "known_threads": [],
  "read_only": []
}
```

Replace `listing` with the complete actual listing, including unavailable hosts/
sources; `known_threads` contains exact reads' `thread` objects from this same
inspection. Receipts expire after two minutes: refresh before claim, prepare,
accept and recover. Do not manufacture idle states or reuse stale observations.

A verified current read-only planning/review turn may be exempted through
`{"thread_id":"ID","turn_id":"CURRENT_TURN_ID","reason":"READ_TURN_EVIDENCE"}`.
An implementation waiting for input/approval still blocks. Different file scope
does not exempt another implementation, except an explicitly authorized isolated
setup fixture. Unknown/unavailable activity blocks dispatch. Manual agents do
not claim; detection beyond 50 non-pinned tasks is best effort. Fresh checks
reduce races but are not a security or multi-machine lock.

## Ownership and recovery

Ignored `backlog/.runtime/state.json` stores the durable versioned claim/last
dispatch. A short OS file lock serializes updates; a remaining mutex file does
not mean held ownership. Do not commit/delete local ownership state.

Transitions: manager -> prepared dispatch -> worker. `prepare` creates a unique
token and freezes task content; `accept` verifies token/hash/ready state. Only one
manager/worker can claim/accept; late attach preserves a fast worker's finished
receipt. No claim timeout or absence from recent listings authorizes recovery.

Recovery needs explicit native idle/notLoaded/systemError evidence. Unknown
dispatch results preserve the reservation until the original child's initial
prompt verifies its token; never blindly create a second worker. Preserve edits
and mark stopped unfinished work blocked. Retain a previously explicit done
record only with clean committed delivery matching upstream. Commit/push the
recovery record before dispatching again.

Dirty files, including untracked UIDs, block dispatch; never stash/delete/stage
another agent's work to clear the gate. Blocked work requires an explicit retry
decision or new user information resolving its blocker. No eligible ready task:
release the manager claim and finish without inventing work.

## Validation

```powershell
python tests/test_backlog.py
./scripts/backlog.ps1 validate
```

Tests use isolated Git fixtures/local bare remotes for concurrency, transitions,
pushed completion, dirty gates, recovery and uncertain dispatch. Native app
dispatch is a separate bounded fixture. Installation/live-test receipts belong
in ignored `backlog/.runtime/` or `artifacts/backlog_setup/`.

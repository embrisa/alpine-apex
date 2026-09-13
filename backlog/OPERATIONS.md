# Scheduled ownership protocol

Production: fresh local manager every 30 minutes, `gpt-6-astra` / `high`; one
new independent worker per wake at `xhigh`, same checkout on main. Any number of
compatible non-FPS-sensitive workers may coexist; no fixed two-worker cap.
Existing manager notification
settings are failures-only. Manager ends after skip/no work/one startup snapshot;
no persistent goal or supervision. Manage the existing automation with native
scheduling tools using its local receipt, not a duplicate installation.

## Helper commands

Python 3.10+ and Git on PATH; no third-party packages. Run at repository root:

```powershell
./scripts/backlog.ps1 validate
./scripts/backlog.ps1 validate --preserve-dirty
./scripts/backlog.ps1 status
./scripts/backlog.ps1 check --snapshot backlog/.runtime/activity.json
./scripts/backlog.ps1 claim --snapshot backlog/.runtime/activity.json
./scripts/backlog.ps1 prepare --task TASK_ID --scope backlog/.runtime/TASK_ID-scope.json --snapshot backlog/.runtime/activity.json
./scripts/backlog.ps1 attach --token TOKEN --worker WORKER_THREAD_ID
./scripts/backlog.ps1 accept --token TOKEN --snapshot backlog/.runtime/activity.json
./scripts/backlog.ps1 scope --token TOKEN --scope backlog/.runtime/TASK_ID-scope.json --snapshot backlog/.runtime/activity.json
./scripts/backlog.ps1 record --token TOKEN --outcome done --record backlog/.runtime/completion.md
./scripts/backlog.ps1 release --token TOKEN
./scripts/backlog.ps1 recover --token TOKEN --snapshot backlog/.runtime/activity.json
```

Caller defaults to `CODEX_THREAD_ID`; use `--owner ID` when necessary. With several
reservations, always recover by exact token. Recovery
`attach` uses the original manager ID only after verifying the child/token.
`--root PATH` selects an exact Git root for isolated fixtures. `record` also
accepts `--outcome blocked`; an unprepared manager releases without a token.
JSON exit 0 + `skipped` is a no-op, never a bypass; exit 2 + `error` requires
investigation. `check` is read-only preflight; status may create an ignored mutex.
`validate` checks metadata, IDs, dependencies/cycles and ready-task open questions.
Strict `validate` reports every malformed record. Operational commands and
`validate --preserve-dirty` report incomplete/deleted uncommitted records under
`unavailable_tasks`, exclude those tasks/dependents and continue with the usable
queue. Committed corruption still fails validation. Never overwrite another
person's incomplete task edit to make this check green.

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
  "read_only": [],
  "inspections": [],
  "work": []
}
```

Replace `listing` with the complete actual listing, including unavailable hosts/
sources; `known_threads` contains exact reads' `thread` objects from this same
inspection. Receipts expire after two minutes: refresh before claim, prepare,
accept and recover. Do not manufacture idle states or reuse stale observations.

A verified current read-only planning/review turn may be exempted through
`{"thread_id":"ID","turn_id":"CURRENT_TURN_ID","reason":"READ_TURN_EVIDENCE"}`.
For active unregistered/manual work, `inspections` contains the exact parsed
`read_thread` result. `work` entries contain `thread_id`, its current `turn_id`,
and `scope` (below); the helper verifies that the inspection is of that active
turn. Do not infer ownership or FPS sensitivity from titles. Declared scheduled
worker scopes are authoritative until that worker updates them. A pre-existing
unclassified reservation can be classified by a manager using this exact-turn
evidence; its token/owner are preserved. A declared FPS reservation cannot be
downgraded by a manager's observation. Waiting/unknown activity still needs
inspection; unresolved intent/unavailable sources block dispatch. Manual agents
do not take scheduled claims. Detection beyond 50 non-pinned tasks is best effort.
Fresh checks reduce races but are not a security or multi-machine lock.

## File reservations and FPS sensitivity

Save a task-specific ignored scope JSON, for example:

```json
{
  "write_paths": ["scripts/ui/example.gd", "tests/example_suite.gd", "tests/example_suite.gd.uid", "docs/PRESENTATION.md"],
  "read_paths": ["scripts/core/session.gd"],
  "fps_sensitive": false,
  "reason": "Current UI work has no comparative timing; engine checks use the serial guard."
}
```

Use actual literal repository-relative paths, never these example placeholders.
A path reserves that file or entire directory subtree, case-insensitively.
Include expected new files, source/assets/imports/UIDs, tests, owning guides and
idea proposals. Include read dependencies whose concurrent edits could invalidate
implementation or checks. The helper adds both active/archive task-record paths.
Write/write and write/read overlaps conflict; read/read does not. Scope is
required for concurrent dispatch; omitted/unclassified implementation scope is
exclusive. `check`/`claim` may also take `--scope` to assess a candidate early.
The manager itself reserves only its dispatch slot, and must groom disjoint paths.

FPS-sensitive means measurements requiring quiet CPU/GPU, stable source/settings,
focus and uncontended frame timing. Such a reservation is exclusive against all
other active implementation work, even when files differ. Default a task requiring
timing to exclusive for its whole run unless its worker explicitly manages phases.
Before a timing phase, use `scope` with `fps_sensitive: true`; a skipped upgrade
means do not start that phase. Finish independent non-timing work while waiting;
if nothing remains, record a precise blocked state and stop instead of spinning.
An active worker may update scope with its own token/fresh snapshot; new paths
are checked against every peer before editing, and old writes stay reserved until
release. Drop FPS sensitivity only after measurement stops. All Godot/Blender
and native engine workloads still use the existing serial validation guard;
non-FPS-sensitive does not authorize simultaneous engine jobs. Avoid heavy
background work during another worker's performance acceptance.

## Ownership and recovery

Ignored `backlog/.runtime/state.json` stores the current manager/dispatch/worker
slot in `claim`, additional accepted workers in `workers`, and token-keyed
completion `receipts` plus `last_dispatch`. Inspect all of them. A short OS file
lock serializes updates; a remaining mutex file does
not mean held ownership. Do not commit/delete local ownership state.

Transitions: manager -> prepared dispatch -> worker. `prepare` creates a unique
token, freezes task content and fingerprints existing dirty paths (working bytes
and index entries). `accept` verifies token/hash/ready state and preserved edits.
Changes within compatible peers' reserved write paths are expected; unknown or
overlapping changes still block acceptance. Existing edits are never auto-committed.
Only one manager/prepared dispatch exists at once. A new manager moves a compatible
accepted worker into `workers` without replacing its token/owner. Every worker
records/releases independently; late attach resolves its own durable receipt even
after other workers finish. No claim timeout or absence from recent listings
authorizes recovery. Never clear live ownership state to upgrade the helper.

Recovery needs explicit native idle/notLoaded/systemError evidence. Unknown
dispatch results preserve the reservation until the original child's initial
prompt verifies its token; never blindly create a second worker. Preserve edits
and mark stopped unfinished work blocked. Retain a previously explicit done
record only with committed worker delivery matching upstream; unchanged dirty
paths from the dispatch baseline do not invalidate delivery. Commit/push the
recovery record before dispatching again.

Dirty files, including deletions and untracked UIDs, do not block dispatch by
themselves. Inspect their scope, preserve them and select independent work.
Never stash/delete/stage another agent's changes to manufacture a clean checkout.
A dirty selected task record blocks that candidate, not other ready tasks.
Unresolved merge conflicts and unfinished Git operations still block dispatch.
If unexpected edits change between prepare and accept, preserve the reservation
and reconcile the same child; never create a duplicate. Completion requires no
new or changed uncommitted files outside the baseline and known compatible peer
writes, a committed terminal task record, and HEAD equal to upstream. Peer scopes
are retained for out-of-order completion; they never excuse overlapping or unknown
output. Existing baseline edits may remain or be committed independently. Use
explicit path-only commits and brief serialized Git operations; preserve others'
index entries. A transient Git index lock is a retryable operation, not permission
to delete locks, stash, stage or commit somebody else's files.
Blocked work requires an explicit retry decision or new user information resolving
its blocker. Its unrelated leftover edits do not block other eligible tasks.
No eligible ready task: release the manager claim and finish.

## Validation

```powershell
python tests/test_backlog.py
./scripts/backlog.ps1 validate
```

Tests use isolated Git fixtures/local bare remotes for concurrency, transitions,
pushed completion with preserved dirty baselines, recovery and uncertain dispatch.
Concurrency regressions include three simultaneous workers, changing dirty peers,
out-of-order delivery/late attach, file/read conflicts, FPS exclusion and isolated
recovery. Native app dispatch is a separate bounded fixture. Installation/live-test receipts belong
in ignored `backlog/.runtime/` or `artifacts/backlog_setup/`.

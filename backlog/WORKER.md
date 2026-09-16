# Independent worker

Implement exactly the dispatched task, Astra xhigh, existing checkout/main.
Read [AGENTS](../AGENTS.md), [OPERATIONS](OPERATIONS.md), the assigned task and
applicable skill/domain guides.

## Accept

Verify helper status matches task ID, token and original manager. Collect a fresh
native snapshot, including recorded owners, then `accept --token TOKEN` as your
own `CODEX_THREAD_ID`. It excludes self/manager, checks other activity, Git state,
the existing-change baseline and unchanged ready-task hash, then marks in_progress.
Unrelated pre-existing edits and evolving compatible peer writes do not prevent
acceptance. Skipped/failed acceptance:
make no source/task changes, report/end, preserve reservation for reconciliation;
never bypass it or create a replacement worker.

Fetch/re-evaluate the baseline before edits; block if intervening changes invalidate
the assignment. Inspect your token across `claim` and `workers`, its
`dirty_baseline`, declared scope and peer reservations. Preserve unrelated working
bytes and staged entries; stage and commit
only owned paths. With unrelated staged changes, use explicit path-only commits
so they are not swept into your commit. A conflict with your actual task requires
reconciliation; an unrelated dirty path alone does not.

## Implement

Complete the bounded scope and its stated acceptance; maintain owning guides and
push validated milestones. Missing product decisions are blockers, not permission
to replace the design. Use guarded, identified, unranked workloads; separate
automated, rendered, performance and human/controller/listening acceptance.
Do not continue to another backlog item.

Before major phases, recheck native activity if another task may have started.
Manual agents do not claim; overlap requires preserving work and recording a
blocker, not termination/overwrite. Snapshot checks cannot exclude later starts.

Compatible non-FPS-sensitive workers are expected, including more than two.
Follow OPERATIONS file/read reservations; reserve every file you may edit,
including UIDs, owning guides and idea proposals. Before expanding scope or
starting comparative CPU/GPU/FPS timing, atomically update it with
`scope --token TOKEN --scope FILE --snapshot FILE`. Skipped means that work must
wait; continue independent allowed work or record the precise blocker and stop.
Never weaken a peer's classification or use performance acceptance under competing
work. Use the validation guard: compatible functional runs may share admission;
timing requires `FpsCritical`, and shared cache/import/build mutations require
`Exclusive`. Reserve overlapping outputs and preserve existing workloads.
Coordinate brief path-only commits; a peer's staged/dirty files remain theirs.

Do not block implementation just because a test reads unfinished source left by
an idle/released worker. Inspect it, declare the read dependency and preserve its
bytes/index as the baseline under OPERATIONS. Run against that identified source
and check for drift. Fixing or committing that other feature is not a prerequisite.
Treat helper refusals as concrete diagnostics: resolve missing activity evidence
or an unnecessarily broad scope autonomously, and stop only when the actual
required work still conflicts or cannot be validated. Never omit a real stable
input or bypass a live writer's reservation to make a check pass.

## Development milestone

Follow [internal versioning](../docs/DEVELOPMENT.md#internal-development-versions).
Reserve a unique `changes/<uuid>.json` path with the existing scope helper, then
create it with `versioning.py note --note changes/<uuid>.json`. Include
all owned source/UID/guide/task paths and tested read dependencies in the note.
Capture input hashes before final checks; record actual results and separate
pending human acceptance. Validate the note and staged owned files before each
milestone commit. Every administrative follow-up commit also needs a Maintenance
note. Prefer including terminal task records in the final milestone. Done release
checks the worker's scoped commits since acceptance; report the final Dev ID after
pushing. Do not change a shared version counter or another agent's note.

## Record and release

Optional follow-ups: zero to three evidence-backed [ideas](ideas/README.md), no
quota; check duplicates, link source task and evidence, distinguish hypotheses.
Do not implement/promote them or ask the manager to choose. This also applies
to useful findings from blocked work.

Write an ignored `backlog/.runtime/` note with outcome, performed checks, source
commits, maintained guides, outstanding human acceptance and idea links (or none).
`record --token TOKEN --outcome done --record NOTE_PATH` is allowed only when the
task's defined completion criteria are met; it moves the task to `completed/`. Commit/
push the completion record and ideas, then `release --token TOKEN`. Done release
requires HEAD equal to upstream, a committed completion record and no uncommitted
changes beyond the preserved baseline and compatible peer reservations. The
checkout may contain both pre-existing edits and ongoing peers' owned files.
Your token releases only your reservation. Report delivery and idea links.
Use `validate --preserve-dirty` when unrelated task records are being edited;
inspect its unavailable-task report and do not repair or commit those records.

Decision/tool/verification/interruption/push blocker: `record --outcome blocked`
with exact reason, checks, remaining work and uncommitted/unpushed changes.
This moves the record to `blocked/`; it does not authorize an automatic retry.
Repair affected task links before committing either move, following [README](README.md).
Preserve edits; do not commit broken code to clear the queue. Commit/push backlog
record when possible, release and end; put required user questions in the final
response rather than holding an active waiting claim. No automatic retry.

Never release before terminal recording. If the helper fails, report the exact
error and leave state intact for reconciliation; do not delete ownership files
or infer permission from elapsed time.

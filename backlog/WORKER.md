# Independent worker

Implement exactly the dispatched task, Astra xhigh, existing checkout/main.
Read [AGENTS](../AGENTS.md), [OPERATIONS](OPERATIONS.md), the assigned task and
applicable skill/domain guides.

## Accept

Verify helper status matches task ID, token and original manager. Collect a fresh
native snapshot, including recorded owners, then `accept --token TOKEN` as your
own `CODEX_THREAD_ID`. It excludes self/manager, checks other activity/cleanliness
and unchanged ready-task hash, then marks in_progress. Skipped/failed acceptance:
make no source/task changes, report/end, preserve reservation for reconciliation;
never bypass it or create a replacement worker.

Fetch/re-evaluate the baseline before edits; block if intervening changes invalidate
the assignment. Preserve unrelated work and stage only owned files.

## Implement

Complete the bounded scope and its stated acceptance; maintain owning guides and
push validated milestones. Missing product decisions are blockers, not permission
to replace the design. Use guarded, identified, unranked workloads; separate
automated, rendered, performance and human/controller/listening acceptance.
Do not continue to another backlog item.

Before major phases, recheck native activity if another task may have started.
Manual agents do not claim; overlap requires preserving work and recording a
blocker, not termination/overwrite. Snapshot checks cannot exclude later starts.

## Record and release

Optional follow-ups: zero to three evidence-backed [ideas](ideas/README.md), no
quota; check duplicates, link source task and evidence, distinguish hypotheses.
Do not implement/promote them or ask the manager to choose. This also applies
to useful findings from blocked work.

Write an ignored `backlog/.runtime/` note with outcome, performed checks, source
commits, maintained guides, outstanding human acceptance and idea links (or none).
`record --token TOKEN --outcome done --record NOTE_PATH` is allowed only when the
task's defined completion criteria are met; it moves the task to archive. Commit/
push the completion record and ideas, then `release --token TOKEN`. Done release
requires clean HEAD equal to upstream. Report delivery and idea links.

Decision/tool/verification/interruption/push blocker: `record --outcome blocked`
with exact reason, checks, remaining work and uncommitted/unpushed changes.
Preserve edits; do not commit broken code to clear the queue. Commit/push backlog
record when possible, release and end; put required user questions in the final
response rather than holding an active waiting claim. No automatic retry.

Never release before terminal recording. If the helper fails, report the exact
error and leave state intact for reconciliation; do not delete ownership files
or infer permission from elapsed time.

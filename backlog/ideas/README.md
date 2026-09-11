# Ideas for the user to review

Implementation workers may propose a few useful next steps here after their
assigned work. These are suggestions, not authorized implementation tasks. The
scheduled manager never dispatches, promotes, rewrites or retires these ideas on
the user's behalf. The helper scans only `backlog/tasks/` and `backlog/archive/`.

Use one Markdown file per distinct idea, based on the
[idea template](../../.agents/skills/alpine-backlog/assets/idea-template.md).
Name it `IDEA-YYYYMMDD-HHMMSS-short-slug.md` using UTC; preserve its ID. Check for
similar existing ideas before adding another. Usually zero to three proposals
are enough; an agent should not invent suggestions to fill a quota.

Each proposal links its source task, worker and evidence, explains the benefit
and bounded next step, and records risks or questions the user should consider.
Its status starts `proposed`. A proposal is not proof its suggested fix is correct.
Link the ideas from the source task's completion record and the worker's final
response, then commit/push them with that completion milestone.

To choose one, say: "Use $alpine-backlog to turn IDEA-ID into a task." The skill
investigates and discusses remaining choices, saves a task when settled, then
marks the idea `accepted` with the destination task link. Preserve the suggestion
and its rationale; do not move an idea directly into the ready queue. If the user
rejects one, record `rejected` with their reason if supplied. Only the user decides
which proposals to take forward or reject. Unreviewed ideas remain `proposed`.

Move closed ideas (`accepted` or `rejected`, including ideas the user retires)
into `backlog/ideas/archive/`. Keep their IDs, decision, rationale and destination
task link when applicable. Update incoming links and rebase relative links inside
the moved file. Proposed ideas stay directly in `backlog/ideas/`; task records
have their separate archive at `backlog/archive/`. Neither ideas folder is an
executable task queue.

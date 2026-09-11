# Worker proposals

Ideas are suggestions for user review, outside the executable queue. The helper
scans only `backlog/tasks/` and `backlog/archive/`; the scheduled manager never
dispatches, promotes, rewrites or retires ideas.

Use [the template](../../.agents/skills/alpine-backlog/assets/idea-template.md), one
distinct proposal per `IDEA-YYYYMMDD-HHMMSS-short-slug.md` (UTC, stable ID).
Check duplicates. Zero to three is a useful default, not a quota. Record source
task/worker/evidence, benefit, bounded next step and risks/questions; hypotheses
are not proven fixes. Start `proposed`, link from source completion/final response
and commit/push with that milestone.

User selection invokes [alpine-backlog](../../.agents/skills/alpine-backlog/SKILL.md)
to investigate and settle choices. Mark `accepted` with destination link only
after the task exists; preserve proposal/rationale. Only the user can reject;
record their reason if supplied. Unreviewed ideas remain proposed.

Move accepted/rejected ideas (including user-retired proposals) to
`backlog/ideas/archive/`, preserving IDs, decision, rationale and destination.
Repair incoming links and rebase outgoing relative links. Proposed ideas remain
here; neither directory is a task queue.

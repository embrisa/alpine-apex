---
id: "IDEA-20260911-155000-uid-companions"
title: "Resolve existing untracked UID companions so the queue can dispatch"
status: "proposed"
created: "2026-09-11T15:50:00Z"
source_task: "AA-20260911-155000-agent-backlog-system"
source_thread: "01a090fe-2a8c-7fe0-8b5b-fa6446206ea9"
accepted_task: null
---

# Resolve existing untracked UID companions so the queue can dispatch

## Why consider this

The installed backlog requires a clean checkout before launching a scheduled
worker. Four files predate this installation and will keep that gate closed even
after current manual work ends. Resolving their ownership would let the queue run.
They were preserved because installing the backlog did not authorize taking over
another agent's asset changes.

## Evidence and origin

The [installation task](../archive/AA-20260911-155000-agent-backlog-system.md)
observed these untracked files in `git status --short`:

- `assets/graphics/foliage_sight.gdshaderinc.uid`
- `scripts/presentation/foliage_sight.gd.uid`
- `tests/foliage_color_playtest.gd.uid`
- `tests/foliage_sight_playtest.gd.uid`

All four corresponding source files exist and are tracked, as verified with file
inspection and `git ls-files` on 2026-09-11. This is an ownership/delivery issue to
investigate, not evidence that the UID contents are wrong or should be deleted.

## Suggested next step

After the user selects this idea, identify the owning foliage work and inspect
the UID values and project references. Preserve correct resource identities and
include the required companions in a small validated commit if appropriate.
Recheck native activity and Git cleanliness afterward. Likely effort is small,
but the correct treatment depends on the original changes.

## Decisions and risks

Confirm whether the source work is finished and whether these are its required
UID companions. Do not delete them, regenerate identities, or silently stage
someone else's changes solely to unblock dispatch. Refresh the evidence before
acting because another agent may already have resolved them.

## User decision

Pending user review. This proposal is not an executable task and the manager must
not promote it automatically.

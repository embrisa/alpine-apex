---
id: "IDEA-20260917-110000-use-scoped-benchmark-metadata"
title: "Apply the economical metadata policy to the benchmark wrapper"
status: proposed
created: "2026-09-17T11:00:00Z"
source_task: "AA-20260913-232221-natural-forest-generation"
source_thread: "01a0a5df-19c3-7783-81dc-eca18c340e4a"
accepted_task: null
---

# Apply the economical metadata policy to the benchmark wrapper

## Evidence and benefit

`scripts/benchmark_pc.ps1` still recursively computes source hashes before and
after each run. This conflicts with the user's newer economical experiment policy
and adds unrelated repository work to every benchmark. The forest experiment uses
the guarded native producer directly, with Git/settings/receipt checks instead.

## Bounded next step

Replace the wrapper's blanket source scans with scoped paths, versions, Git status
and file metadata. Keep runtime replay and physical/scenery cache compatibility
checks intact. Verify the launch plan, changed-input detection and invalid-run
handling with synthetic receipts; no fresh GPU baseline is needed for this tooling
change. Review the corresponding performance skill and validation guide commands.

## Risks and decision

Do not silently bypass replay identity or call unrelated-file changes a timing
failure. No turnaround or FPS improvement has been measured. The active goal
authorizes implementation only after the tasks/blocked phase is finished.

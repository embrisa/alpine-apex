# Alpine Apex agent contract

Physics, response, rendered frame rate and racing depth precede graphics and
secondary systems. Preserve the explicit ski model; no animation-driven movement
or racing-line attractor.

## Shared checkout

- Work directly on `main` in private `embrisa/alpine-apex`; no branches, PRs or
  worktrees unless requested. Inspect status and fetch before edits; fast-forward
  when safe. Coordinate overlaps and preserve concurrent work.
- Commit/push small validated milestones, including related source/assets. Push
  completed work before ending; report the exact blocker and unpushed commit on
  failure. Stage only owned changes; no force-push/history rewriting.
- Give every validated milestone one new [development note](docs/DEVELOPMENT.md#internal-development-versions).
  Capture scoped file metadata with `scripts/versioning.py capture --metadata-only` before verification; run `scripts/versioning.py check`
  on the note and staged owned paths before committing. Report the final Dev ID
  after pushing. Dev IDs never replace gameplay compatibility checks.
- After a successful commit and push, remove unneeded artifacts from your task
  using the [artifact lifecycle](docs/DEVELOPMENT.md#artifact-lifecycle) safeguards.
  Preserve evidence needed for active reviews, unresolved findings or concurrent
  work; never clear another task's outputs. Report any deferred cleanup.
- Preserve asset bytes, import settings and UIDs. Large assets use LFS; commit
  useful art milestones, not autosaves. LFS budget: **$5/month, hard stop**; no
  increase without the user. Keep caches, tools, outputs and credentials ignored.

## Boundaries

- Breaking generator/model/schema changes are accepted. Reject/regenerate
  incompatible data; do not add migrations, shims or legacy paths solely to
  preserve old saves unless requested. Remove replaced paths within scope; retain old fixtures
  only for an explicit current test. This overrides historical compatibility
  guidance and does not authorize unrelated deletion.
- Keep the Node-independent **120 Hz** solver and shared **4 m** terrain authority.
  Presentation reads completed state. Preserve the Godot MCP toolkit and
  plugin/autoload configuration.
- Godot remains the engine. Explain major-system purpose, ownership and material
  risks; improve measured bottlenecks within scope. No speculative engine rewrite.
- Physics/input/session edits require `tests/physics_suite.gd` and
  `tests/runtime_suite.gd` through `./godotw --headless --script ...`.
  Camera/render/effect edits require rendered inspection. Keep automated,
  rendered, performance and human/controller/listening acceptance distinct.
- Default automated checks to the smallest [targeted test map](docs/VALIDATION.md#targeted-test-maps).
  Full mountains/scenery-rich laboratories require `-FullMountain` and a recorded
  `-FullMountainReason`; missing fixtures never trigger an implicit cold bake.
- Default to short, timed test descents for data collection; follow the
  [bounded descent policy](docs/VALIDATION.md#bounded-test-descents). Full runs
  require a specific coverage need, not routine iteration.
- Local slope, rock, tree/forest and mixed rendering checks use the explicitly
  selected [targeted FPS maps](docs/VALIDATION.md#targeted-rendering-and-fps-maps).
  Keep their production-component measurements separate from whole-mountain FPS.
- Engine workloads use the guard's shared/exclusive `artifacts/validation.lock`:
  ordinary isolated checks use `Shared`; FPS/CPU/GPU measurements use
  `FpsCritical`; imports/builds/shared cache mutations use `Exclusive`.
  Avoid nested guards, reserve overlapping outputs and wait for conflicting
  workloads. Test/lab runs never write
  personal bests. See validation for cached mountain fixtures and isolation.

## Keep performance work economical

- Reuse the saved average baseline for a matching workload. Do not rerun the
  original setup before and after every candidate. Follow the
  [baseline reuse policy](docs/VALIDATION.md#reusable-baselines-and-experiment-budget).
- Default to one bottleneck hypothesis, one candidate and one short warmed
  candidate measurement. Reject poor visuals before timing. Expand only when
  a specific result or failure requires it; do not launch a broad matrix by habit.
- Skip source, asset, snapshot and executable hash verification. Use recorded
  versions/paths, Git status, settings and existing receipts. Do not add hash
  audits or repeatedly scan the whole repository. Existing runtime replay/cache
  compatibility checks stay in place; do not alter gameplay formats for this policy.
- These defaults override older fresh-baseline, repetition and manual hash-audit
  recipes in skills and guides. Hash audits require an explicit user request.
- Keep compact reports, timings, useful images and unique source assets. Retire
  redundant frozen assets/import caches and large captures after the experiment;
  do not accumulate full project copies for each variant.

## Read for the task

| Task | Guide |
|---|---|
| Ownership, simulation/contact changes, adopted direction | [Architecture](docs/ARCHITECTURE.md) |
| Setup, builds, native tooling, packaging | [Development](docs/DEVELOPMENT.md) |
| Input, contact, handling, flight, impacts, haptics | [Physics](docs/PHYSICS.md) |
| Generation, terrain, snow support, caches, placement | [World](docs/WORLD.md) |
| Graphics, FidelityFX, snow/forest/weather rendering | [Rendering](docs/RENDERING.md) |
| Performance investigation and optimization | [Performance skill](.agents/skills/alpine-performance/SKILL.md), then relevant guides |
| Camera, interface, HUD, loading | [Presentation](docs/PRESENTATION.md) |
| Skier animation, anatomy, hands/poles or review | [Animation skill](.agents/skills/alpine-animation/SKILL.md), then relevant references |
| Audio, native DSP, voice | [Audio](docs/AUDIO.md) |
| Rider ownership, races, recordings, records, persistence | [Racing](docs/RACING.md) |
| Asset provenance, source libraries, rebuilds | [Assets](docs/ASSETS.md) |
| Check selection, execution and acceptance evidence | [Validation skill](.agents/skills/alpine-validation/SKILL.md), then relevant guide sections |
| Reported bugs, `.apexcase` evidence and fix verification | [Bug investigation skill](.agents/skills/alpine-bug-investigation/SKILL.md), then relevant guides |

When investigating a supplied `.apexcase`, read its notes, selection and diagnostic
settings with `scripts/test_case.ps1 -Mode Inspect`, then use Capture and Rerun as
appropriate. Preserve the original. Report captured evidence, current-code
comparisons and human acceptance separately; a completed rerun is not a fix verdict.

Generation/loading, scenery, simulation performance, audio and native work also
follow [the incremental engine strategy](docs/ARCHITECTURE.md#engine-strategy).

Use [the backlog skill](.agents/skills/alpine-backlog/SKILL.md) to author agreed
tasks; authoring does not implement or dispatch them. Scheduled agents follow
[operations](backlog/OPERATIONS.md) and their [manager](backlog/MANAGER.md) or
[worker](backlog/WORKER.md) role. Manual agents do not take scheduled claims.

Maintain one authoritative domain guide per fact. Write project-specific
contracts, decisions, source pointers and reproducible commands; omit general
tutorials and repeated reports. Detailed evidence goes in `artifacts/`. Preserve
unresolved findings and provenance when removing superseded documentation.

When a change affects a repository skill's commands, assumptions, ownership or
evidence contract, review and update the affected skill in the same validated
milestone. Follow [skill maintenance](docs/DEVELOPMENT.md#agent-skill-maintenance)
for dependency routing and verification; keep domain facts in their owning guides.

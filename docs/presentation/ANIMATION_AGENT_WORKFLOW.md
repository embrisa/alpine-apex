# Animation work for agents

Start with the project skill:
[`alpine-animation`](../../.agents/skills/alpine-animation/SKILL.md).
It is stored in `.agents/skills/` so it travels with this project and supports
automatic selection as well as explicit `$alpine-animation` invocation. If the
current client has not discovered it yet, agents can read that file directly via
the entry in `AGENTS.md`. Skill discovery is documented in the
[official skills guide](https://learn.chatgpt.com/docs/build-skills).

The skill keeps its entry short and loads focused support when needed:

| Need | Guide |
|---|---|
| Find the owning stage and avoid coordinate/rig mistakes | [Rig and action map](../../.agents/skills/alpine-animation/references/rig-and-actions.md) |
| Diagnose a poor pose and learn from rejected revisions | [Review loop and R1–R4 lessons](../../.agents/skills/alpine-animation/references/review-loop.md) |
| Reproduce capture, overhead details, measurements, audits and comparison | [Tool recipes](../../.agents/skills/alpine-animation/references/tool-recipes.md) |
| Give an honest critic brief and leave useful evidence | [Handoff and review formats](../../.agents/skills/alpine-animation/references/handoff.md) |

Maintained commands live in `scripts/pose_review/`. `run_stage.ps1` owns guarded
Godot execution; Python tools inspect provenance, select event phases, freeze
sources/tools, measure final silhouettes, encode complete sequences and build
comparisons without assigning scores. They require explicit revision names and
protect sealed evidence. Do not copy dated R3/R4 artifact scripts as new tooling.

Current design reasoning remains in [review lessons](ANIMATION_REVIEW_LESSONS.md),
[R4 alignment](DOWNHILL_TUCK_ALIGNMENT_R4.md), [anatomy](SKIER_ANATOMY.md),
[equipment](EQUIPMENT.md) and [motion integration](STEEP_MOTION_GAMEPLAY.md). Add newly verified
lessons to the relevant maintained guide and put large captures under `artifacts/`.
Mechanical tests, rendered review, independent grading and user acceptance stay
separate; this skill does not certify the pending R4 visual score.

For tool changes run `tests/pose_review_tools_test.py` with Python 3, the skill
creator's `quick_validate.py` on `.agents/skills/alpine-animation`, and the affected
real-capture commands. Renderer changes also require a guarded rendered smoke
test and visual inspection. Preserve historical sealed revisions during testing.

## Source-pose diagnostics

`tests/pose_reference_render.gd::source_pose()` reconstructs imported curves with
the production `skier_full_motion.gd::sample()` function, then applies the existing
boot/support height offset. It uses an isolated sampler and the shared final
skeleton writer; it does not need an editor project or run pose fitting.

On 2026-09-11, removing the abandoned custom editor preserved exact source joint
positions and rotation bases over all 33 clips, five times per clip and both
mirror states: 7,920 joint samples with zero difference. Physics passed 56/56,
runtime 187/187, production motion 77/77, native interface 122/122, and evidence
tool tests 13/13. Skill validation passed. A native DX12 diagnostic smoke rendered
source/requested/final views for two copied historical frames; all six captures
were inspected, with maximum restored-bone error 0.0000003032 m. Menu and riding
captures were inspected, including a standalone Tools menu after removal.

Logs are in `artifacts/guarded/editor-removal-*`; parity data, the isolated copied
capture and Tools screenshot are in `artifacts/editor_removal_20260911/`.
The historical two-frame smoke verifies diagnostic rendering, not current motion
quality, controller feel or gameplay performance. Production animation/assets,
external authoring tools and personal exports were retained.

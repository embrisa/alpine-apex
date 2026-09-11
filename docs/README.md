# Documentation

The inspected baseline on **2026-09-11** is **mountain v15 / seed 849205174 /
Standard**, **physics model 28**, **replay v5 (eight input fields)**, and
**race schema 4**. See [source identity and acceptance](development/VALIDATION.md#current-identity-and-acceptance)
for the inspected commit and live declarations. Version numbers in filenames can
identify a retained subsystem contract; they do not necessarily name the current
default.

The documentation is arranged by subject. Keep a page with the system it
describes; `tasks/` is reserved for active, hand-off-ready work.

## Start here

| Topic | Documentation |
|---|---|
| Run, play, controls and project layout | [Project README](../README.md) |
| System ownership and development rules | [Architecture](development/ARCHITECTURE.md), [AGENTS.md](../AGENTS.md) |
| Godot direction, native components and performance work | [Engine strategy](development/ENGINE_STRATEGY.md) |
| Required checks and remaining acceptance | [Validation](development/VALIDATION.md), [current acceptance checklist](development/VALIDATION.md#current-acceptance-checklist) |
| Priorities and future scope | [Roadmap](development/ROADMAP.md), [online competition](gameplay/ONLINE_COMPETITION.md) |
| Disposable local output | [Artifact lifecycle](../artifacts/README.md) |

## Development and release

- [Architecture](development/ARCHITECTURE.md), [collaboration](development/COLLABORATION.md), [engine strategy](development/ENGINE_STRATEGY.md), [roadmap](development/ROADMAP.md), and [validation](development/VALIDATION.md).
- [Graphics policy](development/GRAPHICS.md), [graphics presets](development/GRAPHICS_PRESETS.md), [FidelityFX runtime](development/FIDELITYFX.md), and [FPS measurement procedure](development/FPS_OPTIMIZATION.md).
- [V15 generation and caches](development/GENERATION_V15.md) and [Windows playtest packaging](development/WINDOWS_PLAYTEST.md).

## Gameplay

- [Ski physics](gameplay/SKIER_PHYSICS.md), [current carving](gameplay/ARCADE_CARVING_V20.md), [grounded snow model 28](gameplay/GROUNDED_SNOW_V28.md), [skid steering](gameplay/SKID_RESPONSE_V22.md), and [auto tuck/contact](gameplay/TUCK_CONTACT_V21.md).
- [Aerial control and direct-stick flips](gameplay/ARCADE_AIR_V27.md), [jump controls](gameplay/JUMP_CONTROL.md), [impact reserve](gameplay/IMPACT_RECOVERY.md), [rock response](gameplay/ROCK_TERRAIN.md), and [controller feedback](gameplay/CONTROLLER_FEEDBACK.md).
- [Mountain creation and sharing](gameplay/MOUNTAINS.md), [race authoring](gameplay/RACES.md), [race beacons](gameplay/RACE_BEAMS.md), [personal bests and ghosts](gameplay/COMPETITIVE_LOOP.md), and [online competition boundaries](gameplay/ONLINE_COMPETITION.md).
- [Camera](gameplay/CAMERA.md) and [camera-profile validation](gameplay/CAMERA_V2_VALIDATION.md).

## World

- [Current v15 terrain and caches](development/GENERATION_V15.md), [retained v13 density](world/ALPINE_V13.md), [retained v12 landforms](world/ALPINE_V12.md), and [geology fitting](world/GEOLOGY_V11.md).
- [Reactive snow](world/SNOW.md), [thick physical snow](world/PLANTED_SNOW.md), [powder geometry](world/POWDER_VOLUME.md), [snow readability](world/SNOW_READABILITY.md), [soft snow lighting](world/SOFT_SNOW.md), and [dreamlike crystals](world/DREAMLIKE_SNOW.md).
- [Wilderness and return zone](world/WILDERNESS.md), [distant scenery](world/OFFMAP_V3.md), [scenery variation](world/SCENERY.md), [tree collection](world/TREE_COLLECTION.md), and [TreeDesigner pipeline](world/TREEDESIGNER_TREES.md).
- [Golden sunlight](world/GOLDEN_SUNLIGHT.md), [mineral detail library](world/MINERAL_DETAIL_LIBRARY.md), and [mountain discoveries](world/FLAVOR_LIBRARY.md).

## Presentation

- [Interface windows and loading](presentation/INTERFACE.md), [interface overhaul](presentation/INTERFACE_OVERHAUL.md), [interface performance evidence](presentation/INTERFACE_PERFORMANCE.md), [menu and loading art](presentation/MENU_ART.md), and [vector logo](presentation/LOGO.md).
- [Skier assets](presentation/SKIER.md), [animation ownership](presentation/SKIER_ANIMATION.md), [full-curve motion](presentation/STEEP_MOTION_GAMEPLAY.md), [anatomy and deep tuck](presentation/SKIER_ANATOMY.md), and [equipment](presentation/EQUIPMENT.md).
- [Animation workflow](presentation/ANIMATION_AGENT_WORKFLOW.md), [review lessons](presentation/ANIMATION_REVIEW_LESSONS.md), [pose review](presentation/POSE_REVIEW.md), and the retained [Cascadeur evaluation](presentation/CASCADEUR_TRIAL_EVALUATION.md).

## Audio

- [Procedural skiing and crash audio](audio/SKIING_AUDIO.md), [wind DSP](audio/WIND_DSP.md), [wind controls and source loop](audio/WIND_AUDIO.md), and [voice](audio/SKIER_VOICE.md).

## Active handoffs

- [Cascadeur animation handoff](tasks/CASCADEUR_ANIMATION_HANDOFF.md) and [Cascadeur workflow/gameplay evaluation](tasks/CASCADEUR_WORKFLOW_AND_GAMEPLAY_EVALUATION.md).

Maintain the relevant subsystem page when behavior changes. Keep raw
measurements, comparison captures and logs under `artifacts/`; do not append
another copy of an implementation report to the README or validation guide.
Remove completed assignment briefs and superseded reports. Keep useful historical
reasoning in the relevant subsystem note or artifact if it is ever needed again.

Dated measurements in subsystem notes describe their original workload. Old local
artifacts were deleted on 2026-09-09; referenced output paths can be regenerated,
but historical before/after baselines are no longer retained.

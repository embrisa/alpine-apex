# Documentation

The inspected baseline on **2026-09-11** is **mountain v15 / seed 849205174 / Standard**, **physics model 28**, **replay v5 (eight input fields)**, and **race schema 4**. See [source identity and acceptance](VALIDATION.md#current-identity-and-acceptance) for the inspected commit and live declarations. Version numbers in filenames can identify a retained subsystem contract; they do not necessarily name the current default.

## Start here

| Topic | Documentation |
|---|---|
| Run, play, controls and project layout | [Project README](../README.md) |
| System ownership and development rules | [Architecture](ARCHITECTURE.md), [AGENTS.md](../AGENTS.md) |
| Godot direction, native components and incremental performance work | [Engine strategy](ENGINE_STRATEGY.md) |
| Required checks and remaining acceptance | [Validation](VALIDATION.md), [current acceptance checklist](VALIDATION.md#current-acceptance-checklist) |
| Priorities and future scope | [Roadmap](ROADMAP.md), [online competition](ONLINE_COMPETITION.md) |
| Disposable local output | [Artifact lifecycle](../artifacts/README.md) |

## Skiing and racing

- [Ski physics](SKIER_PHYSICS.md), [current carving](ARCADE_CARVING_V20.md), [grounded snow model 28](GROUNDED_SNOW_V28.md), [aerial control and direct-stick flips](ARCADE_AIR_V27.md), [jump controls](JUMP_CONTROL.md), [impact reserve](IMPACT_RECOVERY.md), [rock response](ROCK_TERRAIN.md).
- [Mountain creation and sharing](MOUNTAINS.md), [race authoring](RACES.md), [personal bests and ghosts](COMPETITIVE_LOOP.md).
- [Camera](CAMERA.md), [interface](INTERFACE.md), [menu and loading art](MENU_ART.md), [vector logo](LOGO.md).

## World and presentation

- [Current v15 generation and caches](GENERATION_V15.md), [retained v13 density](ALPINE_V13.md), [retained v12 landforms](ALPINE_V12.md), [geology fitting](GEOLOGY_V11.md), [wilderness and return zone](WILDERNESS.md), [distant scenery](OFFMAP_V2.md).
- [Graphics policy and rebuilds](GRAPHICS.md), [FidelityFX runtime](FIDELITYFX.md), [snow response](SNOW.md), [powder geometry](POWDER_VOLUME.md), [snow readability](SNOW_READABILITY.md), [snow lighting](DREAMLIKE_SNOW.md), [sunlight](GOLDEN_SUNLIGHT.md).
- [Skier assets](SKIER.md), [animation ownership](SKIER_ANIMATION.md), [full-curve motion](STEEP_MOTION_GAMEPLAY.md), [articulation and deep tuck](SKIER_ANATOMY.md), [equipment](EQUIPMENT.md).
- [Procedural skiing/crash audio](SKIING_AUDIO.md), [wind DSP](WIND_DSP.md), [wind controls and source loop](WIND_AUDIO.md), [voice](SKIER_VOICE.md).

## Asset authoring

- [Animation agent workflow and skill](ANIMATION_AGENT_WORKFLOW.md): production ownership, review lessons, reproducible tools, grading and handoffs.
- [Scenery](SCENERY.md), [tree collection](TREE_COLLECTION.md), [TreeDesigner pipeline](TREEDESIGNER_TREES.md).
- [Mineral detail library](MINERAL_DETAIL_LIBRARY.md), [discovery assets](FLAVOR_LIBRARY.md), [discovery integration](FLAVOR_INTEGRATION.md).

Maintain the relevant subsystem page when behavior changes. Keep raw measurements,
comparison captures and logs under `artifacts/`; do not append another copy of
an implementation report to the README or validation guide. Remove completed
 assignment briefs and superseded reports. Keep useful historical reasoning in
 the relevant subsystem note or artifact if it is ever needed again.

Dated measurements in subsystem notes describe their original workload. Old local
artifacts were deleted on 2026-09-09; referenced output paths can be regenerated,
but historical before/after baselines are no longer retained.

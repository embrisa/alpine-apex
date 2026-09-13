---
id: "AA-20260913-221134-sun-facing-lens-flare"
title: "Add an occlusion-aware lens flare when the rider faces the sun"
status: ready
priority: P2
depends_on: []
created: "2026-09-13T22:11:34Z"
updated: "2026-09-13T22:11:34Z"
source_thread: null
---

# Add an occlusion-aware lens flare when the rider faces the sun

## Outcome

During an active ski run, looking toward the visible daytime sun adds a restrained cinematic lens flare. It should strengthen naturally as the sun approaches the view centre and fade cleanly as the rider looks away, the sun leaves the frame, sets, or becomes visually blocked. The effect must enrich sunny riding without obscuring the course, HUD, or the rider's ability to read terrain.

## Current state and evidence

`scripts/world/alpine_world.gd` owns the visible directional sun and applies the current `WeatherState` `sun_direction`, `sun_energy`, colour and visibility to it; weather is explicitly presentation-only in `docs/RENDERING.md`. `scripts/main.gd` selects the presentation camera and already supplies the active camera to weather/effects each frame. `scripts/presentation/chase_camera.gd` has the established `effects_enabled` lifecycle gate for active riding effects.

No runtime lens-flare owner was found. The sole repository text match is a static interface-art assertion in `tests/interface_art_playtest.gd`, not a gameplay effect. `AA-20260912-004402-scene-motion-blur` demonstrates the current riding-camera effect lifecycle but is blocked; this task must not modify, complete, or depend on that task.

The rendering policy requires a rendered inspection for camera/render/effect edits. `docs/VALIDATION.md` provides the compact `slopes` targeted rendering/FPS map and requires `FpsCritical` admission for comparative timing; a full mountain is not needed for this local presentation change.

## Agreed decisions and scope

- Add a presentation-only, warm restrained lens flare for the currently selected **active riding camera** in both chase and first-person views. It is not shown for menus, loading, pause/preview/survey cameras, results, crashes, transitions, headless execution, or an inactive/unfocused run.
- Derive the source from the live weather/daylight sun, not the initial `DirectionalLight3D` rotation or a new clock. The flare is zero when daylight sun energy is effectively absent, the sun is below the usable horizon, outside the camera viewport, behind the rider, or occluded from the rendered view.
- Make the flare physically legible rather than a heading-only overlay: its visibility must account for scene/render occlusion by terrain and opaque scenery. A coarse, smoothed visibility update is acceptable if it avoids per-frame cost; a physics/support-surface collision shortcut is not sufficient as the visual-occlusion authority.
- Use a compact procedural or project-owned presentation treatment (core glare plus a small number of soft ghosts), with no new third-party texture, particle system, terrain geometry, shadow/light owner, or sun-position change. Keep it below HUD text and course-critical contrast.
- Respect the existing camera optional-effects/reduced-motion lifecycle. Do not add a separate saved user setting in this first pass; use the established graphics/effects quality path and document its quality/cost behaviour.
- Preserve the 120 Hz solver, terrain/support authority, weather snapshot/race identity, replays, records, ghosts, input sampling and session eligibility. Do not alter `AA-20260912-004402-scene-motion-blur` or turn its outstanding validation into a prerequisite.

## Implementation approach

1. Add a presentation-owned lens-flare component and have `scripts/main.gd` update it after choosing the active riding camera, using the same live weather sun state submitted to the world. Its public inputs should be completed camera state, daylight sun state and presentation lifecycle gates only.
2. Project the sun direction into the active camera and drive stable centre/edge/off-screen response with time-based smoothing. Resolve sun visibility against the rendered scene (or an equivalent renderer-visible occlusion signal), then fade rather than pop on visibility, camera, weather, quality and lifecycle changes. Ensure camera handoffs/reset cannot retain a stale flare.
3. Render the flare in presentation space without changing the world light, terrain shaders, physics queries, HUD layout, simulation clock or serialized state. Prefer bounded draw work; if a full-screen/compositor pass or any recurring scene query is necessary, keep its cadence explicit and expose enough diagnostics for the planned timing comparison.
4. Add focused lifecycle/projection/occlusion coverage and a native rendered producer. Capture fixed, equivalent day scenes for sun centred, sun near frame edge, sun behind/outside the view, sun behind terrain/opaque scenery, cloudy attenuation, and night; run each in chase and first person where applicable.
5. Update `docs/RENDERING.md` with the owner, weather/camera inputs, occlusion contract, gates, quality behaviour, source paths and exact validation commands. Do not duplicate these contracts in unrelated guides.

## Acceptance and verification

- [ ] A focused automated suite proves projection/fade state and every lifecycle gate; it also proves that the component cannot mutate simulation state, terrain/support queries, weather snapshots, session eligibility, replay/record identity or camera-control input.
- [ ] A native rendered playtest on the targeted `slopes` map saves and reviews same-camera daytime stills/motion for centred, edge, off-screen/behind, terrain/scenery-occluded and cloud-attenuated sun cases in chase and first-person views. It shows no flare at night, on blocked sun, or in inactive/menu/preview/crash/result states, and confirms the HUD/course remain readable.
- [ ] If the implementation adds a full-screen pass or recurring scene-visibility query, measure flare-disabled versus fully visible flare-enabled on the same warmed targeted `slopes` workload under `FpsCritical` admission. Report matched frame-time/FPS evidence and any cost; do not make a universal FPS claim from the bounded probe.
- [ ] Run the targeted automated suite through `scripts/run_guarded.ps1` in `Shared` mode and the native rendered producer through the guard without nesting it. Retain useful receipts/captures under an owned `artifacts/sun_lens_flare/` path.
- [ ] Update the rendering guide, add the required development note with captured source/input hashes, run `scripts/versioning.py check` (including `--staged`), stage only owned paths, commit and push the validated milestone. Record actual commands, evidence, compatibility decisions and the pushed Dev ID in the completion record.

Human acceptance: a controller playtest in both riding views should judge intensity, terrain readability and comfort during a short 15–30 second sunny descent. It is separately pending acceptance, not a completion gate; automated, rendered and bounded-performance evidence must be reported independently.

## Open questions

None

## Completion record

Pending implementation. The worker should record the chosen render/occlusion method, actual tests and captured evidence, any matched cost measurement, documentation updates, preserved compatibility decisions, remaining human acceptance, commit/push references and final Dev ID. No separate follow-up idea is proposed.

---
id: "AA-20260913-221134-sun-facing-lens-flare"
title: "Add an occlusion-aware lens flare when the rider faces the sun"
status: done
priority: P2
depends_on: []
created: "2026-09-13T22:11:34Z"
updated: "2026-09-17T12:34:00Z"
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

- [x] A focused automated suite proves projection/fade state and every lifecycle gate; it also proves that the component cannot mutate simulation state, terrain/support queries, weather snapshots, session eligibility, replay/record identity or camera-control input.
- [x] A native rendered playtest on the targeted `slopes` map saves and reviews same-camera daytime stills/motion for centred, edge, off-screen/behind, terrain/scenery-occluded and cloud-attenuated sun cases in chase and first-person views. It shows no flare at night, on blocked sun, or in inactive/menu/preview/crash/result states, and confirms the HUD/course remain readable.
- [x] If the implementation adds a full-screen pass or recurring scene-visibility query, measure flare-disabled versus fully visible flare-enabled on the same warmed targeted `slopes` workload under `FpsCritical` admission. Report matched frame-time/FPS evidence and any cost; do not make a universal FPS claim from the bounded probe.
- [x] Run the targeted automated suite through `scripts/run_guarded.ps1` in `Shared` mode and the native rendered producer through the guard without nesting it. Retain useful receipts/captures under an owned `artifacts/sun_lens_flare/` path.
- [x] Update the rendering guide, add the required development note with captured source/input metadata, run `scripts/versioning.py check` (including `--staged`), stage only owned paths, commit and push the validated milestone. Record actual commands, evidence, compatibility decisions and the pushed Dev ID in the completion record.

Human acceptance: a controller playtest in both riding views should judge intensity, terrain readability and comfort during a short 15–30 second sunny descent. It is separately pending acceptance, not a completion gate; automated, rendered and bounded-performance evidence must be reported independently.

## Open questions

None

## Completion record

Implemented the independent riding-camera compositor, using renderer depth at
the live sun and the production cloud field. A warm core and three soft ghosts
are drawn into a bounded HDR rectangle. One tiny GPU texture retains visibility;
there are no gameplay readbacks, new textures/assets, settings or physics queries.
The existing optional-effects, Reduced Motion and quality paths control it.

Validation completed on Windows DX12 / RX 9070, custom Godot 4.7.2, at Dev95 plus
this milestone's scoped changes:

- Focused suite: **25 checks passed**; main-scene runtime: **192 checks passed**.
  Command: `./scripts/test_pc_environment.ps1 -Suites sun_lens_flare_suite,runtime_suite
  -OutputDirectory artifacts/sun_lens_flare/regression` (Shared guard).
- Native review: **95 checks passed**, eight scenarios in both camera views,
  sixteen main-scene lifecycle gates and two manual-look chronologies. Inspected
  the capped 1920x1080 / Auto75 images. Terrain and opaque blockers produced zero
  raw visibility; the deterministic cloud patch reduced it to about 0.5015.
  The course, rider and HUD remain readable. Native camera/device projection
  agreement is checked explicitly, including vertical device correction.
- Timing: **15 validity checks passed**, one 2-second warmup and 15-second sample
  per off/on arm, same fixed production `perf-slopes` scene (256x512 m, 4 m grid,
  zero objects). Output 3840x2160, internal 2880x1620, High / Auto FSR4.1.1,
  frame generation/GI off, uncapped, no captures/readbacks or focus loss.

| Fixed slopes, 4K High / Auto75 | Flare off | Flare on |
|---|---:|---:|
| Mean frame time | 2.8291 ms | 2.8346 ms |
| Rendered FPS | 353.47 | 352.79 |
| Frame p95 / p99 | 3.141 / 3.287 ms | 3.147 / 3.293 ms |
| Mean GPU time | 2.4289 ms | 2.4341 ms |
| Mean render-thread CPU time | 0.2101 ms | 0.2762 ms |

The observed +0.0055 ms frame / +0.0052 ms GPU differences are too small to
interpret as a stable penalty from one short pair. Render-thread CPU increased
0.0661 ms. This accepts a small optional effect cost; it is not an optimization,
dense-route baseline, full-mountain FPS result or Mac measurement.

Native commands use the executable and arguments in
`docs/VALIDATION.md#sun-lens-flare-checks`, with Shared label
`sun-lens-flare-verified-review-20260917` and FpsCritical label
`sun-lens-flare-cost-20260917` (`--timing`, `--fps-limit=0`). Receipts are
`artifacts/sun_lens_flare/verified_review/report.json`, `cost/report.json` and
`regression/results.json`. No full mountain was generated.

The rendering guide owns the effect contract. The validation guide owns exact
producer usage; existing skill routing remains applicable. Model35, world17,
120 Hz, shared 4 m terrain, all gameplay/race/replay/archive formats and stored
preferences are preserved. Motion blur's implementation and task are unchanged.
Depth-free transparent surfaces cannot occlude this effect; native non-DX12
renderers remain unmeasured.

Human acceptance remains separate: a short controller descent in both views
should judge intensity/readability/comfort. No human playtest is claimed.
Development note: `changes/3879248c14e144b7b87b3b9e61ad7e32.json`; delivered as
**Dev96**, with the containing commit identified by the versioning history.

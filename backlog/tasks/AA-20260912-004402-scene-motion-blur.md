---
id: "AA-20260912-004402-scene-motion-blur"
title: "Add configurable scene-motion blur for speed feel"
status: blocked
priority: P2
depends_on: []
created: "2026-09-12T00:44:02Z"
updated: "2026-09-12T18:48:00Z"
source_thread: "01a0930e-ba9f-77c2-80fd-defb3dea4672"
---

# Add configurable scene-motion blur for speed feel

## Outcome

Make high-speed skiing feel faster through blur that follows actual scene
movement. The user explicitly selected "motion blur that follows scene movement
with Off and strength controls" after distinguishing it from the existing
peripheral speed blur. Keep nearby terrain, obstacles, gates and instruments
readable while making motion apparent in both riding views.

## Current state and evidence

Source inspected on 2026-09-12 at `78178562edb4a9ab812d95b5a47ce36ae6252554`:

- [Peripheral shader](../../assets/speed_periphery.gdshader) takes five radial
  screen-color samples around a fixed center. It does not read depth or motion
  vectors. The same shader also owns speed streaks and impact-reserve warning.
- [Camera settings](../../scripts/presentation/camera_settings.gd) expose
  `blur_strength` and `streak_strength` independently per view in `camera_v2.cfg`.
  Connected uses 50%; Race sets all `_strength` fields to 100%; Stable sets them
  to zero. New defaults must account for those broad preset loops explicitly.
- [Camera controls](../../scripts/ui/camera_settings_panel.gd) label the existing
  effect "Peripheral blur". Named presets, live saves and the paused preview
  share these settings. The preview is explicitly stationary framing only.
- [Main](../../scripts/main.gd), `_update_screen_effects()`, scales peripheral
  blur from the riding camera's `motion_intensity`, hides it outside active
  riding, and keeps impact warning independent of optional camera effects.
  [ChaseCamera](../../scripts/presentation/chase_camera.gd) currently derives
  that intensity from a smoothed 60-200 km/h ramp, separate from the configurable
  lens speed curve. Scene-motion blur must derive direction from scene motion.
- [Rendering](../../docs/RENDERING.md#fidelityfx) describes the custom DX12
  temporal reconstruction and HUD-free frame-generation pipeline. Blur ordering,
  motion-vector conventions and extra GPU cost require native verification.
- Godot's [CompositorEffect documentation](https://docs.godotengine.org/en/stable/classes/class_compositoreffect.html)
  exposes motion-vector requests and render callbacks. It is a candidate
  integration point, not evidence that ordering with this custom renderer works.

No duplicate implementation task was found in active/archive tasks or ideas.
The [presentation comfort review](../archive/AA-20260911-153904-presentation-comfort-review.md)
prepares evidence only; it is not a prerequisite or approval for this feature.
No prototype, rendered comparison or performance measurement was run for authoring.

## Agreed decisions and scope

- Implement actual scene-motion blur. Increasing radial blur or adding screen
  streaks alone does not satisfy the request.
- Add clearly labelled Motion blur On/Off and Strength (0-100%) controls in
  Camera > Motion effects, independently saved for third and first person.
  Strength zero is also a full bypass; toggling Off retains the selected strength.
  Apply immediately, persist through reload, support named presets and reset,
  and retain controller navigation. No extra exposure/quality UI is required.
- Conservative authoring defaults: Off in all built-in profiles, retained
  strength 50% for Connected/Race and zero for Stable. The implementer tunes the
  bounded visual range from moving evidence; this task does not enable it by
  default or authorize changing the existing peripheral-blur defaults.
- Retain distinct Peripheral blur and Speed streaks controls and their behavior;
  test combinations to avoid unreadable compounded effects. Do not reinterpret
  saved peripheral-blur values as scene-motion blur.
- Respect V's optional-effects disable. Suppress the new effect under reduced
  interface motion and outside active riding, including pause/preview, summit,
  menus, crash/results, loading and focus loss. Preserve impact warning.
- Presentation only: no changes to the 120 Hz solver, 4 m support authority,
  input sampling, trajectory, replay/race identity, records or eligibility.
  Follow [Architecture](../../docs/ARCHITECTURE.md#engine-strategy),
  [Presentation](../../docs/PRESENTATION.md) and [Validation](../../docs/VALIDATION.md).

## Implementation approach

Use a bounded depth-aware velocity blur over the 3D scene, with direction and
extent derived from actual rendered motion, including camera translation and
turning. Prefer a local rendering effect using existing scene depth/velocity;
verify the installed renderer's buffer conventions and pass order before choosing
the final hook. Keep HUD, menus and impact warning outside the blur. Inspect skier,
skis/poles, vegetation, sky and translucent snow/weather for missing or invalid
velocity and foreground/background bleeding. Do not introduce multi-frame color
trails as a substitute for exposure blur.

Map strength to a bounded exposure/sample radius, normalize for rendered frame
time and clamp spikes so changing frame rate or enabling generated frames does
not arbitrarily change blur length. A stationary scene should remain sharp.
Keep samples and scratch textures bounded, handle resolution changes, and skip
the blur pass and any solely required velocity/resolve work when disabled.
Do not disable motion vectors needed by reconstruction or frame generation.

Main owns active-camera/lifecycle handoff; the effect consumes completed render
state and owns GPU resources. Reset any history on view switches, teleports,
restart, pause/resume, focus changes, loading, resize and upscaler/FG changes.
Keep render-thread access and resource lifetimes valid. Establish blur placement
relative to reconstruction and FG with actual native evidence; do not modify or
blur the velocity/depth inputs they consume. If the current hooks cannot support
the feature without a broader renderer redesign, record that concrete blocker.

## Acceptance and verification

- [x] Both views expose working On/Off and 0-100% strength controls, live apply,
  independent persistence, named-preset round trips, reset and controller focus.
  Invalid/nonfinite settings remain safe. Off/zero perform no blur-only GPU work.
- [ ] Native chronological comparisons show Off, medium and maximum strength
  on identical straight high-speed, carving, braking, jump/landing and manual-look
  sequences, in both views. Include stationary, low-speed and 100-200 km/h cases,
  nearby trees/rocks, terrain hollows, gates, skier equipment and snowfall.
  Motion follows scene movement; stationary images have no residual smear.
- [ ] HUD/text and warning remain readable and unblurred; inspect disocclusions,
  silhouette bleeding, long trails and periphery/streak combinations. Confirm all
  suppression and lifecycle cases above, including the stationary camera preview.
- [x] Extend meaningful settings/lifecycle checks and run, as one guarded batch:
  `./scripts/test_pc_environment.ps1 -Suites camera_profiles_suite,camera_suite,menu_camera_suite,interface_suite,graphics_suite,pc_graphics_suite,fidelityfx_settings_suite`.
  Add focused motion-effect checks where these suites lack coverage. If changes
  touch physics/input/session behavior, also run the required physics/runtime
  suites through the existing guard and `./godotw --headless --script ...`.
- [ ] Validate actual shader compilation and moving output on the production
  custom DX12 runtime, with Native and Auto reconstruction, FG off/on, windowed
  and fullscreen, and resize. Exercise the supported stock-engine fallback;
  unavailable capabilities must produce an honest disabled state, not a silently
  substituted radial effect. Headless checks alone do not satisfy this gate.
- [ ] Measure matched Off/medium/maximum runs at 3840x2160 output on recommended
  High, with warmed identical route/camera/weather, source/engine/settings identity,
  actual internal pixels, GPU cost, memory, rendered FPS and frame p95/p99.
  Use serial guarded runs and the existing 90-120 rendered FPS, p95 <=11.1 ms,
  p99 <=16.7 ms targets. Report incremental cost and any baseline target failure;
  generated frames are separate. Verify Off has no material regression, and tune
  the enabled range/cost before declaring the implementation complete.
- [ ] Store captures/receipts and exact reproducible commands under
  `artifacts/scene_motion_blur/`; tests use isolated preferences and never write
  personal bests. Update Rendering for effect ownership/order/cost and Presentation
  for controls/defaults. Commit/push source, shaders and related assets, validate
  the backlog record, and retain evidence needed for pending user review.

Human acceptance: the user's moving/controller playtest determines whether speed
feel improves and whether blur is comfortable and readable. This is a separately
pending follow-up, not a worker completion gate. Worker completion requires the
automated, native rendered and performance evidence above; do not claim human
comfort or perceived-speed acceptance from those checks.

## Open questions

None.

## Completion record

Implemented manually on 2026-09-12; qualification remains blocked on the deferred
full-resolution/performance matrix. The user is raiding Mount Hyjal and explicitly
selected **short capped visual checks; defer 4K FPS benchmarks**. Do not treat the
concurrent WoW run or the 30 FPS cap as a performance baseline or a target failure.
No scheduled claim was taken. No separate proposals were added.

- Added the riding-camera compositor, depth/velocity compute shader, per-view
  On/Off and retained strength, availability explanation and lifecycle resets.
  Defaults stay Off in every built-in. Rendering owns implementation/order/cost;
  Presentation owns controls/defaults. Physics, inputs and race/replay formats
  were not edited.
- Required seven suites plus `scene_motion_blur_suite` passed **3,000 checks**
  in one guarded batch: `artifacts/scene_motion_blur/headless_final/`.
  The interface suite previously measured a 64x64 headless window; baseline and
  current HUD had identical failing geometry. Its fixture now explicitly uses
  1440x900. See `baseline_ui/geometry.json`; no product layout was changed.
- Custom DX12 small-scene probe: **71 checks**; official stock 4.7.2 DX12
  fallback: **48 checks**. Native/Auto, Off/50/100, Native MSAA, FG off/on where
  supported, stationary motion, resize and Off dispatch bypass are exercised.
  Captures show directional blur, pixel-identical stationary Off/100 frames,
  and a pixel-identical opaque HUD region across strengths.
- Production-game lab: **23 checks**, seven matched three-second input sequences
  (21 seconds total), Off/50/100 in both views plus combined peripheral/streaks.
  Started at 160 km/h, sampled approximately 86–148 km/h; carve, jump/airtime,
  braking, manual look, skier/skis/poles and snowfall were observed. At 960x540
  output/720x405 internal and preset 4 this is scoped visual/dispatch evidence.
  Native Camera-controls/focus probe: **5 checks**, both view captures.
- Evidence and exact commands: `artifacts/scene_motion_blur/README.md`,
  `sources.json`, `native/`, `stock/`, `game/`, `ui/`; corresponding serial guard
  receipts are `artifacts/guarded/scene-blur-*`. Retain this evidence for the
  pending review. Source/shader/test UID companions are included in delivery.

Still required before marking done: matched three-repeat 3840x2160 High
Off/50/100 GPU/memory/rendered FPS/p95/p99 measurements (including baseline
Off regression), fullscreen/FG transitions, full-resolution near-obstacle/gate/
hollow/disocclusion and transparent-weather inspection, 200 km/h and low-speed
coverage, and the remaining complete lifecycle/visual matrix. The enabled range
is provisional until that qualification; transparent pixels use opaque depth/
velocity supplied by Godot. Human/controller comfort and perceived-speed
acceptance remain separately pending.

Delivery commit/push references: recorded after the implementation milestone.

---
id: "AA-20260911-163058-interface-overhaul"
title: "Overhaul the interface, controller menus, graphics settings and customizable HUD"
status: done
priority: P2
depends_on: []
created: "2026-09-11T16:30:58Z"
updated: "2026-09-11T18:48:40Z"
source_thread: "01a0914b-c7d5-7ad1-bc28-5d0cd55be42d"
---

# Overhaul the interface, controller menus, graphics settings and customizable HUD

## Outcome

Substantially improve the entire player interface. Use the screen edges for
navigation and contextual actions, with large, centered content and enough space
that nothing feels cramped. Show easy choices first, group related settings,
and keep deeper configuration available in collapsed advanced sections. Deliver
consistent controller menu operation, a real 1-10 graphics scale, individually
configurable HUD widgets, and polished audio, animation and visual feedback.

The user selected all player menus, settings, loading, HUD, mountain/race screens
and retained in-game tools; an evolution of the angular Alpine Apex identity;
and a full HUD editor with movement, resizing, opacity, visibility and controller
support. They also explicitly abandoned the custom Animation Workshop and asked
for its immediate removal as pre-work; see the completion record. It must not
receive redesign effort or remain an active workflow. The remaining UI overhaul
is one implementation task with small validated milestones.

## Current state and evidence

Initial read-only inspection on 2026-09-11, with HEAD `35e29c1`. Camera source,
tests and `docs/PRESENTATION.md` had concurrent working edits; these subsequently
landed as `4e10f9f`. Re-read the completed state before implementation and preserve
ownership. No implementation or acceptance of the UI overhaul occurred during
authoring. The separately requested editor-removal pre-work and its limited
verification are recorded below.

- [HUD/menu builder](../../scripts/ui/hud.gd) uses a 530-logical-pixel left menu
  and a fixed 980-wide Settings window. Eight settings tabs share that window.
  Display contains graphics quality, upscaling, render scale, frame generation
  and terrain GI alongside window mode and frame cap. Weather separately owns
  effects quality. Scroll containers follow focus and Back sits outside scrolling
  content, providing useful behavior to retain while replacing the layout.
- Main-menu headings and descriptions include nonfunctional slogans such as
  "MAKE IT YOUR DESCENT." and "A clean line is a fast line." The
  [loading overlay](../../scripts/ui/loading_overlay.gd) has five hard-coded tips,
  including keyboard-only and vague promotional advice.
  [Loading artwork](../../scripts/ui/alpine_art.gd) also supplies decorative
  captions. The copy audit must cover all three sources and the other screens.
- HUD instruments have fixed positions and `toggle_instruments()` toggles a
  collection together. Headers, conditions and telemetry are separate nodes.
  There is no per-widget layout store/editor. The controls footer is currently
  menu-only; keep that riding default.
- [Theme](../../scripts/ui/alpine_theme.gd) and
  [angular style box](../../scripts/ui/angular_style_box.gd) already provide
  shared styling. [Feedback](../../scripts/ui/interface_feedback.gd) supplies
  four synthesized cues, a three-player pool, rate limiting, 160 ms reveals,
  volume/mute/reduced-motion persistence and isolated automated preferences.
  [Interface documentation](../../docs/PRESENTATION.md#ownership-and-navigation) describes earlier rendered
  evidence, which is historical evidence rather than acceptance of this overhaul.
- [Input router](../../scripts/core/input_router.gd) maps rider actions;
  [main](../../scripts/main.gd) routes menu, preview, pause and gameplay events.
  There is no common explicit controller navigation layer for all screens.
  Its unhandled restart/camera actions and overlapping confirm/drop-in bindings
  warrant lifecycle tests; this is a source-based risk, not a reproduced bug.
  [Race creation](../../scripts/racing/race_workshop.gd) uses mouse terrain picking
  and rider axes for survey movement, so menu focus must not also move that camera.
- [PC settings](../../scripts/presentation/pc_graphics_settings.gd) persists seven
  combined graphics/display fields and clamps quality to three levels.
  [Graphics quality](../../scripts/presentation/graphics_quality.gd) contains
  many additional hidden budgets for textures, LOD/distance, shadows, indirect
  lighting, snow particles/tracks/deformation and distant scenery.
  [World](../../scripts/world/alpine_world.gd) applies that profile. Consumers
  include three-element arrays indexed by `level`, and
  [speed effects](../../scripts/presentation/speed_effects.gd) returns early when
  the level is unchanged. Merely adding ten labels or overrides would therefore
  produce invalid indices or stale effects without a consumer audit.
- [Mountain library](../../scripts/ui/mountain_library.gd),
  [race workshop](../../scripts/racing/race_workshop.gd) and
  [records](../../scripts/ui/competitive_panel.gd) build their own controls.
  [Camera panel](../../scripts/ui/camera_settings_panel.gd) already has grouped
  advanced controls, separate camera profiles and a paused-view preview. Integrate
  this behavior with the common shell instead of replacing its camera model.
- At inspection the abandoned editor lived in `scripts/workshop/`, with its own
  main-menu lifecycle, suites, launchers and documentation. The pre-work removes
  these and active skill/doc references. The retained non-editor diagnostic,
  [pose renderer](../../tests/pose_reference_render.gd), now reconstructs source
  poses through the production sampler without an editor project dependency.
- No equivalent overhaul exists in the current tasks/archive or `docs/tasks/`.
  The [input evidence task](../archive/AA-20260911-153901-input-acceptance-evidence.md),
  [presentation review](AA-20260911-153904-presentation-comfort-review.md) and
  [human acceptance](AA-20260911-153906-player-and-controller-acceptance.md)
  cover evidence, not this implementation. The
  [weather upgrade](AA-20260911-160307-weather-upgrade-storm-races.md) overlaps
  Weather, effects and race settings: integrate whichever implementation exists
  at execution time. These tasks are coordination context, not hard dependencies.

## Agreed decisions and scope

### Layout and navigation

- Evolve the current angular cuts, Alpine branding and cold-white/ice-blue/navy
  palette with clearer typography, better hierarchy and generous spacing.
  Retain the live world behind ordinary menus and photography in loading.
- Use a shared responsive screen shell: edge navigation, optional local tabs
  along the upper edge, a large centered workspace, and a concise action strip
  along the lower edge. Keep Back and primary actions reachable outside scrolling
  content. Center the useful content within the available workspace; keep large
  previews large. Do not simply stretch a narrow column or pack additional
  unrelated settings into one giant panel.
- Fit actual output aspect ratios, including 1280x720, 1440x900, 1920x1080,
  3840x2160 and an ultrawide case. Scale logical typography/controls coherently;
  expose UI scale and safe-area adjustment under Interface. Wider layouts use
  space for previews and related columns; narrower layouts stack related content
  and scroll vertically. Never solve overflow by making all text tiny.
- Apply the shell to title, pause, crash/results, settings, mountain creation and
  library/share, race creation/library/share, records, Physics Workbench and
  dialogs. Preserve their existing functionality and explicit test-lab boundaries.
  Race/mountain previews and in-world creation keep the terrain view central.
  Animation Workshop is removed, not integrated.
- Present a short basic section first on each settings page. Put advanced
  controls in labeled expandable groups within that category, initially closed.
  Preserve session focus, scroll and expansion state when returning to a page.
  Do not hide every useful setting behind a single ambiguous Advanced screen.

Settings organization is a product boundary, with control details left to the
implementation inventory:

| Category | Basic choices and grouped deeper controls |
| --- | --- |
| Display | Screen/window mode, output resolution and rendered frame cap; supported monitor/refresh/synchronization controls grouped here |
| Graphics | Preset 1-10 first; grouped rendering, textures/detail, lighting/shadows, snow/particles and weather effects |
| Camera | View and named presets first; retain current framing, speed progression, follow/stability, effects, look and foliage groups and preview |
| Controls | Device-aware bindings/help and menu navigation; existing input/comfort settings grouped by purpose |
| Audio | Existing broad volume/mute choices first; skiing, wind, voice, UI and loading ambience in related groups |
| Interface & HUD | UI scale, safe area, reduced motion and Edit HUD first; deeper visual preferences and widget configuration |
| Weather | Actual conditions, time and automatic behavior; no duplicate rendering-quality ownership |
| Rider | Appearance/equipment presentation using the existing capabilities |

Physics tuning stays in its explicit Workbench, separate from normal graphical
preferences. Reorganize existing functionality; do not invent a gameplay rebinding
system, HDR renderer, online service or replacement authoring engine as a side effect.

### Controller operation

- Use real focus navigation: D-pad/left stick moves, south button confirms,
  east button backs out, and shoulder buttons switch the relevant categories/tabs.
  Show accurate PlayStation/Xbox-style prompts according to the active device,
  with a generic fallback and keyboard/mouse prompts after deliberate device use.
  Prevent analog noise from constantly changing glyphs or stealing focus.
- Give stick navigation a deliberate deadzone, initial repeat delay and bounded
  held repeat. Sliders/steppers support fine adjustment and sensible held repeat.
  Dropdowns, checkboxes, collapsed groups, lists and dialogs work by controller.
  Restore focus to the originating action after closing a child screen; opening
  or collapsing a group must never leave focus in a hidden or disabled control.
- Support the complete ordinary player menu loop and every HUD-editor operation
  without a mouse. All retained tools receive controller-operable menus and
  settings; specialist terrain picking/precision authoring may retain its existing
  pointer controls, with an honest contextual prompt. This does not expand into a
  controller port of every authoring gesture. Provide controller text entry when
  a core player/HUD flow requires it, rather than silently requiring a keyboard.
- Back closes only the topmost popup, group-edit state, child screen or menu as
  appropriate. Cancel from a settings page must not resume skiing accidentally.
  Opening menus owns those inputs: confirm/back/shoulder presses must not also
  drop in, restart, change riding camera, steer, release a charged hop or rotate
  the rider. Preserve existing neutral/release gates when resuming.
- Handle keyboard/pointer handoff, focus loss, disconnect/reconnect and screen
  reload without stuck repeat, invisible focus, duplicate activation or input
  leakage. Popups and native/custom dialogs must participate in the same ownership.

### Graphics presets and advanced settings

- Provide ten real, bounded, documented presets. **1 = minimum, 7 = the recommended
  starting equivalent of current High, 10 = Ultra.** The user explicitly accepts
  Ultra falling below 90 rendered FPS on the target PC. Levels 8-10 add measured
  visual detail/cost; do not claim they meet the normal performance target.
  Every adjacent level must differ in an effective supported setting/budget,
  rather than several numbers aliasing the existing three tiers.
- Define a table of actual settings for all ten presets before wiring consumers.
  Use current Low/Balanced/High as named anchors at 1/4/7, retaining those required
  identifiers in CLI/testing/resource contexts where useful. Distinguish a
  ten-step preset ID from discrete asset tiers and capability decisions. Keep one
  current implementation; no old-save migration or parallel legacy preset system.
- Initial defaults retain Auto upscaling at 75%, a 120 rendered FPS cap, frame
  generation off and terrain GI off at level 7. Presets may select documented
  graphics reconstruction/detail defaults, but never alter output display mode,
  output resolution, frame cap, camera, input, audio, comfort or HUD preferences.
  Frame generation remains a separate explicit choice and is never silently
  enabled by raising the preset. Ultra means the highest validated supported
  configuration within bounded budgets, not every arbitrary number at maximum.
- Individual changes produce a clear Custom state associated with the last
  selected base preset. Selecting/reapplying a numbered preset replaces the
  graphics overrides it owns. Category reset and graphics reset have clear scope;
  neither resets another settings domain. Persist the effective configuration
  across launches, retries, mountain changes and menu transitions.
- Inventory essentially all meaningful graphics controls already supported by
  the rendering pipeline. The advanced UI must expose quality and useful strength/
  distance controls, not only today's few toggles. Minimum inventory: upscaler,
  internal scale, compatible antialiasing/sharpening, frame generation; available
  texture tiers and filtering; scenery/foliage LOD and draw distances, decorative
  density and distant backdrop detail; shadow quality/range, contact shading,
  SSIL and terrain GI; atmosphere/fog/shafts/glow; snow material detail/sparkle,
  track capacity/relief, local deformation, spray/particle budgets; precipitation
  and other weather-rendering quality. Cover additional live controls discovered
  in the bounded audit, including new weather effects if already implemented.
- Document each control's owner, valid range/discrete choices, preset membership,
  persistence and apply timing. Distinguish unavailable backend/asset features
  from hidden settings. Do not add no-op switches or promise unimplemented effects.
  Shader constants that enforce correctness, physical terrain/obstacle population,
  gameplay weather rules and solver values are not graphics sliders. Record
  justified exclusions in the inventory so "advanced" is not a vague promise.
- Display and Graphics have separate UI pages and owned data domains. Monitor,
  output resolution, window mode, refresh/sync and frame cap belong to Display;
  reconstruction/internal resolution and visual rendering belong to Graphics.
  Expose device-supported display choices, with Apply/Keep/Revert and a roughly
  15-second automatic recovery for disruptive output changes. Preserve the custom
  DX12 exact-output/frame-generation path and report effective backend support
  concisely. New native HDR or engine integrations are outside this task.
- Use current Godot consumers and supported assets. Advanced changes must reach
  live materials, emitters, scenery and viewports even if the base preset or
  discrete asset tier is unchanged. Coalesce costly dragging changes; label and
  use an explicit apply/reload only where genuinely required. Do not regenerate
  the physical mountain for a presentation setting.

### HUD editor

- Provide a paused full-screen preview with realistic sample states, accessible
  from title/settings and a paused run. The central space previews the normal
  gameplay aspect ratio. Edge controls select widgets and edit properties.
- Register coherent widgets with stable IDs: speed, time/PB, course progress,
  split/delta, riding state, impact reserve, location/altitude/weather, performance/
  debug readouts and transient gameplay notice placement as applicable. Group
  component labels/bars with their instrument; moving impact reserve, for example,
  moves its label and bar together. Inventory all current HUD elements so the
  feature does not silently omit the separate header/telemetry nodes.
- Each widget supports visible/hidden, normalized position/anchor, uniform scale
  and opacity. Offer mouse drag and controller selection/move/resize modes with
  clear focus, fine/coarse steps and optional snapping/alignment guides. Keep
  bounds inside the selected safe area, recover layouts after resolution changes,
  and provide Reset widget and Reset layout. Hidden widgets remain selectable
  from the editor list. Cancel restores the edit-session snapshot; Apply saves it.
- Save user layout separately from race/model identity. Use one shared layout
  initially with contextual visibility: free skiing must not show irrelevant
  timed-race instruments. Keep the controls footer hidden during riding by default.
  The existing H/global HUD toggle temporarily hides/restores the configured
  layout without overwriting per-widget visibility. UI navigation, loading progress
  and blocking/error dialogs remain independent of gameplay HUD hiding.
- World markers, camera overlays and full-screen impact effects are configured in
  their relevant presentation settings, not draggable rectangular HUD widgets.
  Keep the default riding layout readable and the route unobstructed.

### Sound, motion, effects and text

- Give navigation/focus, activation, back, setting adjustment, success and error
  distinct but coherent feedback. Use clean brief sounds, restrained focus/selection
  effects and short coordinated transitions to achieve the requested AAA feel.
  Maintain readable contrast over bright snow and dark scenes. Avoid persistent
  decoration that competes with the content or animations that delay input.
- Extend the shared feedback service with bounded/preloaded assets and rate
  limiting. Respect UI volume, mute and separate loading-ambience preferences.
  Reduced motion removes spatial travel, animated background effects and repeated
  pulses while preserving immediate readable state changes. Menus must accept
  input during transitions; rapid back/tab changes cancel obsolete tweens/sounds.
- Audit all visible copy. Keep labels, values/units, useful state, consequence/help,
  errors and necessary action prompts. Remove random slogans, filler captions,
  redundant explanations and developer implementation text from ordinary menus.
  Optional detailed help appears on focus/expansion when it aids a choice, never
  only on mouse hover. Legitimate diagnostics belong in the explicit tools view.
- Loading tips may contain accurate game knowledge, current device-aware input
  tips, or ski history/facts/trivia. Replace vague slogans and stale bindings;
  verify historical claims against reliable sources and record provenance in
  maintained content documentation. Keep loading readable without rapid/repeated
  tip changes, fake progress or a minimum delay to display a tip. Retain honest
  loading stages, cancellation, failure handling and reduced-motion behavior.

### Completed editor pre-work boundary

The custom Animation Workshop is abandoned and removed ahead of the overhaul.
Preserve its removal; do not recreate an entry point, exporter or compatibility
path. Retained production animation, pose diagnostics, authored assets, ragdolls,
external DCC workflows, Physics Workbench, race creation and the Godot MCP toolkit
remain in scope only as existing integrations to preserve. Personal exports,
general art sources and external user data were not deleted.

## Implementation approach

1. Recheck shared checkout/ownership, current UI/camera/weather contracts and
   relevant docs. Capture a baseline and create the screen/settings/HUD inventory,
   using only retained screens and preserving the completed editor cleanup.
2. Build reusable Godot Controls for shell, edge navigation, grouped settings,
   focus/prompts and feedback. Separate navigation/presentation responsibilities
   from the large HUD builder while retaining existing gameplay service ownership.
   Validate one representative settings flow, then apply it across the full scope.
3. Introduce validated settings schemas and the ten-preset table; connect each
   setting to its existing owner. Audit every three-tier consumer and early return.
   Keep Display, Graphics and HUD layout data separate, with atomic/error-aware
   saves, sensible invalid-value handling and isolated test stores. Current schema
   versioning is required; preserving old configuration files is not.
4. Implement HUD registration and the visual editor; exercise persistence, context
   visibility and controller editing before adding final animation/audio polish.
5. Complete all retained screen layouts, dialogs, copy and loading content; update
   maintained interface, graphics, input and loading documentation. Measure the
   affected UI/renderer work and remove any demonstrated repeated allocations,
   unnecessary rebuilds or effect overhead within this scope.
6. Run the acceptance matrix, inspect chronological rendered evidence, prepare a
   concise physical-controller/listening checklist and commit/push the completed
   milestones. Keep reports honest about any remaining human acceptance.

Follow [engine strategy](../../docs/ARCHITECTURE.md#engine-strategy),
[graphics policy](../../docs/RENDERING.md#performance-policy), [FidelityFX](../../docs/RENDERING.md#fidelityfx)
and [input/competition boundaries](../../docs/RACING.md#future-competition). No change
to the independent 120 Hz solver, authoritative 4 m support/contact surface,
physical obstacle identities, flight trajectories, race rules or replay meaning
is authorized by this UI task. Keep menu input separate from rider input and
presentation settings out of physical/race identity. UI animations do not own
simulation time. UI/HUD must continue rendering at output resolution.

## Acceptance and verification

### Functional and automated

- [x] All scoped retained screens and dialogs use the common responsive hierarchy;
  easy choices appear first and related advanced controls expand/collapse safely.
- [x] Controller events complete title -> settings -> advanced control -> Back ->
  Drop In -> pause -> HUD edit -> resume -> restart/results/library flows. Cover
  dropdowns, scrolling, long lists, disabled/hidden controls, dialog/text entry,
  device changes, disconnect/reconnect, held sticks, focus loss and rapid navigation.
  Assert no gameplay action or survey movement leaks through menu interaction.
- [x] All ten presets have validated distinct effective configurations; every
  exposed graphics setting changes its actual consumer. Same-preset overrides
  update correctly. Custom/reset, capability gating, invalid input, save/load,
  output-change timeout/revert and domain independence are exercised.
- [x] Every registered HUD widget can be moved/scaled/faded/hidden/restored using
  controller and mouse; bounds, aspect-ratio changes, cancel/reset, contextual
  visibility and the temporary global toggle survive menu/reload/launch lifecycle.
- [x] Preserve the editor pre-work: no obsolete entry points/dependencies return;
  useful production animation and diagnostic fixtures still work.
- [x] Run applicable existing suites and meaningful new behavior tests under
  `scripts/run_guarded.ps1`, waiting for `artifacts/validation.lock` rather than
  terminating another workload. Required input/session regressions:
  `./godotw --headless --script tests/physics_suite.gd` and
  `./godotw --headless --script tests/runtime_suite.gd`, invoked through the guard.
  Include `controller_input_suite.gd`, `interface_suite.gd`, `pc_graphics_suite.gd`,
  `graphics_suite.gd` and `fidelityfx_settings_suite.gd`; exercise current camera
  profile/menu suites and affected loading, library/race and rider lifecycle
  suites. Update assertions tied to old tab counts/preset indices to test useful
  behavior. Do not continue running tests for a deliberately deleted editor.

### Rendered and listening evidence

- [x] Inspect native rendered screenshots at 1280x720, 1440x900, 1920x1080,
  3840x2160 and an ultrawide viewport: main/pause/results, settings basic/expanded,
  long lists/popups, display recovery, previews, loading and HUD editing/riding.
  Check clipping, spacing, focus visibility, contrast, safe areas and actual pixel
  sizes, including increased UI scale. Large screens must show a usefully larger
  workspace rather than the old fixed panel surrounded by unused space.
- [x] Inspect chronological interaction captures/video for focused controller
  navigation, animated transitions, HUD editing, live settings, reduced motion
  and a short unranked descent. Validate native custom-DX12 display/FSR transitions,
  including frame generation on/off and the HUD at output resolution. Headless
  passes cannot establish this evidence.
- [x] Audition or capture actual navigation/confirm/back/adjust/error/success cues
  and loading ambience, including fast repeated input, mute and volume changes.
  State explicitly if real output-device listening remains unperformed. Loading
  facts have source provenance and input tips match current production bindings.

### Performance and delivery

- [x] Compare matched before/after menu, settings-scroll/transition and riding-HUD
  workloads on Ryzen 5 5600X / RX 9070 / 16 GB at 3840x2160. Record source/engine,
  current cache/recipe/seed, output/internal pixels, upscaler and actual settings,
  frame cap, frame-generation state, CPU/GPU times, p95/p99 and memory. Measure
  steady frames separately from screenshot overhead and costly setting application.
  Investigate material matched-setting regressions; do not hide them by lowering
  quality or counting generated frames as rendered FPS.
- [x] Measure all ten presets on a repeatable native workload; compare sustained
  moving-route cases at least at 1, 7 and 10. Target 90-120 rendered FPS for the
  recommended configuration, p95 <= 11.1 ms and p99 <= 16.7 ms as specified by
  current graphics policy; report misses honestly. Ultra may miss that target
  by agreement, but must remain bounded, stable and explicitly measured. Use
  current validated v15 Standard cache generation for routine mountain checks;
  distinguish loading/rebuild cost from rendering cost.
- [x] Deliver the settings/preset/HUD inventory and updated subsystem docs,
  verification evidence and a short user playtest checklist. Preserve the updated
  production-animation guidance and the completed editor removal.
  Run `./scripts/backlog.ps1 validate`, commit and push coherent validated
  milestones on `main`, and record their hashes and any remaining limitations.

Human acceptance: spaciousness, visual polish, real-controller comfort and listening
quality require the user's review. This task may finish implementation after its
automated/native evidence and review checklist are delivered; that human approval
is a separate follow-up, not a worker-claimed pass or a pre-implementation gate.
Respect any user feedback received during implementation. The existing human
acceptance task must not be marked done on the strength of this task's automation.

## Open questions

None.

## Completion record

Implemented and pushed on `main`. Milestones: `264689a` (ten presets and
separate recoverable display settings), `6f5ef8d` (responsive interface,
controller navigation, HUD editor, retained screens and feedback), `8024088`
(bounded nested-dialog registration and all-widget mouse coverage), and
`9abd939` (final rail visibility, native validation tools and maintained evidence).

All eight settings domains use the shared responsive hierarchy, with basic
choices first, collapsible advanced groups, persistent page state and fixed
Back/primary actions. Controller navigation, child dialogs and text entry own
menu inputs; the selected category remains visible in a scrolled rail. Twelve
coherent HUD widgets support position, scale, opacity, visibility, mouse/controller
editing, reset, Apply/Cancel, context and the temporary global toggle. Display
has exact native recovery and a real 15-second timeout. Graphics presets 1–10
have distinct bounded consumers and Custom/group-reset behavior; frame generation
remains explicit. Feedback includes six cues and reduced motion; loading retains
honest progress/cancellation and seven source-documented game tips. Production
animation, the removed editor boundary, 120 Hz simulation, authoritative terrain,
race rules and replay/model identities are preserved.

Verification: physics 56/56, runtime 192/192, retained screens 248/248, settings
114/114, graphics overrides 64/64, HUD/mouse 84/84, final native controller/rail
26/26, feedback/content 111/111, library 62/62, existing native interface 122/122,
native PC graphics 16/16, native graphics 29/29 and FidelityFX settings 18/18.
Controller input, rider lifecycle (51), camera profiles, camera and menu-camera
(20) also pass. Six real staged-loading cancellation points release partial
resources in 27.6–506.0 ms. Final editor import and backlog validation pass.

Native evidence: 125-check matrix / 111 captures at all five requested output
sizes, including 1.4 UI-scale request at 720p; 14 camera-preview captures;
real display Keep/Revert/timeout and FG off/on/off; 26 chronological controller
interaction frames with no simulation advance; full/reduced-motion unranked
movement captures. Actual 48 kHz mixer capture covers all six cues, rapid input,
volume/mute and loading ambience. Physical output-device listening has not been
performed. Images were inspected for layout, contrast, focus and authoring/HUD
interference; this is not a user visual-quality or controller-feel approval.

Performance: the full native run completed 48 result rows, followed by 11 final
paired rows. All ten presets have fixed summit/forest samples; 1/7/10 also have
at least 30 seconds of real solver-driven movement with matching same-tick state.
Maximum 6,144-history-plus-two-live GPU buffer/texture readbacks are bounded,
finite and byte-stable. Full source/engine/device/cache/recipe identities,
actual settings, rendered/GPU/CPU times, p95/p99 and memory are retained.

**Performance acceptance remains open:** preset 7 averages 112.79 rendered FPS
on the moving summit route (p95 12.400 ms) and 88.42 FPS in the moving snowy
forest (p95 15.462 / p99 26.549 ms). These miss the sustained tail targets, and
the forest also misses 90 FPS. Ultra misses allowed targets as documented.
Stationary paired layouts show no material regression; isolated configurable-HUD
updates add about .048 ms. The moving layout pair is 3.8% slower in mean frame
time with improved tails, without establishing a causal UI regression. No
quality reduction or generated-frame counting conceals those results.

Maintained delivery: [interface/settings/HUD inventory and review checklist](../../docs/PRESENTATION.md#ownership-and-navigation),
[graphics preset contract](../../docs/RENDERING.md#graphics-and-display),
[measured performance and protocol](../../docs/VALIDATION.md#performance-evidence),
[structured evidence](../../docs/INTERFACE_PERFORMANCE_RESULTS.json), and
[loading provenance](../../docs/ASSETS.md#branding-and-loading-art). Raw captures/timings are
under `artifacts/interface_overhaul/` and named guarded runs. The task is complete
under its implementation/evidence criterion; spaciousness, real-controller
comfort, listening quality and full-descent acceptance remain for the user and
the existing acceptance tasks. Their status has not been changed by this work.

Editor-removal pre-work completed and pushed to `origin/main` as `abc6254` on
2026-09-11. Removed 31 editor-only files, menu/lifecycle hooks and active references.
The diagnostic renderer now uses the production pose sampler; all 33 clips at
five times with both mirror states matched the prior reconstruction exactly
(7,920 joint samples, zero position/basis difference).

Verification: physics 56/56, runtime 187/187, production motion 77/77, native
interface 122/122, evidence tools 13/13, skill validation and the source-reference
audit passed. Inspected native Tools/menu/riding captures and all six diagnostic
images for two copied historical frames. Maximum restored-bone error was
0.0000003032 m. See [animation workflow evidence](../../docs/VALIDATION.md#animation-evidence),
`artifacts/guarded/editor-removal-*` and `artifacts/editor_removal_20260911/`.
This establishes the cleanup and retained diagnostic functionality; it does not
mark UI-overhaul acceptance, current motion quality, controller feel or performance
passed. Production animation/assets and personal exports remain intact.

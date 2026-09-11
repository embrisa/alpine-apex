---
id: "AA-20260911-160307-weather-upgrade-storm-races"
title: "Weather upgrade, random launches, and storm races"
status: ready
priority: P2
depends_on: []
created: "2026-09-11T16:03:07Z"
updated: "2026-09-11T16:03:07Z"
source_thread: "01a0912e-4fd1-75b3-840f-afa391343fdc"
---

# Weather upgrade, random launches, and storm races

## Outcome

Make everyday clouds, snowfall, wind and transitions richer while preserving
readable high-speed skiing. Add rare free-ski snowstorms and thunderstorms,
varied application launches, a 60-minute active-skiing day/night cycle, and
repeatable authored weather challenges in custom races.

The supplied earlier-session draft establishes the scope and numerical defaults
below. On 2026-09-11 the user also confirmed that storm timing carries across
launches using accumulated free-ski time. This is one implementation task with
incremental validated milestones.
Human skiing, visual comfort and listening acceptance remain a separate follow-up.

## Current state and evidence

Read-only source inspection on 2026-09-11, at commit `1a99064`:

- [Weather controller](../../scripts/presentation/weather_controller.gd),
  [state](../../scripts/presentation/weather_state.gd) and
  [presets](../../config/weather/) already centralize presentation weather.
  Clear, Cloudy, Snowfall and Rain use a fixed six-step sequence with 180-second
  holds and 20-second blends. Automatic weather defaults off; settings are not
  persisted. `settings_changed` also fires during ordinary cycle/daylight changes.
- [Daylight](../../scripts/presentation/daylight_cycle.gd) defaults to fixed noon
  and a 1,200-second optional cycle. Existing authored bands select Dawn 06:30,
  Day 12:00, Dusk 17:30 and Night 00:00; retain those hours.
- [Main](../../scripts/main.gd) distinguishes personal launches from scripted,
  headless and autoplay runs. Its reload snapshot retains preset, quality,
  auto flags and hour, but loses transition phase and visual time. Ordinary
  retries keep the controller. [World](../../scripts/world/alpine_world.gd)
  separately integrates cloud displacement, so copying controller fields alone
  cannot preserve complete weather continuity.
- [Cloud field](../../assets/cloud_field.gdshaderinc),
  [sky](../../assets/weather_sky.gdshader) and
  [cloud lighting](../../scripts/presentation/cloud_lighting.gd) share the main
  cloud layer and projected shadows. The sky uses a half-resolution cloud pass
  and a cheap radiance branch. Preserve the existing submission caching.
- [Weather effects](../../scripts/presentation/weather_effects.gd) allocate at
  most 600 snow, 900 rain and two 100-particle drifts on High, halved on Low:
  1,700/850 total. Existing particle shaders already compensate camera velocity
  and fade the central route. No thunder implementation/assets were found.
  [Speed effects](../../scripts/presentation/speed_effects.gd) own current
  wind/rain playback and lifecycle handling; precomputed rain has an existing
  [asset-generation example](../../scripts/tools/generate_rain_audio.py).
- [Race definition](../../scripts/racing/race_definition.gd) currently declares
  schema **4**, hashes canonical shared JSON, and has no weather fields.
  [Race workshop](../../scripts/racing/race_workshop.gd) owns editor/library UI;
  [run session](../../scripts/core/run_session.gd) owns timing and record
  eligibility. Current solver model is 28 and replay layout is 5.
  [Races](../../docs/RACING.md#race-authoring) and parts of
  [validation](../../docs/VALIDATION.md#check-selection) still say schema 3: source takes
  precedence, and affected documentation must be corrected during this work.
- No duplicate weather task was found in `backlog/` or `docs/tasks/`.
  The [current performance audit](AA-20260911-153903-current-4k-performance-baseline.md)
  and [race-loop audit](AA-20260911-153905-race-loop-acceptance-audit.md)
  are related evidence tasks, not prerequisites or authorization to rewrite them.
  Reuse their results only if current and matched. Coordinate shared files with
  concurrent scenery/presentation work.

These are inspection findings, not new gameplay or performance test results.
Recheck versions and changed files when implementation starts; if another task has
already consumed schema 5, use the next schema rather than reusing an identity.

## Agreed decisions and scope

### Personal defaults and launch behavior

- Persist automatic weather, day cycle, Weather FX quality, manual weather/time,
  separate **Random weather at launch** and **Random time at launch** toggles,
  Rare storms and lightning effects. Both cycles, both launch toggles and Rare
  storms default on. Weather FX defaults High; manual fallbacks are Clear/Day.
- Draw launch weather once per normal application launch using base weights
  Clear 30%, Cloudy 30%, Snowfall 30%, Rain 10%. Exclude storms. Draw an hour
  uniformly across the full 24-hour day before the anti-repeat constraint.
- Avoid the previous launch's weather/time-band pairing using the existing
  Dawn/Day/Dusk/Night band boundaries. Never change a non-randomized component
  to satisfy this rule. When both components are randomized, retain the selected
  weather and reroll the hour outside the previous band if the pair repeats;
  when only one is randomized, reroll only that component. With neither
  randomized, honor manual values and allow repetition. Document the resulting
  constrained distribution rather than asserting independent exact weights.
- A disabled launch toggle starts that component at its saved manual selection.
  Launch toggles affect the next application launch, not the current scene.
  Automatic flags still govern subsequent progression independently.
- Explicit command-line weather/time/quality options override the corresponding
  startup choice for that session without changing saved manual preferences.
  Explicit fixed weather/time also hold their corresponding cycle unless an
  automatic-cycle override was explicitly requested. Script/headless/autoplay
  runs retain Clear/Day, cycles/randomization off and fixed seeds unless
  explicitly configured; never read/write personal weather history in tests.
- A full day takes **3,600 seconds of active skiing**. Menus, pause, survey,
  camera preview, loading, finish and other inactive lifecycle states hold
  progression. Title/menu ambience may animate clouds/precipitation under the
  existing reduced-motion policy without consuming front/day/storm time.
- Retries, summit returns and mountain reloads retain suspended free-ski progress
  within the application and do not reroll launches.
  **Confirmed by the user:** carry accumulated active free-ski time and remaining
  storm cooldown across application launches. Time outside the game never counts;
  the first 20-minute delay is cumulative across play sessions, not repeated on
  each launch. New launches still apply the saved launch preferences; full live
  fronts are restored only within an application. Randomized launches exclude
  storms, while a saved manual storm remains available with randomization off.
  If a launch replaces a storm that was active at the previous exit with ordinary
  weather, retain a full 20 active-minute cooldown before another automatic storm.
  Persist counters at bounded checkpoints/lifecycle transitions, not every frame;
  malformed/missing progress defaults to the initial delay.
- Manual weather/time selections apply immediately and update only the manual
  fallback. Preserve the existing explicit automatic toggles: selecting a preset
  starts a new hold; disabling automatic weather freezes the current blend;
  resuming continues it. Routine fronts/random launches never overwrite manual
  selections. Race weather changes are transient as described below.

### Weather fronts and presentation

- Extend the shared controller/state with a private seeded random stream.
  Ordinary fronts hold 4–7 active minutes and blend over 45–75 active seconds.
  Replace the fixed loop with coherent transitions and bounded within-front
  intensity/wind variation. Rain-to-snow and snow-to-rain changes pass through
  Cloudy, including storm approaches/recoveries.
- Rare automatic storms are free-ski only: a **5% chance at each eligible ordinary
  front change**, no storm in the first 20 active minutes and none within
  20 active minutes after the previous storm ends. Eligibility requires
  automatic weather and Rare storms enabled. Select Snowstorm from the snowy
  branch and Thunderstorm from the rainy branch; Cloudy can lead into either.
  No nested storms or storm-to-storm transitions. Peak lasts 90–150 seconds;
  smoothly approach and recover into ordinary weather. Cooldown starts after
  recovery finishes. Time outside free skiing does not consume these timers.
- Add manually selectable Snowstorm and Thunderstorm. In manual mode a storm is
  held like other presets; the rare-event chance/cooldown does not prevent
  explicit selection or authored storm races. The 90–150-second peak applies to
  automatically scheduled free-ski storms, not fixed race conditions.
- Improve main cloud silhouettes, varied structure and sky shading while
  retaining alignment of the main clouds with terrain, rider and other receiver
  shadows. Add only a restrained, non-shadow-casting upper wispy layer on the
  High graphics tier; preserve the cheap radiance branch. Storm cover, fog,
  precipitation and visual wind strengthen gradually with bounded parameters.
- Improve snowflake size variation, flutter, depth and gust-driven spindrift
  inside the existing 1,700 High / 850 Low particle ceilings. Preserve camera
  motion compensation, camera-cut/reset handling and central-route fading.
  Rain remains part of the everyday upgrade.
- Thunderstorms use pooled distant branching bolts, brief cloud illumination
  and delayed positional thunder. Precompute/add reusable thunder clips and
  integrate with existing audio settings/mute/lifecycle ownership; no per-frame
  audio synthesis or new shadow-map passes. Keep cloud illumination in the
  shared presentation pipeline rather than another daylight owner.
- Use saved lightning effects **Full / Reduced / Off**, default Full. Reduced
  suppresses abrupt cloud illumination and uses restrained bolt presentation;
  Off disables visible bolts and flashes while thunder remains subject to audio
  controls. Reduced motion caps the effective setting at Reduced without
  overwriting the saved choice. No new storm flashes/thunder in inactive menus.
  Clear transient bolts, illumination and pending thunder on lifecycle handoff,
  pause, retry, exit, scene cancellation, and weather-mode changes; never deliver
  a backlog of delayed thunder after resume. Future active-clock events continue
  normally. Persistent weather state and transient effect queues are distinct.

### Fixed race conditions

- Add weather and Dawn/Day/Dusk/Night selectors to the existing race creator,
  default Clear/Day, with both storm presets. Show conditions in race details,
  saved-library selection and human-readable shared JSON. Per-map weather
  authoring and a general race-editing redesign are out of scope.
- Add canonical authored conditions and a weather-rules version to **race
  schema 5**. Validate types, allowed presets/time bands and supported rules;
  include them in race and record identity. Reject old schemas without migration
  or fallback weather rules. Update affected storage namespaces and tests so
  obsolete definitions/records cannot be mixed with current results; no need to
  delete the user's old files.
- Each attempt, including retry, begins at exactly the authored preset/hour.
  Disable automatic fronts/day progression for the attempt; a storm remains
  stormy for its full duration. Seed gusts/lightning/cloud motion from canonical
  race identity and sample them using elapsed race time. Start at elapsed zero
  before the first visible/racing frame. Pause cannot consume their schedule.
  Retry repeatability must not depend on frame rate, camera choice or FX quality.
- Changing weather/time or enabling either automatic progression during an
  attempt latches it as **practice** until retry; changing back does not restore
  record eligibility. Weather FX Off likewise makes any authored-condition
  attempt practice, including Clear/Day. Low/High and reduced/disabled lightning
  remain permitted. Show the reason; practice cannot update PB/history/ghosts.
  Retain existing physics/test/lab/autoplay eligibility restrictions.
- Keep the initial free-ski snapshot suspended through race entry, race-to-race
  switches, retries and any world rebuild. Restore it when leaving for free ski,
  including boundary return, cancelled/failed race loads and ordinary exit paths.
  Finishing and retrying stay in the authored race context. Race conditions and
  transient practice weather controls never overwrite personal preferences or
  the suspended free-ski snapshot. Accessibility/quality preferences may be
  saved independently and reapplied without disturbing restored progression.

### Authority and excluded work

Weather remains independent of mountain generation, snow accumulation, wet grip,
physical wind forces, collision and the 120 Hz solver. Authored visibility
conditions affect race identity/eligibility through session orchestration, not
movement. Preserve the shared 4 m terrain authority and gameplay RNG. No networking,
backend, engine replacement, volumetric-cloud framework, extra shadow passes or
unrelated scenery/performance rewrite.

## Implementation approach

1. Add a small weather-preferences object patterned on
   [display preferences](../../scripts/presentation/pc_graphics_settings.gd),
   separating durable player choices, launch history and agreed storm counters
   from live weather state. Missing/corrupt settings fall back safely. Use the
   existing personal-preference gate and isolated test paths. Save explicit
   preferences through their own signal; periodic front/day updates must not
   trigger preference writes.
2. Make the controller the complete source of resumable weather state: front
   endpoints/phase/durations, intensity/wind state, private RNG seed/state, active
   clocks, daylight, rare-storm phase/cooldown and integrated cloud offsets.
   World/effects consume the snapshot. Move current world-owned cloud integration
   behind that ownership boundary to avoid double advance/reset.
3. Add bounded front scheduling, presets, cloud/precipitation improvements and
   pooled storm audio/visual effects. Keep resource creation out of riding hot
   paths, bound catch-up on large deltas and pool/event counts, and preserve
   inexpensive unchanged-state submissions. Measure the affected weather cost;
   [weather submission benchmark](../../tests/weather_submission_benchmark.gd)
   is a useful isolated probe, not full-descent acceptance.
4. Integrate creator/schema/identity and race lifecycle in
   `race_workshop.gd`, `race_definition.gd`, `main.gd` and `run_session.gd`.
   Main owns personal versus race context and eligibility latching; the solver
   never sees WeatherState. Resolve condition changes before the next tick can
   save an eligible result. Update HUD controls without creating another timer
   or preference owner.
5. Deliver small coherent validated milestones on main, including required
   assets/imports/UIDs. Update weather/daylight architecture, races, interface,
   graphics and validation documentation, plus affected competition contracts.
   Follow [engine strategy](../../docs/ARCHITECTURE.md#engine-strategy),
   [online competition boundaries](../../docs/RACING.md#future-competition) and
   [guarded validation](../../docs/VALIDATION.md#check-selection).

## Acceptance and verification

All checks below are planned implementation work, not authoring-session results.

### Automated

- [ ] Fresh-profile defaults and missing/corrupt preference handling; save/reload
  every preference; ordinary updates do not write preferences; explicit
  arguments and script/autoplay isolation take precedence correctly.
- [ ] Reproducible launch draws, full-day range, ordinary-only weather,
  base weights and constrained anti-repeat behavior for all four launch-toggle
  combinations. Exactly one launch draw across retry/reload/race lifecycle.
- [ ] Exactly 3,600 active seconds wraps daylight; menus/pause/loading/finish,
  survey/preview and race suspension consume no free-ski progression. Confirm
  the agreed cross-launch storm-counter behavior using isolated profiles.
- [ ] Seeded front durations/transitions, cloudy rain/snow bridges, storm
  eligibility boundaries, 5% decision path, peak/recovery/cooldown, bounded
  intensity, manual storm holds and deterministic large-delta handling.
- [ ] Full snapshot round trips during holds, blends and storms preserve future
  state/RNG/cloud continuity; scene reconstruction and quality changes neither
  double advance nor reset it. Transient thunder never leaks across handoffs.
- [ ] Schema/share/library round trips, malformed/old-code rejection, identities
  differing by weather/time/rules, default suggested race conditions, retry
  schedule equality at different render step sizes, pause and race switches.
- [ ] Practice eligibility latches on weather/time/automatic/FX Off changes,
  clears only through a valid fresh retry, and never writes PB/history/ghosts.
  Low/High and lightning controls preserve eligibility. Cover race finish,
  boundary return, cancellation/load failure and free-ski restoration.
- [ ] Same rider input and terrain produce unchanged simulation/replay state
  under different weather settings; weather draws do not consume gameplay RNG.
- [ ] Run guarded serial `physics_suite.gd`, `runtime_suite.gd`,
  `race_suite.gd`, `graphics_suite.gd`, `golden_sunlight_suite.gd`,
  `offmap_atmosphere_suite.gd`, affected `interface_suite.gd` and audio suites,
  plus focused new weather tests. Use `./godotw.ps1 --headless --script ...`
  where supported and required native modes for interface/render cases.
  Update old fixed-cycle assumptions rather than retaining a legacy scheduler.

### Native rendered and audio

- [ ] Inspect chronological native motion evidence for all six conditions
  across the four daylight bands in chase and first person. Include storm
  build/peak/recovery, changing cloud shadows, rain/snow at skiing speed and
  fog/route readability. Compare ordinary conditions against matched baseline
  footage; stills alone do not establish transition quality.
- [ ] Exercise graphics Low/Balanced/High separately from Weather FX Off/Low/High,
  reduced motion and Full/Reduced/Off lightning; verify native shader
  compilation, particle ceilings, immediate settings effects, sky/shadow
  alignment and no extra shadow passes. Confirm lightning off has no residual
  illumination and cloud motion does not jump on reload/restore.
- [ ] Inspect weather settings and race creator/details at supported UI sizes;
  create/share/start/retry/finish/leave a storm race, including practice feedback.
- [ ] Verify delayed positional thunder through rendered/audio evidence with
  bounded overlapping voices, existing mute/volume behavior and no stale
  effects after pause, camera/lifecycle handoff or failed load.

### Performance and delivery

- [ ] Capture a source-stable pre-change baseline, then matched capture-free
  v15 Standard default-mountain descents at 3840x2160 High, Auto FSR 75%,
  120 rendered FPS cap, frame generation/SDFGI off. Use a validated complete
  ordinary-input trace through `scripts/benchmark_pc.ps1`; extend its current
  Clear/Snowfall-only weather selector and metadata to measure the new presets.
  Repeat matched ordinary and storm workloads enough to distinguish variance
  (three runs per reported comparison); record seed, trace, conditions/time,
  source/engine/driver identity and competing load.
- [ ] Report actual internal/output pixels, rendered FPS, CPU/GPU timings,
  p95/p99, memory and weather submission cost. Compare against the 90–120
  rendered FPS target, p95 <= 11.1 ms and p99 <= 16.7 ms. Separate pre-existing
  full-descent misses from weather-induced regressions; address measured
  regressions in this subsystem and record remaining target gaps honestly.
  A crash/stall, capture run or generated-frame count is not a valid complete
  rendered-performance result.
- [ ] Keep engine workloads serial under `artifacts/validation.lock`; wait
  for other agents and preserve concurrent changes. Keep fixtures/profiles
  isolated from personal saves.
- [ ] Update maintained docs, validate the backlog record, and commit/push all
  completed milestones directly to main with scoped staging.

Human acceptance: the user should later judge everyday/storm readability, skiing
comfort, controller flow and thunder mix on their equipment. This is a follow-up,
not a worker completion gate. The worker must complete required automated,
rendered and performance evidence or state a concrete blocker; never label user
acceptance passed on the strength of those checks.

## Open questions

None.

## Completion record

Pending implementation. Record changed behavior, tests actually run, reviewed
motion/audio evidence, measured baseline/deltas/limits, documentation, remaining
human acceptance and commit/push references. If required work is blocked, record
the blocker and unfinished checks. Record separately selected follow-up ideas in
`backlog/ideas/`, or note that none were proposed.

# Impact reserve — model v18

## Automatic slope-matched absorption - v18

Small, well-aligned jumps spend no reserve. Large clean landings absorb most damage;
awkward contact and extreme normal closing speeds still spend reserve and can
exhaust a low bar. Absorption is automatic, with no timed crouch requirement.
The existing settled-tuck tolerance allowance remains an optional benefit.

Immediately before touchdown, the solver compares the physical equipment up axis
with the struck triangle normal, then compares either projected ski tip with
tangential travel. Full fit extends through 10 degrees of tilt and 15 degrees of
travel error. Each weight fades with smoothstep to zero at 50 and 60 degrees,
respectively; their product is the landing fit. Inverted/degenerate frames receive
no bonus. Below 0.5 m/s tangential speed only slope fit matters. Forward and switch
receive identical treatment. Cosmetic body posture, total speed and jump height
do not independently add damage or change absorption.

`landing_hit(normal_speed, alignment_cost, reference_speed, fit, reason, tuning)`
blends the clean damage below with the existing capped rough damage, then uses
the same reserve deduction and maximum-per-contact-group machinery as `hit`.
The original `hit` interface remains the obstacle and unrelated bottom-out path.

```text
R = landing_tolerance * (1 + effective_tuck * landing_absorption)
clean = min(impact_max_damage,
    landing_clean_damage_scale * impact_reference_damage * max(0, normal_speed - R)
    / (R * (1 - impact_soft_ratio)))
damage = lerp(rough_damage(normal_speed + bounded_alignment_cost, R), clean, fit)
```

Defaults are R = 10.5 m/s untucked, clean scale = 0.10, reference damage = 0.30,
soft ratio = 0.55, and maximum damage = 0.65. Angle thresholds are stored in radians;
normal and tangential speed thresholds are m/s in the existing tuning resource.

| Clean normal landing speed | Reserve spent from full |
|---|---:|
| Up to 10.5 m/s | 0% |
| 14 m/s | 2.22% |
| 20 m/s | 6.03% |
| 30 m/s | 12.38% |

A landing episode starts even when touchdown is free, without restarting damage
recovery. For 0.30 seconds from its first touchdown, it remembers the weakest fit.
Immediate compression stops reuse that fit rather than judging the already
aligned grounded frame. Recontacts cannot extend the episode or improve its fit;
a worse touchdown can increase the group's maximum damage. After expiry, an
unrelated bottom-out uses its original rough curve. Restart clears episode state.

Contact impulses, inward-velocity removal, tangential momentum handling and raw
`landing_force`/per-ski landing speeds are unchanged. Animation, sound and HUD
consume actual impact speed and reserve separately. Obstacle damage, rock wear,
1.25-second recovery delay, 6-second supported refill and 65% event cap remain.
Physics identity advances to v18; replay layout remains v4 and older model records
are not compared. There is no save migration.

Current verification: 776 assertions across 12 suites pass, including 155 focused
landing checks. Four native landing sequences at 1440x900/RX 9070 retained 100%,
96.32%, 39.98% and 84.24% minimum reserve for small clean, large clean, awkward and
extreme clean landings. Sampled landing/follow-through frames were inspected.
Concurrent vegetation shader errors limit overall rendering/performance acceptance;
human skiing acceptance remains pending. See [validation](../development/VALIDATION.md).

```powershell
.\godotw.ps1 --headless --script res://tests/landing_absorption_suite.gd
.\godotw.ps1 --script res://tests/landing_absorption_playtest.gd '--' --graphics-quality=high --terrain-gi=off
```

The new playtest writes `artifacts/landing_v18/visual/`. Its optional `--timing`
mode uses 3840x2160 output, High, 75% FSR2 and a 120 FPS cap without frame captures,
and records CPU/GPU/tick timings and engine memory separately. Shader failures
invalidate full-workload performance acceptance regardless of its timing numbers.

## Current recovery presentation - v17

[Model 17](SKIER_PHYSICS.md) retains the 0.30 s group, 1.25 s recovery delay,
6 supported seconds to refill and 30%/65% reference/max impact damage. Landing
speed and side drive absorption; normalized reserve adds restrained chest/hand
recovery without control penalties. Continuous abrasion cannot repeatedly fire
discrete recoil. Crash handoff includes the whole-flight angular velocity and
uses the final composed pose. The crash cuff's 24-degree upper flexion stop
provides extra margin under impact; the existing test limits are retained.


Exposed [rock terrain](ROCK_TERRAIN.md) now also spends reserve gradually while
sliding. Recovery requires snow support and a delay after the last abrasion.
Abrasion uses its own timer so it cannot merge unrelated landing/collision hits.

Alpine Apex now uses the impact bar requested after the Steep study. Rough
landings and collisions spend reserve according to severity. Riding smoothly
restores it after a delay. An impact causes a fall when it empties the bar.
Steering, skidding and body lean do not spend reserve or trigger balance deaths.

## Playing

### Progressive screen warning

Below **70% reserve**, the world gradually loses colour and a soft crimson pulse
appears around the screen edges. The warning becomes stronger as reserve falls;
the existing red HUD message still starts at 30%. A softly feathered oval leaves
the central viewing area free of crimson tint and edge darkening, and the HUD
remains above the effect. Radial falloff replaces the original square perimeter.

The presentation-only controller consumes the current reserve value, including
airborne time and gradual rock abrasion. Its target is
`pow(clamp((0.7 - reserve) / 0.7, 0, 1), 1.8)`, with exponential time constants of
0.45 seconds for increasing danger and 1.0 second for recovery. The broader range
and gentler early curve begin with a faint hint, reaching approximately 3%, 10%,
37% and 76% of maximum warning at 60%, 50%, 30% and 10% reserve. A sudden drop
fades in over roughly 1.35 seconds to reach 95% of its target. Pulse frequency
rises from 0.5 to 0.9 Hz as the smoothed warning strengthens: half the original
pulse speed, with each cycle lasting about 1.1–2 seconds. Its continuous
0.30–1.00 envelope retains a visible tint between peaks; colour loss stays steady.
Maximum strength caps desaturation at 75%, crimson blending at 30% and edge
darkening at 15%. These are visual warning values, not changes to impact damage.

**V / camera motion effects off** and **Reduce interface motion** suppress
pulsing while retaining a steady warning at the pulse's mean strength. Pause,
crash, results, focus loss, loading, mountain transitions and restart clear the
warning state. Resume fades in from the reserve currently held by the solver.

`scripts/presentation/impact_warning.gd` owns the envelope and integrates pulse
phase independently of rendered frame rate. `assets/speed_periphery.gdshader`
combines it with the existing speed treatment in one pass beneath the HUD.
Warning-only frames sample the world once; frames with neither effect skip the
pass. No simulation, replay, audio, vibration or camera-motion rules change.

Verification commands (serialize engine workloads using `scripts/run_guarded.ps1`):

```powershell
./godotw.ps1 --headless --script tests/impact_warning_suite.gd
./godotw.ps1 --headless --script tests/runtime_suite.gd
./godotw.ps1 --headless --script tests/physics_suite.gd
./godotw.ps1 --script tests/impact_warning_playtest.gd
./godotw.ps1 --script tests/impact_warning_playtest.gd '--' --timing
```

The native harness validates and reuses seed 849205174's v14 bake. It writes
matched day/night, chase/first-person peak/trough views and six-second diagnostic
reserve/recovery sequences to `artifacts/impact_warning/`. Its capture-free timing
mode uses 3840×2160, High, Auto FSR at 75%, 120 FPS cap and frame generation off.
Two reversed-order on/off pairs cover open terrain and a forest clearing.
Reports identify the engine, actual upscaler, pixels, source hashes, cache,
CPU/GPU/frame timings and memory. Fixed-view rendering isolates the screen cost;
it does not prove full-descent performance or user skiing acceptance.

Current comparison views cover 70%, 60%, 50%, 40%, 30% and 10% reserve, followed
by steady comfort mode and recovery. This revision passed 25 controller checks,
170 runtime checks and the native v14 run (56 captures, four six-second sequences,
complete recovery in every view). The early hint and stronger warning were
inspected in rendered captures. Current previews are
`day_chase_early_gradual_preview.mp4` and `night_first_early_gradual_preview.mp4`
under `artifacts/impact_warning/`. Human skiing acceptance remains separate.
Performance measurements below precede
the oval, slower-pulse and earlier-onset refinements and retain that scope.

Initial square-perimeter version validated 2026-09-10 on the RX 9070 with the
custom DX12 engine and FSR **4.1.1** (timings below precede the slower oval revision):
24 controller checks, 170 runtime checks (including actual scene reload), and
56 physics checks passed. Native day/night, chase/first-person peak/trough and
recovery captures completed without engine errors. A combined speed/warning
capture was inspected after timing, outside all measurement windows.

| Fixed v14 view | GPU off / on, mean | Added GPU time | Warning-on frame p95 / p99, worst repeat |
|---|---:|---:|---:|
| Open terrain | 7.128 / 7.271 ms | 0.142 ms | 8.383 / 8.420 ms |
| Forest clearing | 6.077 / 6.182 ms | 0.105 ms | 8.385 / 8.432 ms |

Each state used two 600-frame samples after 180-frame warmups, with reversed
order on the second pair. Both views held the 120 rendered FPS cap at actual
3840×2160 output / 2880×1620 internal pixels; no generated frames were counted.
Peak reported video allocation was 4.11 GB, engine static memory 1.41 GB. The
timing run validated a warm v14 cache (10.2 s reconstruction), followed by 71.0 s
scene construction. The initial visual run rebuilt the cache because it belonged
to the stock engine. No competing Godot workloads ran during these samples.
These fixed views establish effect cost, not full-mountain performance or
human skiing acceptance. Reports and six-second diagnostic previews are under
`artifacts/impact_warning/`.

### Reserve and recovery

The **IMPACT RESERVE** bar starts full. Ordinary hops and soft landings have no
cost. A rough landing reduces the bar; an amber cue explains the impact. At 30%
or less, a red cue asks for smooth snow. Recovery starts after 1.25 seconds without
a new damaging impact and restores roughly 16.7 percentage points per supported
second. Airborne time and pause do not refill the bar. Restart restores it fully.

Four separated rough reference-strength impacts spend 30% each: they leave 70%, 40%,
10%, then cause a fall. Smaller impacts spend less; a single event is capped at
65% damage. [Model v13 jump control and validation](JUMP_CONTROL.md) also adds
neutral-steering landing help and equivalent backward skiing.

The existing release-to-hop controls are preserved: hold Space or A/×, then
release. The last supported ledge tick and 75 ms early-landing buffer still work.
Repeated ski probes or immediate terrain recontacts share one impact event, so
one landing cannot unexpectedly drain the bar several times.

## Original model v12 changes

- Removed the `LOST EDGE` and `BODY BALANCE LOST` crash paths and scalar balance
  depletion. Sideways skids still dissipate speed through snow forces.
- Replaced the balance HUD with the impact reserve, impact explanation, low
  reserve warning and recovery feedback.
- Added a supported pose-recovery assist so a rider can regain an upright stance
  after tipping. Normal carving continues through the existing body controller.
- Replaced immediate hard-landing failure with impact damage and normal landing
  response while reserve remains.
- Added swept obstacle contact points and normals. Survived collisions remove
  inward velocity and stop at the obstacle; a light graze can slide past. A fast
  graze is assessed using normal closing speed, not total speed alone.
- Increased physics identity to **12**. Previous model records remain separate;
  release input and snapshot file formats are unchanged.

The implementation follows the user's clarified description of Steep's bar.
The installed Steep English readme, v1.04 G-force notes, also describes recoverable
impact feedback. Neither source establishes exact damage equations or constants:
the following numbers are original Alpine Apex tuning. No Steep assets or code
were copied into the game.

## Inherited rough-contact tuning and units

Rough landings use normal impact speed plus the existing bounded alignment cost.
Default reference severity is 10.5 m/s; settled tuck retains its existing landing
absorption allowance. Obstacle reference severity is 7 m/s of normal closing
speed. These reference values correspond to 30% reserve damage, not an instant
crash threshold.

For effective severity `s` and reference `r`:

```text
damage = min(0.65, max(0, (s / r - 0.55) / 0.45) * 0.30)
reserve = max(0, reserve - damage)
```

Contacts in a 0.30 s group charge their maximum damage once, independently of
probe order. A stronger contact in that group charges only the difference.
After 1.25 s without a new damaging event, supported simulation ticks restore
`dt / 6.0` reserve, clamped to full. Soft contacts do not restart that delay.

The following table is the rough curve (and historical pre-v18 aligned curve).
Current clean landings use the absorption table above.

| Rough normal landing speed | Bar remaining from full |
|---|---:|
| 3.2 m/s | 100% |
| 8.0 m/s | 85.9% |
| 10.5 m/s | 70.0% |
| 14.0 m/s | 47.8% |
| 30.0 m/s | 35.0% (single-event cap) |

`scripts/core/impact_recovery.gd` owns reserve, event grouping and recovery. The
simulation calls it only for measured landings and obstacle impacts; body torque,
heading error and slip pressure are not damage sources. `landing_force` remains
a decaying normal impact speed in m/s for existing presentation consumers. The
HUD's reserve is a gameplay percentage, not a physical accelerometer reading.

`balance` and `balance_pressure` remain inert compatibility fields for historical
diagnostic scripts. The simulation holds them at 1 and 0; they have no effect on
survival, the visible bar, or feedback. Old body torque tuning names remain
because that controller still supplies the force-limited carving pose.

The pose assist activates beyond 1.15 rad roll or 0.70 rad pitch while supported.
It bounds the pose, removes outward angular motion and approaches the requested
stance at up to 2 rad/s until the rider is near it. This is an explicit gameplay
assist, not a claim of unassisted biomechanics. It does not assign root velocity,
add propulsion or turn airborne motion toward a racing line.

## Collision scope

The shared heightfield retains the same terrain and obstacle geometry. Its new
contact query returns the earliest swept cylinder intersection, point and outward
normal, including vertical overlap with the rider. The old reason-only query
remains for route validation and older adapters. A surviving hit projects out
inward velocity at the contact and adds a 2 cm separation to avoid sticking.

Tree/rock collisions on shipped surfaces use reserve damage. Leaving the playable
world remains an explicit boundary failure. Legacy custom surfaces that report a
hit without contact geometry retain their reason-only crash behavior; the solver
cannot safely turn such a string into a physical glancing response.

## Historical v12 verification and limits

Godot 4.7.2 validation on 2026-09-07 passed **956 checks across 13 suites**,
with no reported failures or runtime errors:

| Suite | Checks |
|---|---:|
| Physics | 56 |
| Runtime and input lifecycle | 93 |
| Release jumping and turn transfer | 76 |
| Handling | 84 |
| High-speed turns | 108 |
| Jump mechanics | 90 |
| Skier motion | 19 |
| Turn anatomy | 32 |
| Competitive records | 64 |
| Races | 51 |
| Impact reserve | 44 |
| High-speed balance diagnostics | 219 |
| Technical showcase v7 | 20 |

The showcase suite's automated skiing pilot reached the base along both snow
alternatives without crashing. Ten native D3D12 captures on the RX 9070 were
visually inspected at 1440×900. Runtime and native checks were repeated with the
concurrent menu and lighting updates included; the impact behavior remained the
same. This does not establish human gameplay acceptance or 4K performance.

Run these from the project root in PowerShell:

```powershell
.\godotw.ps1 --headless --script res://tests/physics_suite.gd
.\godotw.ps1 --headless --script res://tests/runtime_suite.gd
.\godotw.ps1 --headless --script res://tests/impact_recovery_suite.gd
.\godotw.ps1 --script res://tests/impact_recovery_playtest.gd '--' --display-mode=windowed --graphics-quality=low --upscaler=native
```

The dedicated impact suite checks graduated damage, zero-bar failure, soft landing
exemption, recovery delay/rate, no airborne healing, reset, contact grouping and
probe order. It also exercises real landings, direct and glancing obstacle hits,
earliest-contact ordering, body self-righting, and repeated turns/broadside skids
without hidden balance damage. Runtime checks cover bar feedback, pause, restart
and the preserved release-to-jump lifecycle.

Generated results, logs and native captures are in `artifacts/impact_recovery/`.
`validation.json` records suite counts and delivered script hashes. Tests use an
isolated project copy with a separate user-data directory; the user's project
plugins and personal records are preserved. The old `handling_upgrade_playtest.gd`
entry point forwards to the current impact playtest.

Native captures distinguish an actual landing and recovery from explicit low-bar
and crash-label diagnostic fixtures. The real rendered landing spent about 18%
reserve and recovered to full on subsequent snow. These are automated physics,
runtime and rendered checks; the final judgment of forgiveness and gamepad feel
still belongs to a human playtest. Capture FPS counters are not a performance
benchmark.

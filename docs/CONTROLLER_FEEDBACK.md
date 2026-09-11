# Controller input and impact feedback

Left-stick X steers and forward Y requests analog tuck, with the existing 0.12
action deadzone. The solver retains its 20% steering correction allowance and
150 ms grace before opening tuck in sustained turns. Center steering with
forward still held to tuck again. L2/LT brakes. Hold R2/RT to prepare, then
release for one fixed-strength hop. Cross/A confirms menus and drops from the
summit. In the air, center the left stick once, then forward/back flips without
L1 at about 1.7 seconds per turn. Held takeoff tuck cannot start a direct flip.
L1 remains optional for flips and fast spins, suppressing the stick tuck request;
keyboard W/up continues to work. W/S or up/down keeps limited airborne pitch
after centering. Release brakes rotation. See
[arcade air control](ARCADE_AIR_V27.md) for current behavior and replay v5.

`presentation/rider_haptics.gd` uses its own instance of the existing contact
observer, sampled after completed 120 Hz ski ticks independently of audio mute.
It queues landing and obstacle onsets, ignoring equipment and near-miss events.
Impacts below **3.5 m/s normal closing speed** are silent, including small
landings, supported bottom-outs and glancing obstacle brushes. Between 3.5 and
14 m/s, severity is `(speed² - 3.5²) / (14² - 3.5²)`: an impact-energy proxy
from the solver's normal closing speed, independent of travel speed and reserve
damage. Both motors and pulse duration increase with severity: 45 to 180 ms,
weak motor 0.08 to 0.55, and strong motor 0.02 to 1.0 before the user's intensity
multiplier. This keeps marginal contacts faint and gives heavy impacts more
range before saturation at 14 m/s. Overlaps use maximum motor strength and
cannot extend one active cluster past 180 ms from its onset. Sub-threshold
recontacts cannot strengthen or extend an active impact.

Supported rock contact above 2 m/s gives a 30 ms weak-motor pulse at most every
450 ms, scaled by the supported rock fraction with a maximum of 0.12. Impacts
take priority. Leaving rock or losing support cancels a rock pulse. Speed,
steering, skidding, impact reserve and persistent crash state produce no rumble.
The existing Vibration setting multiplies both motors (default 0.5).

The effects node applies finite device commands only when a pulse or strength
changes. A final crash impact may finish while its crash view is visible;
subsequent crash state does not repeat it. Other inactive views, focus loss,
restart, disconnect/reconnect, shutdown and zero intensity clear feedback.
Controller connection changes also cancel prepared jump input.

The observer and envelopes never write simulation state. Jump strength, tick
rate and record eligibility remain unchanged by haptics. Current aerial
control uses physics model 28 and replay v5.

Validation separates automatic input/envelope checks, rendered posture review,
and physical-controller comfort. See `tests/controller_input_suite.gd`,
`tests/haptics_suite.gd` and the runtime lifecycle checks. Hardware comfort must
be assessed on the actual controller; synthetic inputs do not establish it.

## Input acceptance audit on 2026-09-11

Production source snapshot:
[`29b1767da65f8dc7d75c4937601381a2096ba5fa`](https://github.com/embrisa/alpine-apex/commit/29b1767da65f8dc7d75c4937601381a2096ba5fa).
The only executable-source change in this audit is the
[rendered controller fixture](../tests/controller_input_playtest.gd): it now
observes neutral input before tuck, checks held-start suppression, reapplies
both trigger axes every frame, verifies landing and isolation, and accepts a
separate output directory. No production mapping, solver or haptic tuning changed.

All runs used Godot **4.7.2.stable.custom_build.ed1daf0bf**, physics **28**, replay
**5**, and the explicit **laboratory v3** or synthetic plane fixtures. The default
v15 Standard mountain was not exercised. Native rendering used **D3D12 Forward+**
on the RX 9070, driver **32.0.31041.1004**, actual **1920x1080**, native resolution
and a 60 FPS cap. This was a functional capture run, not a performance measurement.
Executable SHA-256 identities:

```text
game:    a18ddc9f3ee8fa1915a47d54c3e0d05ec4b10f8ee9deb15d7206b4e23d29bcc9
console: 0c4e9e4d32c3e550189f463efbf16bd7325cd26eae69b6718a40dc4088ef0b0b
```

### Automated evidence

All **388 checks passed**, serially through the exclusive validation guard.
Every guard exited zero with no script/engine errors or reported driver failure.

| Suite | Checks | Relevant coverage |
|---|---:|---|
| [Physics](../tests/physics_suite.gd) | 56 | Existing solver regressions and render-schedule independence; no handling retune. |
| [Runtime](../tests/runtime_suite.gd) | 192 | Prepared/released jump, pause/workbench/focus/restart/disconnect cancellation, haptic lifecycle, camera and scene integration. |
| [Controller input](../tests/controller_input_suite.gd) | 48 | 0.12 action deadzone, analog/diagonal tuck and steering, brake, R2, Cross/A, optional L1, centered direct-stick flips in both facing directions, keyboard priority. |
| [Haptics](../tests/haptics_suite.gd) | 41 | 3.5 m/s threshold, motor envelopes, overlap bounds, rock pulses, intensity/reset and observer independence. |
| [Rider lifecycle](../tests/rider_lifecycle_suite.gd) | 51 | Held spin/flip/grab and limited pitch, direct-stick rearming across pause/disconnect/restart/focus, crash/restart state. |

The source-owned lifecycle boundaries are in [main.gd](../scripts/main.gd) and
[input_router.gd](../scripts/core/input_router.gd):

| Boundary | Current behavior and evidence limit |
|---|---|
| Enter/leave active play | Clears jump preparation/buffer and air intent; resets riding-axis arming. A subsequent tick must observe `abs(steer) + tuck + brake < 0.01` before riding axes are admitted. The rendered fixture exercises this held-start gate; menu motion cannot stand in for centering. |
| Landing / new flight | A grounded router sample clears direct-stick flip arming. A centered airborne sample rearms it; held takeoff tuck cannot directly start a flip. Input tests cover both rider-facing directions. |
| Pause, focus loss, restart, connection change | Prepared jumps, buffered releases and air-control state are cleared. Runtime/lifecycle tests exercise cancellation and fresh neutral/hold behavior. Connection callbacks are synthetic: actual USB/Bluetooth disconnect and reconnect are not verified. |
| Haptic cancellation | Pause/focus/restart/connection change/zero intensity clear pending and active output. The final crash impact may finish while its crash view is visible; persistent crash state adds no rumble. Shutdown resets output in source; physical motor stop behavior remains untested. |

### Rendered inspection and limits

Eight final images were inspected in chronological order: held start, forward
tuck, diagonal turn, resumed tuck, R2 preparation, release/hop, landing, and the
Controls guide. Held start reports zero tuck input; after centering, solver tuck
is **0.99475**, falls to **0.01082** during the diagonal turn, then returns to
**0.99481**. R2 preparation stays grounded; release is airborne; the landing
sample is grounded without a repeated jump or crash. The guide visibly explains
hold/release jumping and centering the stick after takeoff for optional-L1 flips.

The first forward-tuck image is visibly more upright than the resumed-tuck image
despite similar solver values. This is an observation, not proof of an input or
animation defect; [the proposed posture investigation](../backlog/ideas/IDEA-20260911-185650-tuck-presentation-consistency.md)
records the reproducer and uncertainty. Snow also partly occludes skis in the
grounded images. These snapshots do not establish continuous-motion quality,
final tuck/turn pose quality, full-mountain landings or rendered flip quality.

All eight states remain unranked with preferences and physical haptic output
disabled. Their sampled haptic outputs are zero; this is not a continuous pulse
trace or evidence that a real controller feels quiet. Each run used an isolated
`APPDATA` profile under the audit directory, keeping test saves out of the user's
profile. Physical dead zones, trigger travel, wireless lifecycle and vibration
comfort remain unverified.

Local evidence is under `artifacts/input_acceptance_20260911/`: `audit.json`,
`source_before.json`, `source_render_before.json`, and `visual/` contain the
summary, 605 source hashes, executable hashes and final captures. Only the listed
fixture changed from the initial source receipt; all hashed sources and both
executables were stable from the pre-render receipt through final review.
Guard receipts/logs use `artifacts/guarded/input_acceptance_<suite>_20260911/`.
The first native attempt passed but its `res://` output argument was truncated
by the PowerShell launch path; its outputs were preserved in `first_native_attempt/`.
The final rerun verified the project-relative output argument below. Older
controller output was copied to `previous_controller_input_v1/` before testing.

### Reproduce the audit

From the project root, with no other validation workload active, use a separate
profile and run one suite at a time. Wait for an occupied validation lock; do not
bypass it. The native run uses a project-relative output argument to avoid colon
parsing through PowerShell's script wrapper.

```powershell
$auditRoot = (Get-Location).Path
$auditPreviousAppData = $env:APPDATA
try {
    $env:APPDATA = Join-Path $auditRoot 'artifacts/input_acceptance_recheck/profile'
    New-Item -ItemType Directory -Force $env:APPDATA | Out-Null
    foreach ($suite in @('physics_suite','runtime_suite','controller_input_suite','haptics_suite','rider_lifecycle_suite','controller_input_playtest')) {
        $auditArgs = @('-NoProfile','-File',(Join-Path $auditRoot 'godotw.ps1'))
        if ($suite -ne 'controller_input_playtest') { $auditArgs += '--headless' }
        $auditArgs += @('--script',"tests/$suite.gd")
        if ($suite -eq 'controller_input_playtest') {
            $auditArgs += @('--','--output=artifacts/input_acceptance_recheck/visual')
        }
        & ./scripts/run_guarded.ps1 -FilePath (Get-Command pwsh).Source -Arguments $auditArgs -Label "input_recheck_$suite" -TimeoutSeconds 600
        if ($LASTEXITCODE -ne 0) { throw "Audit failed: $suite; inspect the guard logs." }
    }
} finally {
    $env:APPDATA = $auditPreviousAppData
}
```

### Real-device playtest checklist — open

Use ordinary keyboard and controller play; record the device, connection type,
source/build, mountain seed and settings, and mark untested items explicitly.

- [ ] Check centered-stick drift, small corrections, analog steering/tuck and diagonal input; compare turn initiation, sustained carving, reversals and tuck-to-turn-to-tuck transitions with keyboard input.
- [ ] Check full L2/LT brake travel and R2/RT preparation/release: hold stays grounded, release gives one hop, Cross/A only confirms or drops in. Try both clean aligned landings and switch skiing.
- [ ] Hold tuck through takeoff, then center in air and command forward/back flips; compare optional L1, braking rotation by release, and fresh centering after landing.
- [ ] Hold jump/air controls through pause, settings, restart and focus loss; disconnect/reconnect the actual device. Check for stale hops, rotations or vibration, then center/release and make a fresh command.
- [ ] At the chosen Vibration setting, compare tiny versus heavier impacts, supported rock and leaving rock; verify zero intensity and lifecycle cancellation. Judge motor strength, duration and comfort during a real descent.

Record actual feedback in [player/controller acceptance](../backlog/tasks/AA-20260911-153906-player-and-controller-acceptance.md).
This evidence audit does not close that user-gated task.

## Impact threshold retune on 2026-09-11

The user reported vibration from tiny jumps and impacts. The onset threshold
increased from 1 to 3.5 m/s, with a quieter minimum pulse and an energy-weighted
response extending to 14 m/s. The supported-rock texture is unchanged.

Automated validation passed 284 checks: haptics 41, runtime 187, and physics 56.
Coverage includes small landings/obstacle brushes/bottom-outs, progressive motor
strength and duration, overlap limits, lifecycle cancellation, intensity scaling,
and paired solver runs with/without haptic observation. No core physics or replay
sources changed; the model remains 28 and replay remains v5.

The native DX12 controller fixture passed at 1920x1080 on the unranked laboratory.
The hop and landing captures were inspected; all seven captured states reported
zero haptic output. These are sampled states, not a continuous vibration trace.
Hardware output was disabled, so physical-controller comfort remains for the
user's playtest. No new performance claim is made. Evidence is under
`artifacts/controller_input_v1/` and `artifacts/guarded/haptics_*_20260911/`.

## Verification on 2026-09-09

All 612 checks passed: controller input 18, haptics 25, physics 56, runtime 145,
tuck/contact 213, jump 90, and competitive/replay 65. The guarded engine runs
reported no script/engine errors in their final attempts. Source hashes confirm
the only changed core script is the hardware input router; the ski solver,
default tuning and replay source are unchanged.

The production scene was inspected at 1920x1080 on the explicit laboratory
fixture, with hardware vibration disabled and records ineligible. The seven
captures cover tuck, diagonal steering, resumed tuck, R2 preparation, hop,
landing and the updated Controls guide. Measured tuck was 0.9948 before the
turn, 0.0108 after sustained diagonal steering, and 0.9948 after returning
forward. R2 preparation stayed grounded; the release capture was airborne.

Evidence is in `artifacts/controller_input_v1/` and the corresponding
`artifacts/guarded/controller_*` logs. An initial capture attempt did not sustain
its one-shot synthetic forward axis across native frames; the final harness
reapplies axes immediately before each frame's physics steps. The rejected
attempt is retained separately. This is rendered behavior evidence, not a
4K performance measurement or human controller/vibration acceptance.


Menu/controller ownership, repeat thresholds, popup input, device prompts and
HUD editing are documented in [the interface overhaul](INTERFACE_OVERHAUL.md#controller-ownership-and-focus).
They retain the existing rider action mapping and add a neutral-axis resume gate.

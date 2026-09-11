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

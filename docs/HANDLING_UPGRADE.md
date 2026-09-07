# Release jumping and turn response — model v11

Historical v11 report. Model v12 retains release jumping and turn response but
replaces balance deaths and the balance HUD with an [impact reserve](IMPACT_RECOVERY.md).

Implemented 7 September 2026 in Alpine Apex's own Godot ski solver. This applies
the practical recommendations from the Steep study: reliable intent timing,
earlier weight transfer, and readable recovery. These are independently designed
changes, not recovered Steep equations or copied tuning values.

## Playing

- Hold **Space** or the controller's **south face button (A / ×)** to prepare a
  hop; **release to jump**. The HUD shows “JUMP READY / RELEASE TO HOP”. Holding
  longer does not increase jump power or produce repeated hops.
- Release at the last supported moment on a ledge to add the normal small hop.
  Releasing after takeoff cannot boost flight. A release shortly before landing
  can wait for snow contact in a 75 ms buffer and fires once.
- Reverse steering to start transferring into the next turn. Momentum still
  takes time and grip to redirect. Establishing the new turn costs some speed.
- Teal **LANDING**, then **RECOVERING**, indicates a survived impact and returning
  balance. Amber **LOSING EDGE** indicates ongoing balance loss. The bar changes
  colour and label with that distinction; a crash reason takes priority.

Jump preparation and pending releases are cancelled by pause, focus loss,
workbench/menu transitions, restart, finish and crash. A button held through an
inactive screen must return to neutral before a fresh hold/release can jump.
Steering, tuck and brake retain their existing analog strengths and bindings.

## Model changes

`RiderInput.jump` is a release command. `jump_held` supplies readiness feedback
only. The router samples the logical action, while the main game requires a valid
prepared hold after observing neutral in active play. This also handles Godot
exposing a release edge on the following physics tick, and consumes a prepared
release once.

The simulation owns the 0.075 s request buffer. It consumes a request when it has
current support, or support at the start of this same tick before predictive
release. A cached supported frame supplies the takeoff normal. This orders the
hop before the next-height ledge check and prevents that check from silently
discarding the last supported release. A request in open air only ages toward
expiry; gravity and drag continue unchanged. Landing never bypasses impact or
crash checks to accommodate a buffered hop. Successful landing can consume the
request on the next supported tick. Reset and crash clear it explicitly.

The hop still adds **3.2 m/s along the support normal**. There is no added grace
period after losing support, charged jump power, double jump, or air steering
force. The solver remains independent of scene Nodes and rendering at 120 Hz.

Turn transfer retains at least 15% of the ordinary yaw rate while the rider is
banked into the old turn. The existing excessive-slip gate can reduce this
further. During opposed steering/force, the balance controller requests a modest
0.25 rad opposite bank instead of 0.10 rad. Pressure, torque, available grip,
boot motion and body lean limits still determine the achieved motion; neither
body roll nor travel velocity is assigned from the steering input.

HUD recovery is now based on whether balance is actually improving:

| State | Cue |
|---|---|
| Supported; balance pressure exceeds recovery rate | Amber warning to ease the turn |
| Supported; balance below 90%; improving; first 150 ms after landing | Teal landing absorption |
| Supported; balance below 90%; improving after that | Teal recovery / hold a steady line |
| Stable, prepared jump | Release-to-hop instruction |
| Crashed | Crash reason and fallen label |

`landing_force` retains its existing name for consumers, but is a decaying
**normal impact speed in m/s**, not Newtons or g. Telemetry now labels this unit.
`time_since_landing` is an age in seconds used to separate impact and recovery
cues; it does not alter forces. Landing tolerance, balance recovery rate and
obstacle crash rules retain their existing values.

## Measured turn response

Godot 4.7.2, 120 Hz, packed plane with gradient 0.46 (about 24.7°), upright entry.
Hold full steering for 2 s, then reverse for 4 s. “Response” is time from reversal
to opposite signed lateral acceleration exceeding 1 m/s². This measures grip
onset, not the time required to reverse the skier's entire travel direction.
The previous controller is reproduced with yaw fraction 0 and transfer bank
0.10; all other settings and the fixture are identical.

| Entry speed | Previous response | v11 response | Earlier |
|---|---:|---:|---:|
| 60 km/h | 0.8000 s | 0.7667 s | 4.2% |
| 120 km/h | 0.8583 s | 0.7417 s | 13.6% |
| 160 km/h | 0.8917 s | 0.7500 s | 15.9% |
| 200 km/h | 0.9250 s | 0.7833 s | 15.3% |

These upright cases retained full balance and peak slip below 14.3°. Mirrored
and tuck-held variants pass the same regression suite. At the end of the 6 s
fixture, v11 exits about 0.66–1.04 km/h slower than the previous controller:
earlier turn engagement spends momentum rather than supplying a speed boost.
Repeated full reversals every 0.5 and 1 s at 200 km/h also pass.

The study's provisional 0.45–0.65 s target was not used as a reason to exceed
the support limits. More aggressive transfer trials produced body tipping under
rapid 200 km/h reversals; the shipped setting gives a smaller, tested improvement.
No keyboard steering ramp was added: keyboard full-input reversals are covered,
and no hardware playtest established that extra input delay would improve them.

## Verification

**601 checks passed with no reported engine/script errors** across eight suites:

| Suite | Checks |
|---|---:|
| Physics | 56 |
| Runtime, input and lifecycle | 91 |
| Handling | 84 |
| High-speed turns | 108 |
| Jump and natural terrain landings | 90 |
| Turn anatomy and boot limits | 32 |
| Competitive records and replays | 64 |
| New release/transfer regressions | 76 |

The new suite covers last-supported ledge releases, no impulse after takeoff,
early landing requests, expiry, one-time consumption, equal hop power across
hold durations, lifecycle cancellation, recorded command reproduction, old
model rejection, mirrored turn response and rapid repeated reversals.

Tests ran against an isolated copy of the current working tree with imported
assets and a separate user-data directory. Plugins were disabled only in that
copy. The tested changed Godot scripts were compared byte-for-byte with the
delivered repository. The user's plugin settings and personal records were not
used as test storage.

Ten native 1440 × 900 captures were inspected on a Radeon RX 9070 using D3D12 at
Low quality: prepared jump, released hop, actual landing, recovery, restored
balance, turn transfer, opposite turn, comfort view, and explicit warning/crash
HUD fixtures. The latter two are labelled diagnostic fixtures; they are not
claims of a physically induced crash. The new cues and footer fit the viewport,
and the real drop recovered from about 70% to full balance without crashing.

These are automated runtime and rendered checks. Physical keyboard/controller
feel and MacBook performance still require a human/device playtest. Capture-time
FPS counters are not a performance benchmark.

Local generated evidence is in `artifacts/handling_upgrade/`: `validation.json`
lists suite counts and source hashes, `physics.json` contains the comparison,
and `native.json` identifies captures and diagnostic states. Generated evidence
is ignored by Git; these test scripts and this report are source files.

Run from the repository (PowerShell; use `./godotw` on macOS/Linux):

```powershell
.\godotw.ps1 --headless --script res://tests/physics_suite.gd
.\godotw.ps1 --headless --script res://tests/runtime_suite.gd
.\godotw.ps1 --headless --script res://tests/handling_upgrade_suite.gd
.\godotw.ps1 --script res://tests/handling_upgrade_playtest.gd -- --display-mode=windowed --graphics-quality=low --upscaler=native
```

## Records and playtest focus

Physics model **11** creates `laboratory-v3-physics-v11-default` and changes custom
race/replay compatibility through the existing model key. Older model records
are kept separate. Snapshot format remains v2; the four recorded input values
still include the one-shot jump command. Readiness is not required to reproduce
the simulation.

For a manual pass, alternate short and long holds on Space, release at a lip,
release just before touchdown, then hold jump across pause and resume. In the
120 km/h speed lab, compare a held carve with a decisive opposite turn and a
series of quick left-right corrections. Check that the earlier weight transfer
feels useful without making line choice harder. Repeat with the south controller
button and partial stick inputs before choosing further sensitivity changes.

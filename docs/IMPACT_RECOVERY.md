# Impact reserve — model v12

Alpine Apex now uses the impact bar requested after the Steep study. Rough
landings and collisions spend reserve according to severity. Riding smoothly
restores it after a delay. An impact causes a fall when it empties the bar.
Steering, skidding and body lean do not spend reserve or trigger balance deaths.

## Playing

The **IMPACT RESERVE** bar starts full. Ordinary hops and soft landings have no
cost. A rough landing reduces the bar; an amber cue explains the impact. At 30%
or less, a red cue asks for smooth snow. Recovery starts after 1.25 seconds without
a new damaging impact and restores roughly 16.7 percentage points per supported
second. Airborne time and pause do not refill the bar. Restart restores it fully.

This is a severity-based reserve, not a fixed two-hit rule. For example, three
closely spaced reference-strength rough landings spend 35% each: the first leaves
65%, the second leaves 30%, and the third causes a fall. Smaller impacts spend
less; a single impact is capped at 75% damage to make the system forgiving.

The existing release-to-hop controls are preserved: hold Space or A/×, then
release. The last supported ledge tick and 75 ms early-landing buffer still work.
Repeated ski probes or immediate terrain recontacts share one impact event, so
one landing cannot unexpectedly drain the bar several times.

## What changed

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

## Tuning and units

Landings use normal impact speed plus the existing bounded alignment cost.
Default reference severity is 10.5 m/s; settled tuck retains its existing landing
absorption allowance. Obstacle reference severity is 7 m/s of normal closing
speed. These reference values correspond to 35% reserve damage, not an instant
crash threshold.

For effective severity `s` and reference `r`:

```text
damage = min(0.75, max(0, (s / r - 0.55) / 0.45) * 0.35)
reserve = max(0, reserve - damage)
```

Contacts in a 0.30 s group charge their maximum damage once, independently of
probe order. A stronger contact in that group charges only the difference.
After 1.25 s without a new damaging event, supported simulation ticks restore
`dt / 6.0` reserve, clamped to full. Soft contacts do not restart that delay.

| Aligned normal landing speed | Bar remaining from full |
|---|---:|
| 3.2 m/s | 100% |
| 8.0 m/s | 83.5% |
| 10.5 m/s | 65.0% |
| 14.0 m/s | 39.1% |
| 30.0 m/s | 25.0% (single-event cap) |

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

## Verification and limits

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

Run these from the repository in PowerShell:

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
isolated working-tree copy with a separate user-data directory; the user's
project plugins and personal records are preserved. Generated evidence is ignored
by Git. The old `handling_upgrade_playtest.gd` entry point forwards to the current
impact playtest.

Native captures distinguish an actual landing and recovery from explicit low-bar
and crash-label diagnostic fixtures. The real rendered landing spent about 18%
reserve and recovered to full on subsequent snow. These are automated physics,
runtime and rendered checks; the final judgment of forgiveness and gamepad feel
still belongs to a human playtest. Capture FPS counters are not a performance
benchmark.

# Tighter arcade carving - physics v20

The carving calibration below remains active. [Physics v21](TUCK_CONTACT_V21.md)
supersedes the tuck/contact behavior and physics identity described here.

Default handling blends stronger snow carving smoothly above 25% steering input,
reaching full strength at full input. Its speed blend starts at 30 km/h and is
complete at 60 km/h. Small corrections retain v19 behavior. Holding tuck still
uses the existing turn-opening behavior and now receives the same carving upgrade.

## Physical implementation

`SkiTuning` owns calibration; each 120 Hz tick computes effective yaw, bank,
pressure reserve, and ski grip without mutating the shared resource. Full-input
ski yaw demand is 1.20 times baseline, grip capacity 1.40 times, and slip-to-grip
response 1.65 times. These are demands, not guaranteed forces: each ski remains
limited by its actual normal reaction and the rider's available support.

The rider anticipates the turn with a lower supported stance and a deeper bank.
Pressure remains available while that bank builds, then more support becomes
available to hold an efficient carve. During reversals, limited yaw retains the
old supporting edge until the center of mass transfers. A bounded 8 cm physical
pelvis shift goes through the existing leg and boot fitting. Neither body pose nor
input directly assigns root velocity, heading of travel, or extra propulsion.

Friction and lateral grip still share the existing balance budget. Each grip
impulse removes sideways velocity without overshooting it. Braking and sideways
skids remain dissipative. Rock skis retain their original grip values; mixed
contact reduces the shared snow-carving blend. Airborne input authority is
unchanged. The larger recovery envelope only persists long enough for an
established snow bank to settle after release.

The custom solver, controls, assistance roles, camera, 4 m support surface,
terrain identity v13, and replay format v4 remain. Physics v20 separates course,
record, and incompatible replay identities from v19.

## Validation and tuning

Calibration lives in `config/ski_default.tres` and `scripts/core/ski_tuning.gd`.
Run the self-contained checks using the stored v19 numeric regression fixture:

```powershell
./godotw.ps1 --headless --script tests/arcade_carving_suite.gd
./godotw.ps1 --headless --script tests/physics_suite.gd
./godotw.ps1 --headless --script tests/runtime_suite.gd
```

The carving suite checks passive grip, progressive steering, supported bank,
small-input behavior and reference metrics without requiring an ignored source
snapshot. The historical upright curves still isolate disabled carving;
auto-tuck/contact behavior has its own v21 suite. Old before/after projects and
media have been deleted.

User skiing acceptance remains open. Inspect turn initiation, sustained turns,
reversals and tuck-to-turn behavior on keyboard and controller. Measure current
full-mountain performance separately using [the validation guide](../development/VALIDATION.md).

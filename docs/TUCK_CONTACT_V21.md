# Auto tuck and small-bump contact - physics v21

Current [grounded snow v28](GROUNDED_SNOW_V28.md) retains these tuck controls and
layers the requested bounded snow-retention assist over the original passive
contact model. The v21 results and no-retention description below are historical.

Holding forward requests tuck. Centered steering, including analog corrections
up to 20%, keeps it. Larger steering gets a 150 ms grace window before the stance
opens; changing steering direction does not restart that window. With forward
still held, centering steering resumes tuck. Releasing forward or braking opens
the stance immediately through the existing smooth response. A sustained turn
is more than 96% untucked by 450 ms.
The grace window preserves an existing tuck; pressing forward and steering
together from upright does not briefly start a crouch. Float32 replay rounding
at the 20% correction boundary produces the same posture decision as live input.

Default tuck grip and edge-response multipliers are both 1.0. Holding W never
reduces the steering command or ski grip. The physical stance still determines
COM and balance, and tuck still reduces aerodynamic drag. Sustained intermediate
turns now fully open the stance, so they lose the old partial-tuck drag benefit.
The v20 carving response is retained, with the full-input bank target increased
from 1.22 to 1.238 radians to preserve its tighter-path target through the tuck grace.

## Contact model

The existing preloaded two-ski suspension now uses 30/s² spring stiffness and
12/s damping, with the damper reaction limited to 4 m/s². Small motion settles
firmly; rapid terrain compression has a bounded damping reaction. Damping always
opposes normal velocity. Normal contact remains unilateral, and the existing
28 cm leg reach and hard compression stop remain the geometric limits.

A ski that briefly unloaded can regain positive support while descending within
that reach, for up to 180 ms and at no more than 2 m/s normal closing speed. This
avoids waiting for the rider root to collide with snow after a tiny unload.
Deliberate hops, reach-based drops, trick flight and established airtime are
excluded. Faster closing contacts retain the existing landing/impact path.

There is no terrain attraction, root snap, extra gravity, aerial traction,
propulsion or speed restoration. The 120 Hz custom solver and authoritative 4 m
surface remain unchanged. Calibration lives in `SkiTuning`; ticks never mutate a
shared tuning resource. Rider input stays at seven recorded fields and replay
format stays v4. Physics v21 separates records and incompatible v20 ghosts.

## Automated evidence

The comparison baseline is identified as `63ae07b`, the v20 handling the user
preferred. Its core sources were reconstructed and hashed after a concurrent
artifact cleanup. The `tests/fixtures/tuck_contact_v20.json` file stores those
hashes and measurements; tests do not require a local reference copy to run.

On 27 matched six-second 4 m heightfield runs, small ripples of 5, 10 and 15 cm
amplitude, wavelengths 8/16/24 m, and entry speeds 90/120/160 km/h produced:

| Amplitude | v20 total airtime | v21 total airtime |
|---|---:|---:|
| 5 cm | 5.767 s | 0 s |
| 10 cm | 22.433 s | 0 s |
| 15 cm | 32.867 s | 0.683 s |
| Total, 162 s of simulated travel | 61.067 s | 0.683 s |

That is 98.9% less time without support. Across the complete 45-case matrix,
including 25/30 cm amplitudes, every case completed without a crash, negative
contact load, unsupported grip, or a boot contact/reach violation. Larger bumps
still produce substantial airtime; a 30 cm amplitude is 60 cm peak to trough.
The smooth laboratory descent retains zero airtime, and real crests, 12 m ledges,
deliberate hops and repeated hard-impact damage retain their behavioral checks.

`tests/tuck_contact_suite.gd` additionally checks automatic posture transitions,
immediate steering authority with W, low-speed contact, ordinary airborne
gravity, unchanged flight rotation authority, deterministic input replay and
v20 incompatibility. Carving tests retain the historical v19 upright/tuck correction
checks and fixed-angle full-steering acceptance. Obsolete whole-model v19 equality
when carving is disabled is replaced by the historical upright curve comparison;
the v21 tuck/contact changes are independent of that carving calibration.

The 576-case carving matrix and 96 contract checks pass. Across its 32 full-input
racing cases (left/right, forward/backward, upright/forward-held, 60/90/120/160
km/h), mean radius is 25.10% smaller than v19 and the lowest speed ratio at 45° is
100.93%. Initiation, reversals, support and the original 5% small-correction
limits pass. The separate handling suite retains its two-tick mirrored response
and 1% matched-heading speed limits; response differences are compared as integer
ticks to avoid rejecting exactly two ticks through floating-point subtraction.

Physics (56), runtime (126), tuck/contact (213), downhill contact (46), downhill
control (258), handling upgrade (84), high-speed turns (108), high-speed balance
(219), jump, airborne control/pose (35/10), attachment (20), impact recovery (45),
landing absorption (155), rock (32), competitive/replay (65), lifecycle (27) and
production anatomy (71) pass. The final tuck boundary/entry refinements were
followed by fresh physics, runtime and tuck/contact runs.

The legacy `turn_anatomy_suite.gd` remains 31/32: its shin skin/boot hinge twist
assertion measures approximately 13.789° against a 0.05° limit. The same failure
was reproduced on frozen v20, and its behavioral assertion remains intact.
Initial low-damping trials that bounced on the laboratory line, and an over-large
bank trial that missed mirrored reversal limits, were discarded.

Run the current regression and native harnesses with:

```powershell
./godotw.ps1 --headless --script tests/physics_suite.gd
./godotw.ps1 --headless --script tests/runtime_suite.gd
./godotw.ps1 --headless --script tests/tuck_contact_suite.gd
./godotw.ps1 --headless --script tests/arcade_carving_suite.gd
./godotw.ps1 --script tests/tuck_contact_playtest.gd
./godotw.ps1 --script tests/tuck_contact_playtest.gd '--' --timing
```

## Rendered evidence

Matched v20/v21 native captures completed on the cached default v13 mountain,
seed 849205174, at 1920x1080 High/native on the RX 9070. Both runs had identical
runtime source hashes, height/obstacle checksums, starting points and inputs.
The shared main scene, HUD and pose writer were frozen for this comparison while
an independent motion-workshop task changed their live counterparts. Each run
also verified its loaded sources remained unchanged and stayed unranked.

| Native case | Duration | v20 airtime | v21 airtime |
|---|---:|---:|---:|
| Tuck, tap, sustained steer, reversal, recenter | 4.5 s | 0.050 s | 0 s |
| Small bumps, 160 km/h entry | 6 s | 1.058 s | 0 s |
| Left carve, 90 km/h entry | 4 s | 0 s | 0 s |
| Reversal, 120 km/h entry | 5 s | 0 s | 0 s |

All eight runs completed without a crash. These are selected clear fixtures on
the real support surface, not a survey of every mountain route. The brief
steering tap retained full tuck; after sustained steering began at 1.4 s, tuck
was 1.0 at 1.5 s, 0.368 at 1.6 s and 0.010 at 1.9 s. Recentering restored 0.993
tuck by 4.4 s. Sampled v21 support remained positive in all four runs.

Inspected frames show connected boots and body through the tuck transition,
sustained carve and opposite-bank reversal. Some frames on the forest bump
fixture are obscured by trees in the observer view. This camera is only a test
observer; these captures do not establish controller feel or camera comfort.
Local evidence is in `artifacts/tuck_contact_v21/{before,after}_visual/`, with a
short `artifacts/tuck_contact_v21/auto_tuck.mp4` preview.

## Matched High/4K timing

Separate serial runs completed on the RX 9070 using High, 3840x2160 output,
2880x1620 internal FSR2, a 120 FPS cap, clear/day and SDFGI off. Both loaded the
same cached v13 surface and frozen presentation, with identical source hashes
and display settings. Each measured the same four fixtures for 19.5 simulated
seconds after scene/region warmup, with no screenshots during measurement.

| Metric | v20 | v21 |
|---|---:|---:|
| Frame time mean / p95 / p99, ms | 9.165 / 13.853 / 16.318 | 9.040 / 13.818 / 16.676 |
| Render CPU mean / p95 / p99, ms | 1.381 / 2.190 / 2.862 | 1.422 / 2.218 / 2.796 |
| GPU mean / p95 / p99, ms | 7.841 / 11.109 / 11.890 | 7.667 / 11.045 / 11.557 |
| Ski tick mean / p95 / p99, microseconds | 651 / 981 / 1261 | 647 / 971 / 1234 |
| Peak engine-reported video allocation | 5.161 GiB | 5.161 GiB |
| Peak validation-process private allocation | 7.939 GiB | 7.942 GiB |
| Lowest available system RAM | 6.865 GiB | 7.214 GiB |

Mean frame time corresponds to approximately 109 versus 111 FPS. The similar
paired timings do not establish a performance gain, and p95/p99 frames still
fall below the 90 FPS target. These short fixture runs do not establish a full
mountain frame-rate floor. No other Godot/Blender rendering or video encoding ran
alongside these measurements; ordinary desktop background activity was still
present. Both runs exited successfully without a driver-error report.

The original D3D12 screenshot readback did not produce a usable timing sample. A
follow-up size check exposed Godot's stretched logical texture dimensions: a
lightweight native probe confirmed its reported 9216x5184 texture was actually a
3840x2160 rendered image. The timing harness now
sets a 1:1 window/canvas, which the same image probe verified makes both sizes
agree, and checks their dimensions without a mountain image readback. Visual
captures retain image-based pixel verification. The final paired timing results are in
`artifacts/tuck_contact_v21/{before,after}_timing/results.json`.

Controller feel remains the user's playtest acceptance.

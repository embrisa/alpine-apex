# Grounded snow — physics 28

The requested handling target is substantially more planted skiing over ordinary
bumps and rounded rollers. Snow compresses softly and sheds rebound; deliberate
jumps and sharp terrain breaks retain flight. The bounded arcade contact assist
is enabled in the default model, independently of camera, animation and tuck.

## Contact behavior

Loose snow uses a 0.25 spring ratio and twice the firm-contact rebound damping
coefficient and limit. Compression damping stays digressive, with its existing
0.75 limit ratio and progressive compression stop. Leg travel remains 28 cm.
Rock retains the original firm support law.

Small-bank crushing now blends from 0 to 30 km/h. Its local incoming plane still
expires within the bank footprint; yielding remains capped at 30 cm and the local
loose-snow depth. It stores no rebound energy and adds no forward drag or speed
restoration. It does not excavate or persistently deform the terrain.

`snow_contact_assist.gd` evaluates the next ski footprint while the completed
previous tick still has real, positive-load support. Each eligible ski must have
snow at its current and predicted location, within the existing leg reach.
Depth supplies a smooth strength blend, reaching full strength at 12 cm. Mixed
contact contributes only the snow skis' existing load shares.

The aggregate eligible support normal supplies a bounded correction of at most
3 m/s per 120 Hz tick, removing only separating normal velocity. It cannot add
kinetic energy, change position, set a heading or restore speed. The correction
is not counted as a compressive normal load and supplies no extra grip budget.
The ordinary suspension, gravity, snow resistance and grip then integrate as
usual. Support heights, ski placement and compression stops share the same
authoritative contact samples.

Raw surface normals and height chords at 4 m spacing detect changes exceeding
10 degrees relative to the local slope. Height chords also detect discontinuous
ledges whose individual triangles have parallel normals. Absolute slope angle
does not classify a lip. A detected sharp break suppresses retention until
departure/landing or 150 ms of continuously loaded, non-separating smooth contact.

Pending or buffered jumps bypass retention before their supported impulse is
consumed. No retention runs during flight or beyond leg reach. Restart, contact
priming/teleport, departure and transition off snow clear transient history.
The fixed-step owner advances the helper once; ordinary probes and presentation
reads cannot advance its history. Completed diagnostic state reports correction
in m/s, dissipated energy in J/kg, eligible ski count and the release reason.

## Identity and ownership

The shipping model is 28, with replay v5 and eight input fields. Model 27 records
are incompatible. There is no migration or production legacy movement path.
The frozen model-27 copy under `artifacts/snow_grounding_v28/baseline/` exists only
for explicit comparisons; its receipt records original source hashes. Baseline
copies have their global class declarations removed and local core references
redirected so they cannot accidentally use the new tuning/contact law.

The default mountain remains seed 849205174 / v15 / Standard. Map generation,
terrain geometry, input bindings, air controls and the final skeleton writer are
outside this change. Older documentation's blanket prohibition on contact
retention is superseded only by this specifically requested, bounded snow assist.

## Verification

Run guarded workloads serially; respect `artifacts/validation.lock` and existing
Godot/Blender work. These harnesses never open an eligible record session.

- `tests/snow_grounding_suite.gd -- --baseline` measures the frozen model 27;
  the ordinary invocation compares the current model on the same 160 fixtures.
  `--quick` selects eight crossings and `--contracts` runs focused contracts.
- `tests/snow_crush_suite.gd` covers isolated/repeated banks, shallow snow,
  diagonals, ordinary and racing speeds, energy, speed retention and lifecycle.
- `tests/snow_grounding_mountain.gd` loads the validated v15 bake and retains all
  18 matched mountain crossings, including rocks and crashes. Clean completed
  snow crossings also supply the continuous rendered comparison fixtures.
- `tests/snow_grounding_playtest.gd` captures continuous before/after chase views;
  `--timing` runs a separate 4K High/75% Auto FSR ABBA comparison without image
  readbacks during measurement. `scripts/playtest_grounded_snow.ps1` opens the
  controller comparison: Resume to ski, F6 compare, F7 retry, F8 next slope.
- Required physics/runtime plus contact, carving, jump, landing, impact, rock,
  lifecycle and replay regressions remain separate from visual acceptance.
- `tests/snow_grounding_carving.gd` compares all 576 firm-surface carving
  fixtures and 24 disabled-carving pairs with the frozen model. This isolates
  pre-existing carving assertions from changes to snow contact.
- `tests/snow_grounding_timing.gd` measures fixed-step CPU cost on a plane,
  banks and rollers in model order 27/28/28/27. Run it separately from rendering.
  `scripts/check_grounded_snow.ps1 -Stage <stage>` queues each workload through
  the shared validation guard (`contracts`, `banks`, `carving`, `mountain`,
  `solver`, `visual`, `timing`).

The behavioral target is at least 80% less unwanted airtime and fewer takeoffs
over ordinary rounded snow. The isolated minor-bank speed budget remains 1%
while crossing at full activation (at least 30 km/h), including the downhill
matrix's 30 km/h entry cases.
Native rendered comparison, solver cost, capture-free 4K timing and human
controller acceptance must be reported separately. Runtime source/engine and
terrain identities accompany the evidence; historical passing reports alone do
not establish this model's result.

The added contact work is bounded to the two predicted ski footprints and their
local 4 m stencils. Remaining performance work, if measured solver cost warrants
it, is to reuse existing footprint samples and reduce temporary sample
dictionaries. There is no native rewrite or second terrain representation here.

## Current contact results

All 160 matched ordinary-bump fixtures complete with zero airtime and zero
takeoffs, compared with 138.883 seconds and 308 takeoffs in frozen model 27.
These are 4-second synthetic crossings, totaling 640 simulated seconds per
model: 30/60/120/160/200 km/h, aligned/diagonal terrain, glide, corrections,
carving and reversals. Rounded waves include 0.15/0.30 m amplitude at 16 m
wavelength and 0.30/0.60 m at 32 m. Amplitude is half the peak-to-trough height.
The cap is 3 m/s, peak reach is 0.280009 m, and maximum physical ski contact
error is under 0.004 mm. Larger rollers can still exhaust the compression stop;
this is not a claim that every terrain impact has disappeared.

The isolated-bank suite passes 3,582 checks across 648 cases. Fully active minor
deep-snow crossings have no sustained flight or bottom-out and stay inside the
1% bank-versus-plane speed limit. Shallow-snow yielding remains depth-limited.
With drag/friction disabled, the repeated-bank coasting check peaks at
1,543.216 J/kg from 1,543.210 J/kg initially, a 0.0061 J/kg numerical difference
within its 0.05 J/kg energy tolerance.

The slow flat-coast edge case enters at 30 km/h but crosses the bank at
16.62–22.70 km/h, inside the partial-activation band. It stays supported with no
bottom-out, 21.63 cm crushing and 3.63 cm peak body lift. Its exit is 9.610 km/h
versus approximately 10.018 km/h without the bank: 0.408 km/h less, or 4.068%
at that low exit speed. This result is retained separately from the full-speed
1% gate; the test initially applied that gate incorrectly to the partial blend.
No forward force restores the difference. Flat entries at 60/80 km/h retain the
full-speed gate with maximum deviations of 0.096%/0.022%.

The v15 comparison retains all 18 fixed-input routes, including rough terrain
and obstacles. It is not an all-route clearance or speed-retention guarantee.
Two previously nonfatal runs now hit trees (`face_1_band_0`, `face_4_band_1`);
one previous rock crash is avoided (`face_2_band_0`). Additional routes crash in
both models. On `face_1_band_1`, more ground contact exposes rock for 2.058 s
and changes exit speed from 148.876 to 127.627 km/h. On the clean moving snow
crossing `face_2_band_2`, airtime changes from 1.317 s to zero and exit speed
from 148.343 to 143.757 km/h. Existing resistance, collision geometry and
obstacle responses remain active; these route differences are not compensated
by artificial acceleration or reduced obstacle collision.

The primary physics suite passes 56 checks, runtime 170, jump 90, air control
35, landing absorption 155, impact recovery 45, rock 32, attachment 20, rider
lifecycle 51 and competitive/replay 65. Planted snow, tuck/contact, downhill
contact and thick-snow control also pass. The historical v19 carving suite still
fails 231 acceptance assertions and 24 disabled-carving curve assertions. The
frozen-model comparison passes: all 576 firm-surface cases match within 0.00001,
all 24 disabled-carving pairs match exactly, and both models produce the same
231 acceptance failures. These are pre-existing failures, not a green carving
suite; its thresholds were not changed. Detailed receipts are under
`artifacts/snow_grounding_v28/`.

Concurrent work changed air flip tuning and input routing after the baseline
freeze. Those edits are retained; matched snow/carving probes do not use flip
input. The first rendered pass also detected an unrelated concurrent change to
`skier_full_motion.gd`; its failed source-stability receipt is retained as
`visual/attempt_01_sources_changed.json` and is not treated as final evidence.
The next visual attempt was stopped by the guard on a concurrent track shader
compilation error. Guard history preserves that failure. Render receipts now
hash the graphics shader sources as well as core/presentation GDScript.

## CPU timing

The separate headless ABBA measurement contains 14,400 timed ticks, with 120 warm
ticks before each fixture. Equal-size runs are averaged below; both repetitions
are retained in `solver_timing.json`. These are CPU solver measurements, not FPS.

| Fixture | Model 27 mean | Model 28 mean | Added mean | Model 28 p95 range |
| --- | ---: | ---: | ---: | ---: |
| Snow plane | 0.682 ms | 0.830 ms | 0.148 ms | 1.017–1.057 ms |
| Repeated banks | 0.812 ms | 0.987 ms | 0.175 ms | 1.263–1.350 ms |
| Rounded rollers | 0.695 ms | 1.027 ms | 0.332 ms | 1.357–1.390 ms |

The largest model-28 p99 is 1.991 ms; the fixed-step budget is 8.333 ms. Model 27
is airborne for 390 of each roller run's 1,200 ticks, so the roller difference
includes the cost of remaining supported as well as the added contact stencil.
Reusing already sampled footprints is the next local optimization opportunity.

## Rendered evidence and performance

The refreshed native capture passes with stable core, presentation and shader
hashes. It contains 1,080 consecutive 1080p frames (three six-second routes per
model at 30 captured frames/s), using the production chase camera. Physical
foot/binding separation remains below 0.8 mm. The moving snow-only comparison
shows continuous supported travel after the change. Foliage partially occludes
the early view; the other two fixtures include a rock crossing and a stall.
These short sequences do not establish full-descent or controller acceptance.

The separate capture-free ABBA timing pass also passes source/engine checks on
the RX 9070: actual 3840×2160 output, 2880×1620 internal pixels, High, Auto FSR
4.1.1 at 75%, 120 rendered FPS cap, windowed, frame generation and SDFGI off.
Ranges below are the two repetitions, not confidence intervals.

| Route | Model 27 mean FPS | Model 28 mean FPS | Model 28 frame p95 | Model 28 frame p99 |
| --- | ---: | ---: | ---: | ---: |
| `face_1_band_1` | 113.57–116.32 | 95.55–96.34 | 17.01–17.74 ms | 20.51–26.16 ms |
| `face_2_band_2` | 90.84–99.26 | 73.38–86.84 | 18.82–22.70 ms | 25.27–29.48 ms |
| `face_3_band_0` (stalls in both) | 78.65–83.79 | 82.03–85.85 | 20.58–22.33 ms | 26.41–35.18 ms |

The 90–120 rendered FPS target is not consistently met. On the two moving
model-28 routes, mean solver cost is 1.445–1.633 ms/tick, render submission CPU
time 1.831–2.196 ms/frame, and GPU time 8.253–10.727 ms/frame. More supported
travel changes both the camera trajectory and snow-effect workload; the GPU
difference has not been isolated to a specific effect. Do not attribute the
entire FPS difference to the contact helper's CPU cost. The stalled fixture is
retained evidence, not a substitute for sustained downhill performance.

Peak engine-reported video allocation is 3.89 GB and static engine allocation
1.04 GB; these counters are not total process RAM or physical VRAM occupancy.
Raw frame/CPU/GPU/solver statistics and guard memory samples are retained in
`timing/results.json` and the corresponding guarded-run receipt. All FPS values
are rendered frames; no generated-frame result is included.

The controller launcher starts paused on `face_2_band_2` with the normal live
input path, model 28, and record eligibility disabled. Resume to ski; F6 switches
between models, F7 retries the same start, and F8 cycles the measured slopes.
It waits for an idle validation slot and holds that slot until the comparison
window closes. Controller connection and startup state are recorded in
`interactive/ready.json`; subjective feel remains for the user's playtest.

The current handoff reached that paused state with a PS4 Controller detected,
live input enabled and no startup errors. The evidence index is
`artifacts/snow_grounding_v28/receipt.json`; paired continuous clips and
chronological contact sheets are in its `visual/` directory.

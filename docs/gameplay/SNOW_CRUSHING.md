# Small snowbank crushing

Current model 28 uses a **0–30 km/h** activation blend and retains the 30 cm and
loose-depth limits. [Grounded snow](GROUNDED_SNOW_V28.md) also adds bounded
rounded-terrain retention and softer rebound. The sections below record the
original model-26 implementation and historical validation; they are not current
model-28 performance or controller acceptance.

Small loose banks yield beneath supported skis at speed. The effect blends from
80 to 120 km/h, independently of tuck and steering. Compression is capped at
30 cm of bank height and by the available normal loose-snow depth. The existing
28 cm leg suspension is separate. Larger terrain can exhaust the yielding layer
and still produce takeoff.

Each ski retains its incoming contact plane while moving through rising snow.
An entry probe requires the bank to return to that slope within 24 m, with no
rise above 30 cm; broad terrain changes and real drops retain ordinary contact.
The entry search stops at the first trough, allowing separate consecutive banks.
Contact history fades out within that local footprint, and release waits for
the distributed normal's trailing stencil to clear the bank.
The physical contact sample stays between the immutable 4 m surface and the
bottom of its permitted loose layer. Support forces, reach checks, compression
stops and physical equipment use that same sample. Yielding stores no spring
energy and supplies no forward drag or speed-restoration force. Ordinary snow
resistance, braking, turning and air drag remain active.

The fixed-step owner advances transient contact history once per 120 Hz tick.
Queries, including the final contact probe and presentation reads, do not
integrate it. Departure, rock, restart and contact priming clear it. Snow returns
unchanged for a later pass: there is no terrain deformation or accumulated
compaction. Rendering, tracks, survey and crash collision retain the original
terrain, with temporary ski penetration confined to its loose layer.

Read-only per-ski telemetry exposes `crush_m`, `crush_vertical_m` and
`crush_rate_m_s`. Existing bounded snow emitters use the amount and increasing
compression rate for a full powder burst, including grains and mist, without
increasing emitter budgets. Spray is assessed from the production chase camera;
an inspection camera placed inside the cloud is not a reason to reduce it.
Render-only ski burial is reduced as
physical crushing supplies that burial, so the offset cannot be counted twice
or switch abruptly at entry.

Snow crushing shipped in physics model 26 with replay v4. Current physics is
model 27 and replay v5 has eight input fields; [arcade air control](ARCADE_AIR_V27.md)
adds limited pitch while preserving these contact rules and completed physical
pose snapshots. Older physics identities are incompatible; no migration
or retained production movement implementation is provided.

## Validation

`tests/snow_crush_suite.gd` covers isolated and consecutive triangular banks,
diagonal crossings, shallow/deep snow, speed and stance combinations, contact
bounds, speed retention, energy, lifecycle and probe repeatability. Authored
4 m footprints are rasterized onto the real 4 m grid; an isolated nonzero vertex
therefore has an 8 m triangular support footprint. Height means rise above the
underlying slope, not the amplitude of a peak-to-trough sinusoid.

Evidence belongs under `artifacts/snow_crush_v26/`. Automated checks, rendered
equipment/spray inspection, native timings and the user's skiing acceptance must
be reported separately. The default v14 cache remains the routine mountain path.

### Automated contact results

The final contact matrix covers 540 crossings and 2,660 assertions. Among the
162 full-speed, adequately deep cases, there are zero airborne ticks, zero
bottom-out impulses and less than 0.7 cm peak body lift. Maximum transient speed
deviation from the bank-free slope is 0.020%; maximum exit deviation is 0.014%.
The limits apply to both speed loss and speed gain, with ordinary resistance
active and no artificial speed restoration.

An additional 54 diagonal crossings use 20 cm of loose snow beneath 20/30 cm
banks at 120/160/200 km/h. These remain grounded, with maximum transient speed
deviation of 0.064% and maximum body lift of 1.8 cm.

Repeated banks also pass with all forward friction and aerodynamic drag
disabled: peak mechanical energy increases only 0.014 J/kg from 1,543.210 J/kg,
inside the explicit 0.05 J/kg numerical tolerance. This regression protects
against the trailing filtered normal supplying downhill force after crushing.
The incoming plane must expire locally; it must never follow the rider down the
rest of the mountain.

Physics, runtime, tuck/contact, planted-snow, thick-snow control, jump,
landing absorption, rock, spray and competitive/replay regressions pass through
the serial guarded runner. Additional downhill contact, airborne control and
ski-attachment checks also passed in that model 26 validation. Those receipts
used replay format 4 and seven input values per tick. Completed test receipts
and guarded logs record the exact runs.

### Rendered crossings

The matched default-v14 capture uses the production chase camera throughout,
at 1920 x 1080, High/native. It records 75 consecutive frames for each of two
2.5-second crossings, with crushing disabled and enabled (300 frames total).
The full powder/grain/mist burst is retained. Sampled entry, compression and
exit frames show a readable skier, snow displaced around the skis and connected
equipment; no additional pose fitting or camera tuning was introduced here.

Both enabled crossings remain grounded. Peak physical crushing is 3.35 cm and
18.80 cm respectively, while the per-frame rigid boot/foot alignment check
stays below 0.75 mm. Each uses the existing 1,536-particle combined snow budget.
The second matched exit changes from 154.853 to 155.112 km/h because yielding
avoids the bank's normal response. This is a comparison with the same bank and
crushing disabled; the isolated matrix above supplies the bank-free speed check.

Raw frames, completed physical samples, camera settings, terrain checksums and
source hashes are in artifacts/snow_crush_v26/visual/results.json and its
adjacent JPEG files. The observer-camera experiments are superseded evidence.
These scripted crossings do not establish the user's controller-feel acceptance.

### Solver cost

A serial ABBA fixture comparison with the frozen original model 25 uses 1,440
ticks per row. Mean flat-slope solver cost is 0.736 ms for model 26 versus
0.709 ms for model 25. For the bank fixture it is 0.824 versus 0.695 ms.
The two model-26 bank rows have p95 values of 1.247/1.220 ms and p99 values of
1.718/1.623 ms. This measures the added local sampling cost; it is not a rendered
frame-rate measurement or a full-descent guarantee.

### Rendered timing

The separate measurement pass confirms 3840 x 2160 output, 2880 x 1620
internal resolution, High, active FSR 4.1.1, a 120 FPS cap, SDFGI off and zero
generated frames on the RX 9070. Each row covers the same 300 physics ticks,
with 262–273 measured rendered frames and no screenshot readbacks during
measurement. All four crossings remain grounded and boot alignment stays below
0.79 mm. Values below are mean / p95 / p99 in milliseconds.

| Crossing | Frame interval | Render CPU | GPU | Solver tick |
| --- | --- | --- | --- | --- |
| Bank 0, disabled | 9.232 / 15.381 / 18.392 | 2.141 / 2.968 / 3.776 | 6.258 / 9.135 / 9.389 | 1.090 / 1.412 / 1.798 |
| Bank 0, crush | 9.115 / 15.565 / 18.234 | 2.021 / 2.955 / 3.258 | 6.243 / 9.238 / 9.382 | 1.134 / 1.845 / 2.472 |
| Bank 1, disabled | 9.273 / 14.661 / 17.317 | 2.504 / 3.273 / 3.854 | 6.448 / 9.421 / 9.899 | 1.086 / 1.408 / 1.666 |
| Bank 1, crush | 9.480 / 16.563 / 18.905 | 2.356 / 3.125 / 3.850 | 6.476 / 9.460 / 9.588 | 1.471 / 2.619 / 3.060 |

Enabled crossings average 109.7 and 105.5 rendered FPS. Both disabled and
enabled cases have long frame intervals; this short comparison does not
establish a sustained 90 FPS floor. It also does not establish a causal
frame-rate improvement or regression from the small difference between rows.
GPU averages are essentially unchanged; solver work rises during crushing.

The guarded run peaks at 6.48 GiB process-private allocation, with 2.21 GiB
minimum system free memory. Engine-reported video allocations peak at 3.74 GiB.
The guard's aggregate Windows GPU counter exceeds physical VRAM and is not
treated as actual device residency. Per-frame timing, presentation counters,
sources and device settings are in artifacts/snow_crush_v26/timing/results.json;
process diagnostics are in artifacts/guarded/crush_gameplay_timing/guard.json.

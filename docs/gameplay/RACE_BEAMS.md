# Central race beacons

One broad translucent beam marks the centre of each start and finish gate in
races, the library, endpoint authoring and the laboratory. Start uses `#c2e76b`;
finish uses `#ffa96b` with 20% stronger unlit colour. Floating gate labels are
removed; physical arch signage, timing stripes and HUD text remain.

The shaft is 12 m wide and reaches 800 m above the gate, fading over the upper
200 m. Its buried lower 8 m lets sloping snow clip the base naturally. A pale
core, slow helical ribbons, rising light flecks, subtle shimmer and swirling
low mist give it movement and depth. Small flecks fade over 100–350 m to avoid
subpixel noise. The continuous broad shaft remains visible at longer distances.

A soft halo roughly 13 m in diameter follows the actual snow around the base.
Three luminous arcs and wisps rotate around it at about 0.24 radians/s. Its
40×40-cell mesh samples the support surface once at placement; it creates no
colliders. The shaft and halo fade close to the camera to keep the ski-through
opening readable. Normal depth testing and weather fog apply to both.

`scripts/presentation/race_beams.gd` exposes
`build(center, finish, support_surface)`. Add it to its parent before building;
the centre is a world-space snow position. `marker_color(finish)` also supplies
the timing stripe colour. One shared cylinder mesh and two small procedural
materials per gate provide the effect without textures, particle emitters,
lights, shadow casting or GI. The tall mesh has its real bounds and does not
inherit the physical arches' 450 m draw cutoff.

Normal presentation calls `update_effect(dt, animate, reduced_motion)` through
the `race_beam_vfx` group. Race and authoring views advance the local visual
clock; paused races freeze it. Reduced Motion leaves a steady shaft/halo. Hidden
markers skip updates, and existing marker cleanup handles retry and free skiing.
No simulation, timing, terrain, replay, race-schema or persistence rules change.

## Validation

Run one workload at a time through the validation lock:

```powershell
./scripts/run_guarded.ps1 -FilePath (Get-Command pwsh).Source -Arguments @('-NoProfile','-File','godotw.ps1','--headless','--script','tests/race_suite.gd') -Label race_beams_central_final_suite -TimeoutSeconds 600
./scripts/run_guarded.ps1 -FilePath (Get-Command pwsh).Source -Arguments @('-NoProfile','-File','godotw.ps1','--script','tests/race_beams_playtest.gd','--','--graphics-quality=high','--render-scale=0.75','--upscaler=auto','--frame-generation=off','--fps-limit=120','--terrain-gi=off') -Label race_beams_central_rendered -TimeoutSeconds 1000
```

The rendered harness loads the validated default v14 mountain through normal
startup, remains unranked and does not save preferences, races or records. It
checks actual presentation dispatch for running, paused and Reduced Motion;
captures near, passage, authoring, 500 m, 2 km and ridge-obstructed views; and
compares day/dusk/night/snowfall at Low/Balanced/High. Ninety motion frames at
30 FPS show three seconds of the near-gate VFX. Future motion captures use
1920×1080; stills and timing use 3840×2160.

Current outputs are under `artifacts/race_beams_central/`; the earlier twin-beam
artifacts are historical and do not validate this design. `--views-only` skips
timing. `--survey-only` limits the run to library/authoring inspection.
`--base-only` captures elevated daylight/dusk views and a separate motion clip
of the snow halo, writing `base_review.json` without replacing the timing report.

Timing uses fixed near and far views with animated VFX at 3840×2160 output,
75% Auto FSR, a 120 rendered FPS cap and frame generation off. The on/off/off/on
sequence uses 180 warmup and 600 measured frames per sample, without screenshot
readback. `report.json` records frame/CPU/GPU mean and p95/p99, memory, draw calls,
active FSR provider, output dimensions and production source hashes. Static-view
timings do not establish full-descent performance or human skiing acceptance.

### Measured central-beam build, 2026-09-10

The race suite passed all 50 checks. The full rendered run completed with no
failures or shader errors: 22 stills, 90 motion frames and eight timing samples.
Normal race updates, pause, Reduced Motion, retry collision counts and cleanup
on return to free skiing passed. All six production source hashes stayed
unchanged during the run. Rendered inspection includes transparent gate passage,
distinct lime/amber colours, the upper fade and natural ridge occlusion.
The supplemental base review also passed, with unchanged production hashes.
Its elevated daylight/dusk stills and three-second `base_vfx.mp4` show the halo
following sloping snow and its bright arcs moving around the base. The halo is
subtle on sunlit snow and clearer at dusk. `finish_vfx.mp4` shows the lower
approach, rising flecks and mist. Both encoded previews are 1920×1080 at 30 FPS;
their capture/encoding speed is unrelated to the performance samples below.

The RX 9070 used custom Godot 4.7.2 / D3D12 / Forward+, High, 3840×2160 output
from 2880×1620 internal pixels, Auto FSR 4.1.1 and frame generation off (zero
generated frames). The following values are milliseconds. Each row averages two
600-frame sample means; p95/p99 columns show the range of the two per-sample
percentiles, not pooled percentiles.

| View / beams | Render CPU mean | CPU p95 | CPU p99 | GPU mean | GPU p95 | GPU p99 |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Near / on | 1.609 | 2.065–2.482 | 2.510–3.330 | 5.342 | 6.747–6.796 | 6.926–7.023 |
| Near / off | 1.827 | 3.179–3.256 | 3.936–3.952 | 5.335 | 6.764–6.769 | 6.868–6.900 |
| 500 m / on | 0.843 | 1.123–1.150 | 1.312–1.511 | 5.342 | 7.048–7.092 | 7.347–7.449 |
| 500 m / off | 0.826 | 1.097–1.099 | 1.249–1.332 | 5.353 | 7.152–7.198 | 7.451–7.474 |

| View / beams | Frame mean | Frame p95 | Frame p99 | Draw calls |
| --- | ---: | ---: | ---: | ---: |
| Near / on | 8.333 | 8.468–8.512 | 8.567–8.804 | 698 |
| Near / off | 8.333 | 8.551 | 8.656–8.683 | 696 |
| 500 m / on | 8.333 | 8.447–8.453 | 8.531–8.541 | 258 |
| 500 m / off | 8.333 | 8.436–8.439 | 8.589–8.640 | 254 |

All views held the 120 FPS cap. The GPU mean difference was +0.006 ms near and
−0.011 ms at 500 m, within the observed sample variation. These short, capped
samples do not establish a precise incremental cost. Godot reported about
1.304 GiB static memory and 3.857/3.875 GiB video memory in the near/far views;
these are engine counters, not total process peak RAM. Image readback and video
encoding were excluded from timing. The user’s skiing/visual acceptance remains
separate from these automated and rendered checks.

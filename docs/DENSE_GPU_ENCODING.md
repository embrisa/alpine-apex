# Dense-scene vertex-storage investigation

The 2026-09-14 candidate is rejected. No rendering optimization ships, and
[the GPU task](../backlog/blocked/AA-20260912-105302-reduce-dense-scene-gpu-cost.md)
remains blocked. UV packing reduced ten meshes' vertex/attribute streams by
20%, but dense FPS improvement did not establish a reliable gain and local
vegetation became slower. Runtime files were restored byte-for-byte to Dev 34,
`41631621a5841777a26e815333eb6fc1a813303b`.

The [structured receipt](DENSE_GPU_ENCODING_RESULTS.json) contains every trial,
native interval, memory observation, identity and input hash. Detailed attempts,
source archives and captures remain in `artifacts/dense_gpu_20260914/`; production
logs remain in `artifacts/pc_environment/dgp-forest-*`. This narrow comparison
does not close the broader [rendering-baseline prerequisite](RENDERING_BASELINE.md).

## Mechanism and rejected refinements

Fresh native profiling ranked depth at 4.468 ms and opaque at 2.665 ms, ahead of
reconstruction at 1.626 ms and motion at 0.725 ms. These are shared scene intervals;
per-family coverage and physical bandwidth saturation were not established.
They identify where to investigate, not a removable-cost estimate for all trees.

A native 78-surface index inventory found little remaining cache-reorder headroom.
An LRU32 CPU simulation estimated 2.103% fewer misses across maple, 4.237% across
golden, zero across spruce and a 0.001% regression across fir. Exact ordered
triangle multisets matched after reordering. This is a CPU model, not measured
GPU misses; no runtime index-order candidate was built or timed.

The chosen storage experiment targeted uncompressed forest render streams:
40 bytes per vertex versus 24 in already-packed examples. Full native attribute
compression could remove 40% of those stream bytes, but failed normal/tangent
preservation: 1,125,382 focused checks, 26 failures, with normal error reaching
3.085 radians. It also encountered more uncompressed species than the initial
fixture expected. Position errors were small; that did not make the changed
basis acceptable. The native packed format encodes the tangent frame as a
rotation, but the exact source of this basis mismatch was not isolated. That
variant was rejected before production timing and retained in
`full-attribute-rejected/` and `encoding-tests/`.

The final refinement packed only UV/UV2 in maple/golden near and mid meshes.
It kept source position, normal, tangent, color and index bytes, material and
bounds intact. Native UNORM16 UV bytes were exposed as two RGBA8 custom vertex
attributes and decoded in the existing tree vertex shader; two per-instance
parameters supplied the flag and UV scale. A derived-mesh cache was populated
before skiing. There was no new per-frame packing, selection, transform upload
or temporal instance reordering. Original asset meshes continued to serve
seating/contact readers; far cards and shadow meshes were unchanged.

Ten meshes used 32 instead of 40 bytes per vertex: 14,228,560 to 11,382,848 bytes
across their vertex/attribute streams. Golden 01 near/mid exceeded the 0.001 UV
error gate and retained their original meshes. The final suite passed 355,860
checks with maximum accepted UV error 0.000715 and branch-pivot error 0.000249 m;
cluster identities and original basis/index/color data remained exact.
The first UV-only attempt's two precision failures remain in `uv-tests/`.

The 2,845,712-byte stream reduction is not a net memory saving: original resources
coexist with derived meshes, whose indices and resource overhead add further
cost. Encoding took 195 ms in the headless fixture, 226-238 ms in local timings
and 244 ms once during the production startup. The experimental implementation
used the pinned engine's serialized ArrayMesh surface format, adding a maintenance
dependency. The complete final six-file candidate is preserved with hashes in
`uv-candidate-source/`; none of it remains active.

## Matched measurements

All production arms used the same compatible 1,800-tick ordinary forest trace,
generator 15/model 35, existing Standard physical archive, High, 3840x2160 output,
2880x1620 internal, Auto selecting FSR 4.1.1, clear weather, the saved weather
quality override, FG/GI off and no frame cap. Godot 4.7.2 `ed1daf0bf`, Forward+
D3D12, RX 9070 executable SHA-256 was
`0c4e9e4d32c3e550189f463efbf16bd7325cd26eae69b6718a40dc4088ef0b0b`.
Trace SHA-256 was
`5eefea368f5d6fcbab00929738e3c992160152b3875315d2063c47cffb9dfbd0`.

Each arm used three 15-second repetitions with 240 warmup frames per repetition,
one process startup shared across the three. Timings were capture-free and held
FpsCritical admission; preparation used Exclusive admission and explicit full
mountain reasons. Every endpoint matched numerically; focus losses, source drift
and observed competing Godot processes were zero. All timed physical/scenery
caches hit. The before/return source inventories matched across all 1,179 files.
This checks enumerated source and executable identity, not a complete frozen
binary/imported-asset inventory or synchronized clocks/queue/residency analysis.

| Arm | Individual rendered FPS | Median GPU mean ms | Median frame p95 / p99 ms | Individual maximum frame ms |
|---|---|---:|---:|---|
| Before | 69.79 / 69.33 / 68.66 | 11.930 | 18.299 / 23.546 | 33.058 / 27.870 / 44.659 |
| UV candidate | 70.32 / 68.89 / 70.19 | 11.794 | 18.248 / 23.071 | 96.388 / 40.594 / 25.643 |
| Restored return | 69.50 / 69.64 / 69.56 | 11.843 | 17.943 / 22.840 | 40.557 / 29.900 / 26.507 |

These are medians of run statistics, not pooled percentiles. Candidate median FPS
was 1.23% above the first before and 0.91% above the return; individual ranges
overlap. Compared with the return, GPU mean fell only 0.42%, render CPU rose 2.10%,
p95 rose 1.70% and p99 rose 1.01%. The 96.388 ms first candidate repetition and
88.222 ms first profiled candidate repetition are retained, not discarded as
warmup. Their cause is unresolved; asynchronous samples do not prove a shader
compile, streaming or GPU stall. Return median 69.56 FPS remains 20.44 FPS below
90; p95/p99 exceed 11.1/16.7 ms by 6.843/6.140 ms.

The local vegetation map used the same scenery camera, 384 trees and three
independent six-second processes per arm. Before FPS was
154.60 / 158.76 / 153.00; candidate was 152.98 / 154.66 / 150.83. Median FPS fell
1.05%, GPU mean rose from 5.247 to 5.354 ms, and p95/p99 rose from
8.245/9.691 to 8.472/9.977 ms. These local component results are separate from
Standard mountain performance. The mixed map was not timed for this rejected pilot.

Separate native profile processes produced 68.96 FPS before and 68.74 candidate.
The maintained interval parser trimmed four query frames at each boundary,
retaining 1,025 before and 1,022 candidate frames with resolved valid timestamps.

| Native interval | Before ms | Candidate ms |
|---|---:|---:|
| Depth pre-pass | 4.468 | 4.377 |
| Opaque | 2.665 | 2.639 |
| Reconstruction, engine marker `FSR2`, actual FSR 4.1.1 | 1.626 | 1.639 |
| Motion | 0.725 | 0.734 |
| Directional/spot shadows | 0.446 | 0.455 |
| Glow | 0.434 | 0.441 |
| SSIL | 0.364 | 0.370 |

Depth plus opaque fell about 0.117 ms in these two profiles. That difference is
not a repeatable total-frame win or proof of tree bandwidth attribution.
The 20% reduction applies to selected source stream bytes; it cannot be multiplied
by the complete shared-pass time as an expected saving.

Whole-process dedicated allocation peaks were 4,578,365,440 / 4,619,522,048 /
4,578,365,440 bytes for before/candidate/return. Private-byte peaks were
6,288,379,904 / 6,326,730,752 / 6,342,873,088. These include startup and are Windows
allocation observations, not physical VRAM occupancy. System free memory minima
were about 2.4-2.7 GiB; background processes are retained in `system.json`.
Source-specific warm startup readiness was 59.307 / 53.065 / 50.882 seconds;
this sequence does not establish a startup improvement from the candidate.

## Verification and next gate

Matching native local detail, overview and riding stills were inspected from
`uv-candidate-capture/` and `return-capture/`. No gross missing trees, silhouette
change or texture corruption was visible at those views. These captures use the
120 cap and are not timing acceptance. They do not establish chronological
FSR/motion-blur, wind/contact, canopy, weather, quality-tier or human/controller
acceptance. The focused encoding suite passed; the full graphics/weather matrix,
open/mineral/stress controls and capped production comparison were stopped after
the primary performance gate failed. No physics/input/session behavior changed.

Reopen on a new measured cost premise: obtain pass/object-level coverage that
distinguishes geometry/deformation from cutout/fragment work, account for static
versus dynamic submission and any moved cost, then test one equivalent-quality
mechanism. Do not repeat UV packing or index reordering based only on reduced
stream bytes. Resolve the broader baseline gate and complete the task's remaining
controls/visual matrix before accepting a production candidate. Tree selection,
stand representation and occlusion remain with their separate task owners.

Recompute this receipt without engine execution:

```powershell
python artifacts/dense_gpu_20260914/report.py --verify
```

To reproduce production timing, use a fresh label with the existing trace and
the documented guard; do not overwrite the retained outputs:

```powershell
./scripts/run_guarded.ps1 -FilePath pwsh -Arguments @('-NoProfile','-File','scripts/benchmark_pc.ps1','-Label','dgp-new-before','-InputTrace','artifacts/dense_gpu_20260914/traces/forest.json','-ScenarioReplay','-TrialStartSeconds','0','-TrialSeconds','15','-Repetitions','3','-FrameCap','0','-Upscaler','auto','-RenderScale','0.75','-TerrainGI','off','-FrameGeneration','off','-ProfileFrameCosts') -Label dgp-new-before -WorkloadMode FpsCritical -TimeoutSeconds 300 -CollectGpuMemory -FullMountain -FullMountainReason 'Source-matched cached Standard forest comparison for a new GPU mechanism.'
```

Profiles add `-ProfileGpuPasses` to the child arguments and select one repetition
and another label. The local wrapper owns its guard:
`./scripts/benchmark_targeted.ps1 -Map vegetation -Camera scenery -Seconds 6 -Repetitions 3 -FrameCap 0 -Output artifacts/dgp-new-local`.
Use a fresh native capture separately with `-Capture -FrameCap 120`.
Current runtime contracts and skill commands are unchanged by this evidence-only
delivery; performance/validation skills were reviewed and required no changes.

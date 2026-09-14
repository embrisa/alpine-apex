# Rejected forest selection experiment, 2026-09-14

The CPU near/mid selector is **rejected**, and the task remains **blocked**. It removed 22.83% of scene-wide submitted primitives but reduced median dense-route FPS from **70.13 to 59.14**. GPU mean rose **12.65%**; p95 and p99 frame times rose **38.42% and 39.42%**. Restoring the original source returned median FPS to **69.80**. All experimental runtime changes were restored; this milestone delivers the findings and receipt, with no runtime optimization.

The [machine receipt](FOREST_SELECTION_RESULTS.json) retains all 21 local and nine dense timing trials, two separate native profiles, validity checks, source identities, CPU costs and memory observations. Raw evidence and the exact rejected source are retained locally under [forest_selection_20260914](../artifacts/forest_selection_20260914/); production receipts are under `artifacts/pc_environment/fs-forest-*`. These ignored artifacts are retained for the unresolved investigation, not distributed runtime dependencies.

## Experiment and identity

The fresh baseline was Dev 33, `e362ce7fa94f8f9fd72c0a70fd7d12dfb340d4ab`. All dense trials used Standard seed 849205174, generator 15, model 35, 120 Hz, the same 4 m heightfield and 200,000 physical trees. The source-compatible ordinary scenery-camera trace was reused without modification; SHA-256 is `5eefea368f5d6fcbab00929738e3c992160152b3875315d2063c47cffb9dfbd0`. Every dense timing/profile run reports the same numerical 1,800-tick endpoint, height/obstacle identity, zero unfocused frames, 240 warmup frames, both cache hits, unranked operation and no crash. The slow, approximately 74 m dense sample does not establish high-speed or whole-route coverage.

Hardware was Ryzen 5 5600X / Radeon RX 9070, custom Godot 4.7.2 Forward+ D3D12. Output was 3840 x 2160, internal 2880 x 1620, High 7, Auto FSR actually 4.1.1, FG/GI off and uncapped rendered frames. Engine SHA-256 was `0c4e9e4d32c3e550189f463efbf16bd7325cd26eae69b6718a40dc4088ef0b0b`. All timing processes used FpsCritical guards. Existing physical archives were loaded; source-specific scenery preparation ran explicitly under Exclusive. No physical mountain was baked.

The [plan](../artifacts/forest_selection_20260914/plan.json) predates the edits. Order was local vegetation and mixed baselines, dense baseline, successive local refinements of one CPU strategy, final mixed candidate, dense candidate and its separate GPU profile, original-source local/dense returns, then the original-source GPU profile. Candidate rejection ended the larger acceptance matrix. This is a documented early stop after a failed leading gate, not completion of the planned open/mineral/stress/capped/counterbalanced acceptance sequence.

The benchmark's 1,179 source entries match exactly between the first dense baseline and return. The candidate differs only in two rendering files, the new selector and two focused test scripts. Its three archived runtime scripts match the measured hashes. The archived native fixture additionally includes shader-uniform assertions run after timing. This is source and engine receipt verification; it is not a new complete frozen/imported-asset integrity audit. No assets, import settings, existing UIDs, solver, input, collision, preferences or race code were edited.

## One bounded strategy

The prototype selected only resident near/mid geometry. It retained the original far cards, readiness fallback and independent shadow resources. It read immutable placement buffers, transformed crown spheres and existing padded geometry bounds; it retained both contributing fades and conservatively tested the union of explicitly supplied camera views. Production supplied its current viewport camera at `frame_pre_draw`.

Refinements removed synchronous per-batch render-server parameter reads, cached the exact configured LOD ranges, added an outer crown-sphere rejection and typed the inner arrays. The final cache tolerated at most 1 m translation or 2 degrees of rotation, with conservative displacement margins; projection, camera, quality and residency changes invalidated selection. Source order was preserved. At most two immutable subset MultiMeshes were retained per resident batch, each with original batch capacity and a selected visible prefix. It never rewrote an existing tree into a different tree's temporal slot.

Pinned-engine inspection matters: `mesh_storage.cpp` associates previous/current transforms by instance slot, so overwriting a compacted buffer can create wrong-tree velocities. Newly initialized immutable resources fill matching temporal halves. Native readbacks verified this association. The renderer also routes recently changed MultiMeshes through its dynamic/motion handling; new-resource publication has costs beyond copying transform bytes. No native engine patch was made.

## Measured results

Statistics below are medians of individual run statistics, never pooled percentiles. All three FPS values are retained, including first encounters. Local maps use the maintained explicit scenery camera and three independently launched six-second trials; their results describe production components, not whole-mountain FPS.

| Local process | FPS, repetitions 1 / 2 / 3 | GPU mean ms | Frame mean / p95 / p99 ms |
|---|---|---:|---|
| Vegetation baseline | 154.81 / 155.35 / 156.46 | 5.267 | 6.437 / 8.270 / 9.492 |
| Mixed baseline | 145.43 / 147.36 / 147.56 | 5.660 | 6.786 / 8.717 / 9.999 |
| Initial working vegetation selector | 121.28 / 129.10 / 133.52 | 5.224 | 7.746 / 10.556 / 14.811 |
| Cached-range refinement | 145.95 / 145.72 / 144.43 | 5.060 | 6.863 / 9.201 / 11.765 |
| Final vegetation candidate | 150.99 / 149.21 / 151.77 | 5.141 | 6.623 / 8.592 / 11.295 |
| Final mixed candidate | 143.34 / 142.87 / 142.39 | 5.516 | 6.999 / 9.056 / 12.325 |
| Vegetation baseline return | 155.79 / 152.73 / 151.98 | 5.316 | 6.548 / 8.423 / 9.928 |

| Dense process | FPS, repetitions 1 / 2 / 3 | Frame mean / p95 / p99 ms | GPU / render CPU ms | Draws / primitives M |
|---|---|---|---|---|
| Baseline | 68.80 / 70.13 / 70.47 | 14.259 / 18.037 / 21.409 | 11.781 / 2.120 | 1617.3 / 13.721 |
| Candidate | 59.14 / 58.08 / 60.20 | 16.908 / 24.966 / 29.849 | 13.270 / 2.278 | 1621.3 / 10.588 |
| Baseline return | 70.43 / 69.80 / 69.44 | 14.327 / 17.815 / 21.160 | 11.895 / 2.152 | 1616.8 / 13.722 |

The two unchanged dense process medians differ by 0.47% in mean frame time and 0.97% in GPU mean; p95/p99 differ by about 1.2%. This narrow return supports rejection of the approximately 15% FPS regression. It does not close the broader [blocked rendering-baseline prerequisite](RENDERING_BASELINE.md), nor establish a generally repeatable acceptance environment. Draw counts did not decrease materially: the useful observed reduction is submitted primitives, which do not equal rasterized triangles or isolated tree cost.

The candidate made 152 selection updates in each 15-second trial. Mean update cost was 5.955 / 5.760 / 5.756 ms, with maxima 18.003 / 18.548 / 18.453 ms. Packing means were only 11.3-14.5 microseconds per new subset, while publication means were 139-182 microseconds. Those nested scopes are included in selection and must not be added to it. They measure CPU API work, not asynchronous GPU transfer completion. CPU list traversal dominates this implementation's measured selection cost; a native packing rewrite alone is not supported by that evidence.

At the endpoint, 1,012 selected batch records represented 2,560 resident near/mid instances; 124-126 were selected. These are endpoint residency counts, not a frame-integrated per-LOD or frustum inventory. There were 1,112-1,113 cached variants containing about 143.5 kB of CPU transform payload. Cumulative `uploaded_bytes` reached 568,032 bytes by repetition three, including startup and warmups. That counter counts each API payload once; it is **not measured upload bandwidth**, and native temporal allocation initializes two halves. Cache bytes exclude resource overhead and doubled GPU storage.

Peak reported video allocation was about 3.833 GB before, 3.824 GB candidate and 3.834 GB return; this is allocator telemetry, not physical VRAM occupancy. Scene-ready times were 53.387 / 53.644 / 49.496 seconds, one warm-cache startup per process. No cold-start improvement is established. Resident regions, pending jobs, render batch counts and prepared source bytes remained 78, zero, 5,903 and 9,600,000 at the endpoints. Long production traversal and cancellation remain unaccepted.

## Separate native attribution

These one-repetition profiles are excluded from the timing comparison. Verified consecutive start-marker intervals exclude four boundary frames per end, leaving 879 candidate and 1,007 return frames; no dropped query frames occurred. The marker named FSR2 encloses the actual 4.1.1 provider. Repeated names are summed per resolved frame and nested totals are not added.

| Native interval, mean ms | Candidate | Baseline return |
|---|---:|---:|
| Depth pre-pass | 4.971 | 4.488 |
| Opaque | 2.510 | 2.673 |
| Motion | 0.912 | 0.725 |
| Directional/spot shadows | 0.552 | 0.448 |
| FSR provider | 1.796 | 1.627 |
| Glow | 0.530 | 0.435 |
| SSIL | 0.447 | 0.365 |
| Transparent | 0.367 | 0.310 |

The modest opaque saving does not offset the increased depth/motion and total GPU times. Increases also occur in unchanged post-processing passes. Without synchronized clocks, queue/wait and residency evidence, these intervals do not prove why every GPU pass changed. A GPU/native rewrite is therefore not justified by the primitive count alone. The next technical gate is a substantially cheaper required-list path plus attribution of publication/temporal-renderer costs, followed by fresh matched FPS/GPU/tail evidence. It must preserve temporal tree identity and prove an end-to-end gain before the remaining acceptance matrix resumes.

## Correctness evidence and remaining acceptance

The candidate passed density LOD (384 checks), spatial (34), colorful forest (200), foliage sight (232), native forest preparation (3,845), final differential selection (23,121) and final native selection (1,957). The native suite inspected 14 temporal buffers and checked exact source transforms, unchanged base/shadow storage, retained LOD shader parameters, three quality tiers, reversal/teleport, bounded caches, re-entry and retirement. Differential fixtures covered scaled/rotated crowns, bare assets, both fades, conservative frustum/camera drift and two-view union. These finite fixtures do not constitute complete delayed-job/cancellation or visual-motion acceptance.

Six separate native local PNGs were captured at cap 120. Matching detail/overview images and the candidate riding still were inspected: tree placement and visible silhouettes agree at those sampled views. The captures are marked non-performance evidence. They do not establish dense chronological FSR/motion-blur quality, wind/contact behavior, canopy 0/50/100, daylight/snowfall, all supported quality tiers or human/controller comfort. The normal capped production comparison, open/mineral controls and 170 km/h stress were not run after the failing dense gate. The requested complete per-LOD/zero-coverage/transition diagnostic inventory was not finished for this candidate.

Rejected setup attempts remain recorded: an unbound GDScript API in the native fixture, a typed-array fixture mismatch, a bool/float assertion typo, and a bare/dead-asset null crown override that aborted the first local candidate before timing. Corrected runs use fresh labels. No invalid attempt was promoted into a performance result.

The final delivered scope is this report, its receipt, the blocked task record and the development note. Runtime files are verified byte-for-byte against Dev 33; experimental scripts and their new UIDs are retained only in the ignored rejected-source archive. No maintained command or runtime ownership contract changed, so the reviewed performance/validation skills and domain guides require no change for this negative result.

Recompute the retained receipt with `python artifacts/forest_selection_20260914/report.py --verify`. The [Validation guide](VALIDATION.md#performance-method) remains authoritative for future measurements. A future passing candidate still requires the task's complete controls and rendered checks; this investigation does not mark those boxes complete.

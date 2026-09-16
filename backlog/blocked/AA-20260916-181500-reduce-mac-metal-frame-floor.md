---
id: "AA-20260916-181500-reduce-mac-metal-frame-floor"
title: "Attribute and reduce the remaining Metal GPU frame floor on the Mac build"
status: blocked
priority: P2
depends_on: []
created: "2026-09-16T18:15:00Z"
updated: "2026-09-16T21:59:44Z"
source_thread: null
---

# Attribute and reduce the remaining Metal GPU frame floor on the Mac build

## Current disposition — 16 September 2026

Blocked for further pass attribution: Xcode Metal capture/counters are unavailable
on the documented Mac setup, and repeated configuration toggles did not isolate
the remaining floor. Resume when that capability or another specific attribution
method is available; do not automatically repeat the matrix. Generic powder and
environment implementation belong to the linked active tasks.

Delivered: Auto bilinear on Metal, packaged Apple Silicon native skier kernels,
Metal128 powder mesh, common disc trim and faded-track discard. Older Windows-only
native-library statements below are superseded. Fable's 24.7 ms / 40.4 FPS sample
is preliminary configuration evidence: 240 rendered warmup frames change the
route start with FPS, profiling remains enabled, focus/early-end validity is not
enforced, and no Metal pass timestamps were collected. Zero-cost and exact-fill
attribution claims below are hypotheses, not established findings. Two worker
aborts remain unresolved; the streaming task owns that follow-up.

The user's review of the 25 cm relief is still pending. Branch/commit instructions
below are historical; follow the current shared-main contract.

## Outcome

Raise the Mac build's rendered frame rate beyond what the upscaler change
delivers, by attributing the remaining 27.6 ms mean frame at High on an Apple
M4 with spatial upscaling and MSAA 2x, and reducing measured costs without
changing the Windows presentation or physics.

## Current state and evidence

- The first Mac baseline is [MAC_PERFORMANCE_BASELINE.json](../../docs/MAC_PERFORMANCE_BASELINE.json)
  (2026-09-16, stock Godot 4.7.2 Metal, Apple M4, 3600x2260 fullscreen backing,
  standard mountain, fixed full-tuck input, 25 s per configuration, one run each).
  Headline: Auto = FSR 2 at 0.75 internal scale 40.0 ms per frame; bilinear at
  0.75 24.7 ms; bilinear at 0.5 18.6 ms; native 1.0 35.9 ms. The same-code
  branch comparison is 39.1 ms FSR 2 versus 27.6 ms bilinear plus MSAA 2x
  (25.6 to 36.3 FPS). These are configuration deltas, not isolated pass times.
  The branch
  `fable/mac-spatial-upscaler` resolves Auto to bilinear on Metal and lowers the
  internal resolution floor to 50 percent.
- Scripted CPU is 5.5-6 ms per frame at 25 FPS (simulation about 2.5, animation
  tick 1.4, pose 0.5, effects 0.25) and render-thread CPU p95 about 1.2 ms.
  This suggests substantial GPU or presentation cost, but subtracting these
  overlapping CPU scopes from frame time does not establish GPU milliseconds.
- Single-feature deltas from the 38.5 ms FSR 2 reference (same route): sun
  shafts off -2.0 ms, highlight glow off -2.5, local powder patch off -3.0,
  shadows 60 m/filter 0 -0.8, minimum tree distances 0.0 (26 percent fewer
  draws, no time change), everything minimised plus weather 0 -7.5, Low preset
  -9.7. Pixel-proportional cost is about 11 ms between 1.0 and 0.75 scale and
  6 ms between 0.75 and 0.5. This makes pixel work a useful hypothesis;
  terrain, forest coverage, fog, glow and tonemap still need attribution.
- `RenderingServer.viewport_get_measured_render_time_gpu` returns no samples on
  Metal, so pass attribution needs Xcode's Metal frame capture or GPU counters,
  or continued configuration toggles. The Windows native pass profiler does not
  apply. The shipped native skier library is Windows x64 only, so Mac keeps the
  GDScript solver ([Performance handoff](../../docs/PERFORMANCE_HANDOFF.md#mac-and-next-experiments)).
- Launch through `open -n -W -a Godot.app --args ...` (as the fixed `godotw`
  does for windowed runs); a shell-exec window is occluded and blocks in
  `CAMetalLayer nextDrawable` for about one second per frame, invalidating FPS.
  `--script` runs still exec directly and need the `open` path plus
  `ALPINE_FULL_MOUNTAIN=1` and a reason in the environment.
- Related Windows-side tasks own the same passes generically:
  [environment and screen passes](../tasks/AA-20260916-084510-trim-environment-and-screen-passes.md),
  [powder patch](../tasks/AA-20260916-084507-reduce-powder-patch-render-cost.md),
  [vertex shader transcendentals](../completed/AA-20260916-084513-reduce-vertex-shader-transcendentals.md),
  [terrain LOD](../tasks/AA-20260916-084505-fix-terrain-mesh-lod-selection.md). This task
  is the Mac measurement and platform-specific defaults; shader and pass
  changes that also help Windows should be delivered under those tasks.

## Agreed decisions and scope

Own Mac-specific defaults and measurement: `scripts/presentation/pc_graphics_settings.gd`
platform resolution, `graphics_presets.gd` only if a Metal-specific default
(for example shafts or glow off at High on Metal) is chosen, the Mac baseline
document and a reusable Mac probe under `tests/` if the ignored
`artifacts/mac_probe/probe.gd` is promoted. Windows Auto behaviour, presets and
physics stay unchanged. There is no Mac frame-rate requirement in
[Rendering](../../docs/RENDERING.md#performance-policy); the user asked for
insight and worthwhile improvements, so accepted changes need a measured Mac
gain and either no visible change or the user's acceptance of the tradeoff.
Work on a branch for Astra to merge.

## Implementation approach

1. Promote the probe to a repeatable `tests/` script (focused `open` launch,
   240 warm frames, 25 s, JSON output) so Mac runs are reproducible.
2. Attribute with Xcode Metal frame capture or Metal GPU counters on one
   representative frame at bilinear 0.75: terrain fill, forest, shadows, sky,
   fog, glow, tonemap, 2D. Fall back to configuration toggles if capture is
   unavailable.
3. Deliver the cheapest wins first: any Metal-specific shader path issue found
   in capture, a Metal default for the two effects already measured at 2-3 ms
   each (shafts, glow) if the user accepts the look, and the powder patch on
   Metal once the powder task lands.
4. Re-measure with the same probe; update the Mac baseline document.

## Acceptance and verification

- [ ] A repeatable Mac probe exists and reproduces the baseline within run
  variation; the attribution table names the dominant passes with numbers.
- [ ] Measured Mac gain at High on the same route, with matched captures showing
  no visible change, or the user's explicit acceptance of a listed tradeoff.
- [ ] `tests/macos_compatibility_suite.gd`, `tests/pc_graphics_suite.gd`,
  `tests/graphics_suite.gd`, `tests/fidelityfx_settings_suite.gd` and
  `tests/runtime_suite.gd` pass headless; Windows defaults unchanged.
- [ ] Update [Rendering](../../docs/RENDERING.md) and the Mac baseline; commit on
  a branch with a development note and record the Dev ID.

Human acceptance: the user's look at any Metal-specific default change on their
MacBook is a completion gate for that change.

## Open questions

None

## Completion record

Partial delivery, 2026-09-16, branch `fable/mac-metal-frame-floor` (Fable, macOS
M4). Repeatable probe: `tests/mac_frame_probe.gd` through
`scripts/mac_frame_probe.sh LABEL [args]` (focused launch, policy flags, JSON
under `artifacts/mac_probe/`). Attribution at Auto = bilinear 0.75 + MSAA 2x,
20 s runs, run noise about +/-1.5 ms, reference 26.3-27.5 ms:

| Toggle | Frame ms delta |
| --- | ---: |
| Local snow deformation off (two runs) | -4.0 |
| Powder patch draw hidden (diagnostic) | -5.0 |
| Powder atlas compute skipped (diagnostic) | -0.1 |
| Powder shadow casting off (two runs) | -0.2 |
| Powder mesh trimmed to the handover disc (-17% patch triangles) | -0.2 |
| Powder 128 / 64 subdivisions | -1.6 / -2.5 |
| Glow off alone / shafts off alone / both | -2.0 / -1.9 / 0.0 |
| MSAA off, cloud shadows, weather 0, snow detail, normals, shadows 60 m, backdrop | inside noise |

Delivered: `PowderSurface.mesh_subdivisions` returns 128 on Metal (25 cm) and 256
elsewhere; the powder mesh omits quads outside the 13.5 m handover reach plus
the storage offset (exact, fragments were always discarded); `ski_track.gdshader`
discards fully faded fragments beyond 380 m early (exact). Rejected: powder
shadow casting off and glow/shafts defaults (not attributable above noise).
Remaining floor: about 2.5 ms of powder fill plus terrain and forest fill that
no single toggle isolates; Xcode Metal capture is unavailable on this machine
(Command Line Tools only). A grass worker crash (`propagate_notification` from
`stand_density` on a worker thread, signal 11) was observed once; log retained
in `artifacts/mac_floor_20260916/`. Rows in
[MAC_PERFORMANCE_BASELINE.json](../../docs/MAC_PERFORMANCE_BASELINE.json).
Human acceptance of the 25 cm Metal relief is pending (capture
`artifacts/mac_probe/final_metal_powder.png`). Task remains ready for the
remaining fill attribution.

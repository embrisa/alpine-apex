---
id: "AA-20260916-084507-reduce-powder-patch-render-cost"
title: "Reduce remaining powder update or shader cost"
status: ready
priority: P1
depends_on: []
created: "2026-09-16T08:45:07Z"
updated: "2026-09-16T21:59:44Z"
source_thread: null
---

# Reduce remaining powder update or shader cost

## Outcome

Keep a credible local snow surface while reducing measured repeated update or
shader work beyond the mesh reductions already delivered.

## Current state and evidence

Windows now uses 256 subdivisions, Metal 128. The common conservative disc trim
retains 108,168 and 27,192 triangles respectively; the 32 m extent, 1024 atlas
and 256 imprint map remain. The old 512-grid proposal is already complete.
Fable's Metal subdivision observation was about 1.6 ms, but its frame-warmed
configuration probe did not compare identical route intervals. Do not infer a
precise split between compute, micro-triangles and fill from those toggles.
Windows mesh reduction evidence remains in the earlier record below.
Fable's later CPU profile reports about 85–88 us for the powder update; shared
cloud globals and live-stroke packing are now delivered elsewhere.

## Agreed decisions and scope

Own `powder_surface.gd` and its shader/compute interface. Preserve terrain handover,
fresh live strokes, independent ghost histories and upload validation. Small
visual tradeoffs are permitted for real gains, with matched rendered review.
Do not repeat 512-to-256, Metal128 or the conservative disc trim. Do not disable
the patch, reduce the snow extent or silently lose track history.

## Implementation approach

Choose one current bottleneck: change-gate unchanged GPU publications/AABB or
dispatch inputs, or reduce repeated vertex height/gradient work. Include live
strokes, storage/visual centres, support changes and lighting in any dirty-state
test; riding normally changes inputs, so do not promise dispatches disappear.
Only pursue a gradient/shadow rewrite if measured pass cost justifies it. The
Mac shadow-off toggle did not show a reliable gain and must not be sold as free.

## Acceptance and verification

- [ ] Fresh strokes, recentering, first-person relief and terrain handover pass
  focused rendered checks before performance measurement.
- [ ] Affected support/upload/snow-response/track-GPU/runtime checks pass; use
  the smallest relevant fixtures, not an automatic legacy full-mountain matrix.
- [ ] One warmed candidate against a matching saved reference records CPU or GPU
  work saved, frame time/FPS and tails without adding overlapping savings.
- [ ] Retain worthwhile component gains under user policy; update Rendering and
  commit/push with remaining human/platform acceptance explicit.

## Open questions

None

## Completion record

Ready for one remaining update/shader hypothesis. Existing mesh savings are delivered.

## Earlier investigation record

Subdivision-only candidate retained after Windows review: 512 -> 256,
524,288 -> 131,072 triangles, same 32 m extent/maps/shader/shadows/track semantics.
Chase, low-angle, production first-person and moving recenter-frame comparisons
passed; 269 checks passed (support 24, response 33, runtime 192, uploads 13,
cosmetic GPU tracks 7). The full legacy volume/interface-mountain matrix was not
needed for this isolated constant; broader shader/gating work still requires
its affected checks. The full task acceptance list is not complete.

Three clean candidate observations saved 0.346-0.397 ms GPU. Initial 92.38 and
91.31 FPS samples had worse p99 versus saved 91.06; one same-process comparison
resolved the larger p99 difference: 90.74 -> 93.26 FPS, 11.021 -> 10.723 ms,
GPU 9.931 -> 9.585 ms, p95 13.398 -> 13.147, p99 15.025 -> 15.078. Maximum
frame time still grew 18.439 -> 23.316 ms; hitch improvement and sustained
90-120 FPS remain unproven. Reuse 92.28 FPS / 10.837 ms, the average of the two
cache-hit candidate samples.

Atlas dispatch gating, height/gradient packing, shadow and AABB proposals remain
unimplemented. This task remains ready for those separate hypotheses. Source
and mesh budgets are in Rendering; compact evidence is
`artifacts/powder_mesh_20260916/REPORT.md` and `reusable_baseline.json`.

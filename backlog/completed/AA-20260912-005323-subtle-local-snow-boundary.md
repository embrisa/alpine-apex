---
id: "AA-20260912-005323-subtle-local-snow-boundary"
title: "Make the moving local snow-detail boundary less noticeable"
status: done
priority: P2
depends_on: []
created: "2026-09-12T00:53:23Z"
updated: "2026-09-17T02:35:16Z"
source_thread: null
---

# Make the moving local snow-detail boundary less noticeable

## Outcome

Preserve the intentional detailed snow around the player, while making its
boundary and updates subtle during riding. The user sees a square whose edge
visibly updates as they progress and finds it strange and off-putting. Nearby
snow should retain its relief and ski response without a conspicuous advancing
square, popping strip or moving shading seam.

## Agreed decisions and scope

- Keep the detailed local snow, live impressions and retained trails. Smooth
  the handoff into surrounding terrain and its movement; do not solve this
  by disabling deformation, flattening nearby snow or hiding it with blur/fog.
- Presentation only: preserve the Node-independent 120 Hz solver, shared 4 m
  terrain, support/contact rules, replay and race identity. The rendering center
  need not inherit physical-grid snapping if exact contact triangles remain valid.
- Keep the bounded local-patch architecture and existing graphics controls.
  Prefer a local shader/transition correction within current mesh/atlas budgets;
  avoid expanding detail across the mountain or adding a new user setting.
- No general snow-material, camera, animation, weather or engine redesign.
  Follow the [incremental engine strategy](../../docs/ARCHITECTURE.md#engine-strategy).

## Completion and acceptance

The boundary correction is delivered. This Dev85 milestone closes the stale
integration record under the documented FPS waiver and the user's current
economical validation policy. It changes no runtime source or assets and does
not invent a fresh before/after performance pass.

- [x] The 4 m storage center is separated from the continuously rendered rider
  center. Nearby relief stays full through 8 m, reaches zero at 13 m and meets
  complementary opaque ownership at 13.5 m. Support/atlas/center publication is
  coherent, with reset/teleport invalidation and world-fixed tracks preserved.
  Rendering owns the maintained contract and current platform mesh budgets.
- [x] The original v3/v5 native motion reviews accepted ordinary glide/carve,
  threshold/reversal/corner motion, low sun, retained edges, deformation off,
  lower-preset overrides and reset. The final six-case paired chronology had
  5,400 rows/images, with 424 and 468 selected images reviewed independently.
  These are historical observations, not new current-source visual claims.
- [x] The remaining loaded-ridge finding was resolved by the
  [completed ridge correction](AA-20260912-132147-review-loaded-track-ridge-shape.md).
  Duplicate raised ribbon banks fade from 12 to 35 mm inside the local relief;
  shallow tracks and physical snow/contact stay intact. Its matched native turns,
  reversal and jump review passed. Small scallops and historical spacing causality
  remain documented limits, not an unfinished boundary implementation.
- [x] Current Windows checks pass: 22 native boundary/atlas continuity,
  24 support-cache query/byte/invalidation and seven native track-GPU checks.
  They cover current post-mesh-trim source. The initial mixed headless batch
  passed CPU checks but could not run the native-only GPU suite; the correct
  two native guarded invocations passed. No test failure was relabelled a pass.
- [x] **Accepted performance limitation:** historical support caching reduced
  the measured snow/powder p99 from 3.115–4.889 ms to 0.814 ms in its justified
  follow-up (mean/p95 0.243/0.533 ms, 738 queries, 5,904 reused knots, unchanged
  82 support uploads). The cache is 1,296 bytes. That observation is not a
  three-repeat final-source or sustained-FPS claim. The original record explicitly
  permits delivery under the user's FPS waiver; current policy also rejects
  automatic repeated baselines and hash audits. The old compound timing gate is
  waived, not marked as measured. No new FPS claim is made by this closure.
- [x] Physics/input/session formats are unchanged. Current domain documentation
  already reflects the implementation. Backlog/whitespace/scoped version checks
  accompany the completion record and commit/push.

## Current verification and delivery

Commands and current receipts: `artifacts/snow_boundary_close_20260917/REVIEW.md`.
Native checks use compact inline surfaces and the actual DX12 RenderingDevice;
no new mountain bake, broad visual matrix or benchmark ran. Earlier visual/cost
provenance remains in the ridge completion and original source history.

Dev85 is identified by the commit containing
`changes/58faa088934347f288c38b54903fd07a.json` and this record. Human/controller
judgment of subtlety remains unperformed and separate. The active powder-cost
task owns its additional update/shader hypothesis; this completed boundary fix
does not claim that later performance work is done. No new idea was proposed.

---
id: "AA-20260916-084510-trim-environment-and-screen-passes"
title: "Reduce remaining sky, periphery or track pass cost"
status: ready
priority: P2
depends_on: []
created: "2026-09-16T08:45:10Z"
updated: "2026-09-16T21:59:44Z"
source_thread: null
---

# Reduce remaining sky, periphery or track pass cost

## Outcome

Reduce a measured remaining environment or screen-pass cost while preserving
the useful appearance and readability of skiing.

## Current state and evidence

Dev54 already made SSAO/SSIL optional through High, retaining their defaults for
presets 8–10. Its saved dense free-ski sample improved 92.28 to 113.94 FPS;
those numbers predate later code and are not a universal Dev75 baseline.
Dev75 also contains shared cloud globals and the ski-track discard beyond 380 m.
These changes are complete. Fable's Mac glow/shafts toggles were inconsistent
within noise; no Mac default change was retained from them.

## Agreed decisions and scope

Own one remaining sky-update, speed-periphery, track-batch or environment pass
identified by current evidence. Preserve the adopted optional SSAO/SSIL controls
and platform upscalers. The user accepts small visual changes for verified gains;
matched inspection is required, but another permission round for every minor
tradeoff is not. New art/features are outside this performance task.

## Implementation approach

Inspect the current pass cost and choose one candidate: avoid needless sky
updates, reduce a redundant screen copy, or cull invisible retained track work.
Do not repeat SSAO/SSIL-off, alpha-discard delivery or a broad feature-toggle matrix.
Check the candidate's visible effect before one warmed timing sample. Keep
Windows and Metal findings separate.

## Acceptance and verification

- [ ] Matched rendered inspection preserves useful speed cues, weather, tracks
  and transitions, with any small accepted tradeoff described.
- [ ] Relevant graphics/weather/blur/track checks pass for the changed owner.
- [ ] Record actual affected pass/CPU cost and capture-free FPS/frame tails
  against a suitable saved reference; keep only justified changes.
- [ ] Update Rendering and commit/push; sustained target and human feel stay separate.

## Open questions

None

## Completion record

Ready for a remaining pass hypothesis; completed lighting changes are recorded below.

## Earlier investigation record

Partial delivery, 2026-09-16: the user explicitly authorized small visual
tradeoffs for measured FPS gains and autonomous integration. That authorization
covers the SSAO/SSIL default change below; no additional approval is pending.

- Presets 1-7 now default contact shading and screen-space indirect lighting
  off; 8-10 default both on. Individual overrides remain available. Matched
  4K forest and clear/cloudy/rock views passed agent inspection with slightly
  less contact darkening and indirect fill. Geometry, shadows and other budgets
  are unchanged. Both effects already ran half-size at medium quality.
- Their shared normal/roughness prepass prerequisite was the main saving:
  native scene depth **3.098 -> 1.739 ms**; opaque **2.149 -> 2.055 ms**;
  their own passes totalled **0.496 ms**. No isolated LOD1 counter claim.
- Clean free-ski **92.28 -> 113.94 FPS**, **10.837 -> 8.776 ms/frame**, GPU
  **9.588 -> 7.500 ms**. P95/p99 **11.652/14.294 ms**. Saved average reused;
  one warmed candidate, with matched route/camera/population and both caches hit.
- Timed recording **82.72 -> 96.68 FPS** includes the earlier powder reduction
  as well as lighting. All 1,800 ticks and 451 pose samples matched. Startup
  rebuilt scenery before warmup. Current references and limitations are in
  [Performance handoff](../../docs/PERFORMANCE_HANDOFF.md#screen-space-lighting-and-current-references).
- All eight requested suites pass: **842 checks**. Corrected the graphics
  fixture's stale family-name assertion; production selection is unchanged.
  [Rendering](../../docs/RENDERING.md#graphics-and-display) owns the preset contract.
  Development note: `changes/b0e42eba151c4521950a0a3d15b06373.json`.
  Compact local evidence: `artifacts/depth_lighting_20260916/`.

Keep this task ready for the remaining sky, tracks, glow, periphery and fog
hypotheses. Open-route timing, human review and sustained frame-tail acceptance
remain open; do not repeat the already half-resolution proposal or treat the
whole task as complete.

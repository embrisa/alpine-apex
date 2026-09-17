---
id: "IDEA-20260917-082200-separate-scenery-bake-dependencies"
title: "Separate scenery bake inputs from render-only updates"
status: proposed
created: "2026-09-17T08:22:00Z"
source_task: "AA-20260914-094136-cull-scenery-behind-terrain"
source_thread: "01a0a5df-19c3-7783-81dc-eca18c340e4a"
accepted_task: null
---

# Separate scenery bake inputs from render-only updates

## Why consider this

Render-only changes can discard reusable CPU scenery preparation. Avoiding
unnecessary rebuilding would shorten startup and iteration; no steady-state
FPS benefit is claimed.

## Evidence and origin

`SceneryCache.key()` uses `GenerationSources.signature(true)`. Its scenery list
includes entire world/scenery consumers and runtime foliage shaders alongside
actual bake inputs. Sky camera publication and terrain instance LOD bias changes
therefore invalidated preparation although they did not change serialized arrays.
The current occlusion visual setup then spent 9.750 s on maps, 5.503 s on forest
preparation and 3.365 s writing the cache. The next launch reused that cache.
Evidence: `artifacts/guarded/occlusion-current-visual-20260917/`.

## Suggested next step

Audit the persisted sections and their actual producers. Separate bake inputs
from consumers that only configure uploaded resources, with explicit invalidation
tests for both kinds. Measure one warm reuse after a render-only edit and verify
that placement, asset, terrain, bounds and bake-algorithm edits still reject stale
data. Start with one narrowly separable dependency, not a cache-system rewrite.

## Decisions and risks

Some broad consumer files also participate in preparation. Do not remove them
blindly or weaken runtime replay/cache compatibility. Preserve packaged dependency
manifests, asset import identity and cancellation/publication ownership. This is
an invalidation-boundary change, not permission to skip compatibility checks.

## User decision

The current goal authorizes addressing ideas after tasks and blocked work finish.
Retain this proposal for that phase.

---
id: "AA-20260918-091311-expand-meshy-seasonal-forest-presentation"
title: "Expand Meshy trees across seasonal forest presentation"
status: ready
priority: P2
depends_on: []
created: "2026-09-18T09:13:11Z"
updated: "2026-09-18T09:18:30Z"
source_thread: null
---

# Expand Meshy trees across seasonal forest presentation

## Outcome

Make the seasonal forest selector use a coherent Meshy-derived tree collection
across the playable forest and distant scenery, rather than mixing the current
winter Meshy/conifer experiment with legacy generator/TreeDesigner presentation
assets. Keep the current snowy look as one option, add summer and autumn
options, and include lighter-snow winter variation so every winter tree is not
fully buried. The result should improve visual fit, variety and performance
while keeping the physical mountain and racing experience coherent. Preserve
those systems by default, but use judgment if a nearby change is genuinely
needed for a better result.

This is a direction-setting task for GPT-6 Astra, not a prescriptive recipe.
Use the evidence below to understand the goal and the current risks, then use
good engineering and art judgment. Astra may improve nearby implementation or
contracts when that is clearly the better way to achieve the intended result;
document meaningful deviations and validate their consequences.

## Current state and evidence

Read-only investigation on 2026-09-18 at `main` commit `c6aa92c9`; the working
tree was clean and no source, asset, runtime or benchmark files were changed.

- The current production winter selector is presentation-only:
  [`forest_appearance.gd`](../../scripts/presentation/forest_appearance.gd)
  swaps render meshes in resident batches and wilderness scenery while leaving
  physical tree records, transforms, LOD ranges and shadow proxies unchanged.
  [`weather_preferences.gd`](../../scripts/presentation/weather_preferences.gd)
  currently validates only two forest styles, with winter as the personal-play
  default.
- The winter manifest has 54 model entries covering 18 variants at three LODs
  across fir, golden, maple, pine and spruce families. Fir, pine and spruce
  entries use winter-specific materials and atlases, while golden/maple near
  and mid entries still route through `FC_Tree`/`FC_Tree_Mid` and their far
  entries through `FC_Impostor_birch_*`. The manifest contains no dedicated
  winter Meshy birch, dead or broken slots, and the winter texture set has no
  birch/dead/broken atlases. This matches the rendered symptom of white birch
  trunks with gray-brown branches, but the worker must confirm the complete
  material route in a fresh runtime render before changing it.
- The source pack
  [`art_source/trees/meshy_snow_v1`](../../art_source/trees/meshy_snow_v1/README.md)
  contains four selected winter source families and retained provenance. It is
  not a complete replacement for the 30 production assets across spruce, fir,
  pine, birch, dead, broken, golden and maple.
- The matched winter production receipt reports 87.181945986 FPS for the saved
  original and 118.1589395 FPS for the winter candidate on the same bounded
  4K High, Auto 0.75, DX12 route: a 35.5314% FPS improvement with lower p95
  and p99 frame times. This is reference evidence for the winter family, not a
  promise that every new season or species will be faster.
- The earlier generic whole-tree Meshy swap was slower than its original
  control, and the prior full premium family also regressed. Meshy provenance,
  rendered quality and matched frame-time evidence must therefore be evaluated
  together; triangle counts or a single isolated gain are insufficient.
- The completed
  [`colorful-forest-variety`](../completed/AA-20260912-094935-colorful-forest-variety.md)
  task added warm broadleaf preparation but explicitly excluded seasons and is
  not a Meshy-only solution. The blocked distant-stand task and completed
  far-material-submission task are adjacent scenery work, not substitutes for
  this collection.

## Direction and scope

- Retain a user-selectable seasonal presentation with three modes: summer,
  autumn and winter. The existing winter appearance remains available and
  remains the default for personal play unless the user later chooses another
  default.
- Expand the Meshy collection beyond the current winter conifers so the whole
  visible tree language feels intentional: spruce, fir, pine, birch, dead,
  broken, golden and maple families, plus the distant and off-map scenery that
  players actually see.
- Give the collection convincing summer, autumn and winter identities. Keep
  winter variation, including some trees with less snow, so the mountain does
  not look copied and fully buried everywhere.
- Treat the white-trunk/dark-branch birch result as an important lead. Find the
  right material and atlas solution across the visible LODs rather than merely
  masking the close-up symptom.
- Aim for a presentation-only migration and keep racing and physical-world
  behavior stable unless Astra finds a nearby contract that genuinely needs a
  better solution. Do not introduce rocks or terrain as part of tree assets.
- Preserve asset provenance and stay within the authorized generation budget;
  surface a decision if that budget is insufficient.
- This task does not investigate or change the separate reported snow-friction
  audio stutter/frame-drop symptom. That finding needs its own reproduction
  and evidence because ghosts do not contain rendered frame times or audio
  output diagnostics.

## Useful investigation leads

The following are starting points, not mandatory steps. Re-audit the catalogue,
seasonal manifest, far-card routes and source provenance; build whatever small
coverage view helps reveal missing families or LODs; and use isolated source
packs where that makes iteration safer. Render enough near, mid, far,
transition, off-map and birch views to judge the result. Reuse the saved winter
performance comparison where it remains a fair control, and measure accepted
changes under comparable quality and route conditions. Keep visual,
performance, automated and human/controller evidence distinct, and use the
project's normal validation safeguards.

## What success looks like

- [ ] The forest reads as one intentional Meshy-led collection across the
  playable view and scenery, with recognizable summer, autumn and winter
  moods, including lighter-snow winter variety.
- [ ] Birch no longer has an unexplained white-trunk/dark-branch material split,
  and the chosen solution holds together across the distances players see.
- [ ] The result is visually convincing in motion and does not trade away the
  game's dense alpine character for a misleading benchmark gain. Performance
  should be measured fairly enough to tell whether the improvement generalizes
  beyond the original winter reference.
- [ ] The implementation respects the project's physical/racing boundaries,
  or clearly records why a nearby boundary needed to change. Automated,
  rendered, performance and human/controller evidence remain distinguishable.
- [ ] The task's documentation and development record explain what Astra chose,
  what was accepted or rejected, and what still needs the user's visual and
  controller review.

Human acceptance: the user must visually review the seasonal selector and
play a short controller descent in summer, autumn, heavy-snow winter and
lighter-snow winter. This is a completion gate for appearance and transitions;
automated renders and frame-time receipts do not replace it.

## Open questions

None

## Completion record

Pending implementation. The worker should record the outcome, verification
actually performed, remaining human acceptance, updated documentation and
commit/push references. No separate task was authored for the audio stutter
investigation; it remains an independent finding until the user requests that
follow-up.

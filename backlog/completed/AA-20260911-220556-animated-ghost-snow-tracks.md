---
id: "AA-20260911-220556-animated-ghost-snow-tracks"
title: "Add selectable top-time ghosts with animated skiers, distinct colors and snow tracks"
status: done
priority: P2
depends_on: []
created: "2026-09-11T22:05:56Z"
updated: "2026-09-17T02:12:45Z"
source_thread: "01a0927f-723e-7341-bfbc-e2ca1b449d1b"
---

# Selectable animated top-time ghosts and snow tracks

## Outcome

Completed across Dev80–83: automatic fastest 1–10 selection (default ten), manual
subsets, full production skiers/equipment, recorded poses and independent snow
tracks. The remaining Windows integration, maximum-duration storage and readable
first-person overlap have now been checked. Human appearance/controller review
remains separate and is not a task-completion gate.

## Agreed decisions and scope

- Retain the fastest ten completed, eligible, compatible replay-bearing runs
  for each race, independently of the last-20 recent-results list. Include
  qualifying non-PB finishes; retain an older fast run even after it ages out of
  recent history. This is the local player's per-race archive, not an online
  leaderboard, multiplayer or imported-friend-replay feature.
- The user's selected default is **fastest 10**, with **up to 10 selectable**.
  With fewer recordings, show all available; with none, show a useful empty
  state. Select the fastest replay-bearing entries, skipping missing, malformed
  or incompatible payloads without inventing ghosts for old time-only results.
- Add an automatic-fastest mode and a manual subset selector in the existing
  race Records interface. Default to automatic; recompute its fastest available
  set at the next attempt after new eligible finishes. Manual selection may be
  empty and persists per race across retries/app reloads using stable run IDs.
  A selection change applies on the next start/retry, visibly labelled as such;
  never replace active competitors mid-run. The existing global ghost toggle
  remains an immediate hide/show switch and does not erase the saved selection.
  If a manually selected entry is evicted or unavailable, remove it with a clear
  notice rather than silently selecting another run. Returning to automatic
  explicitly restores fastest-time selection.
- Show each entry's rank, time, date and a matching ghost color swatch, with
  accessible controller/keyboard/mouse selection and a selected-count summary.
  Order by exact stored finish time, then a stable date/run-ID tie break. Distinct
  equal-time runs may coexist; the same run must never be duplicated. Color
  complements the textual run identity rather than being its only indicator.
- All selected ghosts begin at race time zero and share the session clock,
  independently stopping at their own recorded finish. PB split/finish deltas
  continue to compare against the PB frozen at attempt start, regardless of
  which ghosts are selected. Retention and selection do not change race rules.
- Replace the primitive PB silhouette with the existing full skier model and
  equipment, animated consistently with the recorded rider's actions. Cover
  ordinary skiing, tuck, turns, jumps, air rotation/grabs and landing; do not
  introduce a separate animation library or new character asset.
- Choose clearly contrasting ghost outfit colors from the player's current
  appearance. A fixed cyan choice is insufficient if the player is similarly
  colored. The implementer may choose the palette/contrast rule; maintain a
  stable run-to-color assignment while the selection/player appearance is
  unchanged and refresh contrast when needed. Distinguish all ten ghosts from
  the player and each other, keeping list swatches synchronized. Check the
  actual textured/lit result, not just RGB values. No color-customization menu
  is required.
- Replace the existing distance disappearance with smooth distance-based opacity:
  closer ghosts become more translucent, reaching a minimum of **15% opacity**
  (15% apparent coverage, meaning 85% transparent), and become more opaque with separation.
  Distance alone must never hide an enabled active ghost, including exact overlap
  and distances beyond the old 750 m cutoff. Remove both the near-distance hide
  and far-distance hide; preserve at least 0.15 apparent opacity for the
  body and all equipment. The implementer may tune the smooth curve/upper opacity
  for readability. Preserve ordinary depth occlusion and camera clipping; this
  does not add visibility through terrain. Explicit ghost-off and existing
  replay/session lifecycle cleanup remain separate from distance-based fading.
- Produce natural snow tracks from the replayed skis. Tracks use the current
  snow appearance rather than requiring colored snow. Snow spray, sound and
  additional environmental effects are outside this request.
- Remain presentation-only: no second skiing simulation, collision, forces,
  physical snow changes, ragdoll bodies, ghost gameplay input handling, sound, shadow or
  GI contribution. Preserve the 120 Hz solver, 4 m terrain authority, race timing,
  PB eligibility and player controls.
- Ghost off hides its model and tracks and stops emission. Re-enabling starts
  fresh track history at the current replay time, with no bridge or catch-up
  stamping. Near-player model fade alone does not suppress valid ski tracks.
  Pause freezes animation and emission. Finish stops new emission; existing
  tracks may remain under the normal bounded history policy until reset.
  Retry, replay replacement and world/race unload clear all ghost track history.
  Each ghost owns its own pose, finish state, materials and track histories;
  finishing or clearing one must not stop or erase another ghost's tracks.
- A replay-format change is permitted if required for faithful presentation.
  Reject incompatible ghosts with the existing unavailable-ghost explanation;
  do not invent legacy poses or introduce migration/shim paths. Keep valid best
  times where the existing record contract permits.

## Acceptance and current evidence

- [x] Fastest-ten retention, stable selection, save/eviction/failure/isolation and
  malformed/compatibility handling: archive 161, retry 58, exact clocks 95 and
  crash replay 36 checks pass in Dev81; the expanded maximum archive run passes
  172 in this milestone. Metadata/selected payload ownership stays bounded.
- [x] Automatic/manual/empty selection and next-attempt roster: Dev80 native
  selector passes 92 checks at small and 4K layouts. Global visibility does not
  erase selection. PB comparison remains independent of selected competitors.
- [x] Independent recorded poses, equipment, per-ski contacts and tracks:
  Dev82 passes 5,122 cached/reference pose comparisons, 224 capture-reuse checks
  and 231 focused native checks including six actual-solver contact cases.
  These include switch landing, one-ski support, rock reentry and jump/landing.
- [x] Current ten-ghost chronology and lifecycle: 526 checks pass; inspected
  production tuck, turning, airborne grab/landing, equipment and track captures.
  Pause/toggle/retry/replacement and independent finishes preserve isolation.
  The initial first-person capture exposed stacked translucent helmet interiors;
  the close-range coverage fix below resolves that visible obstruction.
- [x] Palette and overlap: final material passes 414 overlap checks and 37 palette
  checks. Reviewed chase/first-person overlap and bright/shadowed outfits. Shared
  screen coverage below opacity 0.30 preserves the apparent 0.15 floor and fades
  into ordinary alpha blending; all normal-distance appearances remain smooth.
  Fine close-range screen stippling is the accepted minor visual tradeoff.
- [x] Near/far visibility: current lifecycle captures/checks cover zero, old
  1.2/4 m boundaries and 750 m; the 782 m telephoto view shows a live ghost.
  Terrain depth occlusion, camera clipping and explicit lifecycle hiding remain.
- [x] Maximum-duration storage: ten synthetic 600-second/30 Hz stress payloads
  total 255,615,110 raw bytes under the 32 MiB each/320 MiB aggregate limits.
  Initial selected load 1,027.747 ms; new-process load 1,003.795 ms; cached retry
  8.263 ms with ten hits and no decodes. Raw accounting is not a total-process
  memory cap: selected static-memory delta is about 271.4 MiB. Compressed size
  is 3,119,802 bytes for these unusually simple channels, not a typical forecast.
  The seven immutable-fixture retry checks pass; no ten-minute drive was needed.
- [x] Session/race integration: current native competitive 54 and race 68 checks
  pass. Dev81 physics 56/runtime 192 are reused with unchanged simulation/session
  inputs. Corrected obsolete UI test expectations and allowed Windows clipboard
  listeners to finish before verified fixture restoration; no production UI edit.
- [x] Capture-free performance: Dev82 ten-ghost lab improves 12.7013 → 11.1797 ms
  (78.73 → 89.45 FPS). Final overlap material measures 10.9426 ms / 91.39 FPS,
  versus that saved matching 11.1797 ms / 89.45 FPS. GPU 6.7406 → 6.3487 ms,
  frame p95 13.990 → 13.726, p99 15.640 → 15.726 ms. One 15-second candidate,
  focused 4K High / 2880×1620 Auto FSR 4.1.1 / FG off, ten ghosts and 3,200
  stamps. This is a small single-run observation, not an established 2% gain.
  The current economical policy supersedes repeating the old 0/1/10 matrix;
  no whole-mountain or dense-route FPS improvement is claimed.
- [x] Domain guides, selective producers and validation skill updated; scoped
  metadata, backlog, whitespace and development-note checks precede delivery.

## Completion record

Delivery: Dev83, identified by `changes/c3ab51edc9f54307ae4beec806207d37.json`
and the commit containing this record. Source history gives the exact delivery
commit without embedding a self-referential commit ID.

Related completed milestones:

- [Selector and render fixtures](AA-20260912-132147-finish-ghost-selector-and-render-fixtures.md), Dev80 `d94c0545`.
- [Cold loading](AA-20260912-132147-reduce-cold-ghost-archive-load.md), Dev81 `942d3b1e`.
- [Playback CPU cost](AA-20260912-132147-reduce-ten-ghost-presentation-cost.md), Dev82 `1a4c1b23`.

Compact current evidence and exact invocations:
`artifacts/ghost_integration_20260917/REVIEW.md`. Reused child evidence is linked
from the three records above. Failed culling/global-hash material variants were
rejected visually before timing; only near-range shared screen coverage ships.

Remaining limits: human/controller approval is unperformed; existing pole
posture limitations belong to the pole task. The maximum storage fixture is
synthetic, OS file caches were uncontrolled, and Windows timing is not a Mac
claim. No ghost selection, physics, race identity or replay format changed here.

Ideas remain in `backlog/ideas`: selected-count loading and unchanged material
parameter suppression. They are deferred until active and blocked tasks finish.

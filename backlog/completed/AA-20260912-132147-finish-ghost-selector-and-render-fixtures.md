---
id: "AA-20260912-132147-finish-ghost-selector-and-render-fixtures"
title: "Finish ghost selector input and rendered contact/colour checks"
status: done
priority: P1
depends_on: []
created: "2026-09-12T13:21:47Z"
updated: "2026-09-17T01:06:06Z"
source_thread: null
---

# Finish ghost selector input and rendered contact/colour checks

## Historical disposition — 16 September 2026

Keep this task independently ready. The selector's 4K mouse/empty-set issues,
automatic fastest 1–10 setting and fixture lighting can be addressed without
waiting for the blocked pole animation task. Current `ghost_selector.gd` still
selects every available run in Automatic mode; the count control is not delivered.
Use current replay7/archive4 data and preserve known pole defects as baseline
findings. Recheck old fixture failures before changing production input.

## Outcome

Make Records selection reliable at 4K, let the player choose Automatic fastest 1–10, and complete trustworthy rendered evidence for ghost contact and outfit contrast.

## Current state and evidence

Native-v2 has 600 checks with only two 4K selector failures: mouse row toggling and keyboard restoration of an empty manual set. The15-second chronology and other lifecycle/opacity checks pass. Focused-native-v1 has 231 checks with four failed shadow probes; all six real motion/contact cases pass, including180-degree switch landing, one-ski drop, rock and jump track breaks. Inspected stage images lack useful ground/shadow context.

Originating tasks: [AA-20260911-220556-animated-ghost-snow-tracks](AA-20260911-220556-animated-ghost-snow-tracks.md). Evidence: `artifacts/ghost/native-v2/`, `artifacts/ghost/focused-native-v1/`, and `artifacts/orchestration_20260912/ghost/native_v3_fix/`. Measurements are from2026-09-12; private proposals and frozen captures are local, ignored evidence, not shipped dependencies. Recheck live source before applying a candidate.

## Agreed decisions and scope

The user explicitly requested this remaining work be saved for later, after stopping excessive agent/test usage. Authoring does not dispatch. Start with one worker and the smallest sufficient check; batch compatible checks, use the existing validation guard, and stop expanding coverage once the named criteria pass. Preserve120 Hz simulation,4 m terrain authority, personal records/preferences and current replay identities.

Automatic selection must expose a player-chosen count from 1 through 10, defaulting to the current ten. Persist that setting with the existing ghost-selection preference; it applies on the next start or retry, freezes the resulting roster for the active attempt, and selects only the available compatible fastest runs when fewer than the requested count exist. Manual subsets, the explicit empty manual set, PB split comparisons, replay identity and the ten-run archive limit remain unchanged.

Primary owners: `tests/ghost_playtest.gd`, `tests/ghost_focused_native.gd`, `scripts/ui/ghost_selector.gd`, `scripts/core/run_session.gd`, `scripts/racing/competitive_record.gd`, `competitive_panel.gd` and Main input routing.

## Implementation approach

Diagnose logical canvas versus window/image coordinates and analytic-stage winding, shader ownership and shadow reception. These are hypotheses, not confirmed production bugs. The interrupted `ghost/native_v3_fix` directory contains investigation, not a completed patch. Fix the fixture first where warranted; change player UI only with a reproduced production failure. Add an automatic-count selector that works with mouse, keyboard and controller, and extend the existing selection normalization, persistence and roster selection to clamp and honor 1–10. This is an intentional current selection-data schema change: reject/regenerate incompatible stored selection metadata rather than adding a migration or legacy path solely for it. Add or use a selector-only rerun and recapture only lighting/contact images invalidated by the stage repair. Preserve accepted six-case physics/codec results and the completed15-second chronology. Keep textured/lit production materials, a real shadow caster and the existing10% probe-darkening gate; never replace shadow proof with a tint.

## Acceptance and verification

- [x] Mouse, keyboard and controller selection/empty set/Back work at 1024x720 and3840x2160 with correctly transformed input coordinates.
- [x] Automatic fastest 1–10 can be set and persists for the next start/retry; every setting freezes the correct bounded roster for the attempt, while manual and empty selection behavior is unchanged.
- [x] Actual receiving snow/rock and shadow appear; inspect all ten colours against default/dark/light/cyan player outfits and required contact/re-entry images.
- [x] Preserve15% minimum opacity, depth occlusion, independent histories, exact clocks, accepted pose attachments and isolation; record fixture-versus-production fixes and close the corresponding original acceptance items.
- [x] Record exact changed-source verification and commit/push the owned work with updated authoritative documentation.

Human acceptance: actual controller feel, listening and subjective visual approval remain separate follow-ups, not an unattended worker completion gate. Do not revive the cancelled broad player-acceptance task or claim the user tested these features.

## Open questions

None

## Completion record

Completed on 17 September 2026. Delivery is the commit containing development
note `64b82ca294f24a8e8b49d0a76330921d` (resolve with versioning history).

- Production: Automatic fastest 1–10, default ten, persists per race and applies
  at the next start/retry. Active rosters stay frozen; explicit empty manual
  selections remain empty. Selection metadata v1 deliberately resets obsolete
  preferences with a notice, preserving valid PBs, history and replay references.
- Fixture fixes: native popup input now uses its actual embedded-window and
  root canvas transforms. The analytic receiving quads face the camera; the sun
  participates in the stage camera's layer. Shadow probes sample image pixels,
  not logical UI coordinates. Production mouse routing and lighting are unchanged.
- Headless: physics 56, runtime 192, archive 161, retry/cache 58 and crash/replay
  36 checks pass. Archive tests cover every count, malformed preferences,
  obsolete preference reset without record loss and missing-payload fallback.
- Native selector-only: 92 checks pass at 1024×720 and 3840×2160, including
  mouse/keyboard/controller events, empty selection, Back and count persistence.
- All six real contact cases pass on the repaired lit stage. The contact batch
  had four obsolete shadow-probe failures; the final separate palette run
  supersedes those with 37 passing checks and 56.6% real shadow darkening.
  Reviewed all ten ghost colours against default/dark/light/cyan outfits in
  sunlight and shadow, plus turn, switch landing, one-ski, rock and jump reentry.
  Nondefault outfit fixtures use diagnostic solid colours with the production
  lit shader and normal map; they do not change the player's wardrobe.
- Preserved the previously accepted 15-second chronology. This UI-only rerun
  does not claim a new chronology run or repair the known pole animation gaps.
  Minimum opacity, exact clocks, independent histories and isolation remain
  covered by the existing contracts and current focused checks.

Commands and compact review: `artifacts/ghost_selector_20260917/REVIEW.md`;
results in `regression/`, `archive-final/`, `native-ui-embedded/`, `focused-lit/`
and `palette-outfits/` beneath that directory. The runtime sources passed before
final administrative edits; later fixture-only edits repeated their affected
native checks. No FPS gain or human/controller/subjective acceptance is claimed.
Cold loading and ten-ghost playback remain separate active tasks.


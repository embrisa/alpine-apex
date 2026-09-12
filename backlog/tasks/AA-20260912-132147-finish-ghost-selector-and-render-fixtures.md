---
id: "AA-20260912-132147-finish-ghost-selector-and-render-fixtures"
title: "Finish ghost selector input and rendered contact/colour checks"
status: ready
priority: P1
depends_on: ["AA-20260912-132147-finish-pole-transition-validation"]
created: "2026-09-12T13:21:47Z"
updated: "2026-09-12T13:21:47Z"
source_thread: null
---

# Finish ghost selector input and rendered contact/colour checks

## Outcome

Make Records selection reliable at 4K and complete trustworthy rendered evidence for ghost contact and outfit contrast.

## Current state and evidence

Native-v2 has 600 checks with only two 4K selector failures: mouse row toggling and keyboard restoration of an empty manual set. The15-second chronology and other lifecycle/opacity checks pass. Focused-native-v1 has 231 checks with four failed shadow probes; all six real motion/contact cases pass, including180-degree switch landing, one-ski drop, rock and jump track breaks. Inspected stage images lack useful ground/shadow context.

Originating tasks: [AA-20260911-220556-animated-ghost-snow-tracks](AA-20260911-220556-animated-ghost-snow-tracks.md). Evidence: `artifacts/ghost/native-v2/`, `artifacts/ghost/focused-native-v1/`, and `artifacts/orchestration_20260912/ghost/native_v3_fix/`. Measurements are from2026-09-12; private proposals and frozen captures are local, ignored evidence, not shipped dependencies. Recheck live source before applying a candidate.

## Agreed decisions and scope

The user explicitly requested this remaining work be saved for later, after stopping excessive agent/test usage. Authoring does not dispatch. Start with one worker and the smallest sufficient check; batch compatible checks, use the existing validation guard, and stop expanding coverage once the named criteria pass. Preserve120 Hz simulation,4 m terrain authority, personal records/preferences and current replay identities.

Primary owners: `tests/ghost_playtest.gd`, `tests/ghost_focused_native.gd`, `scripts/ui/ghost_selector.gd`, `competitive_panel.gd` and Main input routing.

## Implementation approach

Diagnose logical canvas versus window/image coordinates and analytic-stage winding, shader ownership and shadow reception. These are hypotheses, not confirmed production bugs. The interrupted `ghost/native_v3_fix` directory contains investigation, not a completed patch. Fix the fixture first where warranted; change player UI only with a reproduced production failure. Add or use a selector-only rerun and recapture only lighting/contact images invalidated by the stage repair. Preserve accepted six-case physics/codec results and the completed15-second chronology. Keep textured/lit production materials, a real shadow caster and the existing10% probe-darkening gate; never replace shadow proof with a tint.

## Acceptance and verification

- [ ] Mouse, keyboard and controller selection/empty set/Back work at 1024x720 and3840x2160 with correctly transformed input coordinates.
- [ ] Actual receiving snow/rock and shadow appear; inspect all ten colours against default/dark/light/cyan player outfits and required contact/re-entry images.
- [ ] Preserve15% minimum opacity, depth occlusion, independent histories, exact clocks, accepted pose attachments and isolation; record fixture-versus-production fixes and close the corresponding original acceptance items.
- [ ] Record exact changed-source verification and commit/push the owned work with updated authoritative documentation.

Human acceptance: actual controller feel, listening and subjective visual approval remain separate follow-ups, not an unattended worker completion gate. Do not revive the cancelled broad player-acceptance task or claim the user tested these features.

## Open questions

None

## Completion record

Pending implementation. Record actual results, remaining limits, source/provenance and commit/push references. No worker is dispatched by this authoring change.

---
id: "AA-20260916-084504-reduce-hud-frame-cost"
title: "Skip hidden HUD work and per-frame interface string and theme churn"
status: ready
priority: P1
depends_on: []
created: "2026-09-16T08:45:04Z"
updated: "2026-09-16T08:45:04Z"
source_thread: null
---

# Skip hidden HUD work and per-frame interface string and theme churn

## Outcome

Make the interface effectively free while riding and near zero while menus are
open, without changing what the player sees. The HUD, footer prompts, mode
label, crash readout and menu navigation currently do formatting, layout and
theme work every frame regardless of visibility.

## Current state and evidence

- The `hud` CPU scope is 153-193 µs mean and 208-264 µs p95 per rendered frame
  in the committed receipts, and 300-310 µs mean (about 550 µs p95) in the
  `ui_settings_*` cases of
  [INTERFACE_PERFORMANCE_RESULTS.json](../../docs/INTERFACE_PERFORMANCE_RESULTS.json),
  where every instrument is hidden. The isolated `paired_hud_update_cpu` row
  shows `update_hud` alone rose from 44 to 92 µs mean across the interface
  overhaul. The scope excludes `menu_navigation` and footer/mode label work
  done in `main.gd` outside it.
- Source inspected at Dev 43 / `a9c2acb` (2026-09-16):
  - [`hud.gd:863-954`](../../scripts/ui/hud.gd) `update_hud` only early-outs
    when the HUD editor is visible. It runs `widget_layout.apply(root.size)`
    every frame (line 868), formats `pb_label`, `mode_label`, `menu_specs`,
    `altitude_label` and the ghost count every frame, calls `sim.speed_kmh()`
    up to ten times, allocates the band name Array literal, and at line 936
    calls `impact_label.add_theme_color_override("font_color", tint)` every
    frame. That override has no equality check and triggers a theme-changed
    notification, text re-shape and minimum-size invalidation up the tree.
  - `hud.gd:955-962` builds an 18-line telemetry String at 10 Hz and assigns
    it (twice, via `+=`) to `debug_text` even when the debug panel is hidden.
  - [`main.gd:565`](../../scripts/main.gd) calls `hud.update_crash_recovery`
    from `_physics_process` at 120 Hz while recovering
    ([`hud.gd:707-724`](../../scripts/ui/hud.gd) formats a clock string, sets
    button text/tooltip and `custom_minimum_size` each tick).
  - `main.gd:672` and `main.gd:772` both rebuild `footer_controls.text` from
    `prompts()` in the same frame; `main.gd:763-769` and `hud.gd:943-947`
    format `mode_label.text` up to four times per frame; `main.gd:760`
    concatenates the weather label per frame; `main.gd:758, 771` and
    `set_background_fade` evaluate `has_menu_background()` three times per
    frame, each walking `is_visible_in_tree` on about ten controls.
  - [`menu_navigation.gd:229-238`](../../scripts/ui/menu_navigation.gd)
    `_process` calls `_sync_scope` every frame (popup scan, dynamic `get`
    lookups, six panel visibility checks, window focus) even during play, and
    line 39 connects `SceneTree.node_added` to a GDScript callback that fires
    for every runtime node (ragdoll bodies, SFX players, sparks, beams, props).
  - [`hud_layout.gd:34-46`](../../scripts/ui/hud_layout.gd) `apply` touches 12
    widgets per frame though layout changes only on resize/preferences/menu
    toggles, which already call `layout_widgets()`.
  - [`mountain_flavor.gd:35-41`](../../scripts/world/mountain_flavor.gd)
    `discover_near` scans every placement each frame in free skiing.
- Label `set_text` early-outs on equal Strings in Godot 4, so the waste is the
  GDScript formatting, the theme override and layout invalidation, not redraw.

## Agreed decisions and scope

Own `scripts/ui/hud.gd`, `hud_layout.gd`, `menu_navigation.gd`,
`compact_menu.gd` where `update_crash_recovery` reaches it, the interface
lines of `scripts/main.gd` `_process`/`_physics_process`, and
`scripts/world/mountain_flavor.gd` `discover_near`. Preserve every visible
readout, cadence (10 Hz telemetry, crash clock), controller prompt behaviour,
focus routing and the retained-layer HUD contract in
[Presentation](../../docs/PRESENTATION.md). Menu hitches (buttons, sliders,
records panel, loading, navigation overlay) belong to
[the interface hitch task](AA-20260916-084514-reduce-menu-and-loading-interface-hitches.md).

## Implementation approach

1. In `update_hud`, compute one `instruments_visible` flag from
   `widget_layout.menu_visible`/`global_visible`; after toast and notice
   timers, return early when hidden. Keep `menu_specs`, `pb_label` and mode
   text updates on their events (`show_menu`, `set_mountain`, `show_result`,
   run start) instead of per frame.
2. Cache `speed_kmh` in a local, hoist the band names to a `const`, cache the
   impact tint and only override on change (or switch to `modulate`), gate the
   telemetry block on `debug_panel.is_visible_in_tree()`, and build it once.
3. Move `update_crash_recovery` label work to render rate and skip the clock
   text when `crash_clock` is hidden; compare elapsed before formatting.
4. Build footer and mode text once per frame in `main.gd`, or on
   `device_changed`, workshop mode and summit transitions; store the weather
   label when weather state changes; store `background_visible` in
   `_sync_menu_backdrop` and read it.
5. In `menu_navigation`, enable `_process` only while a direction is held or a
   scope exists, recompute scope on `visibility_changed` of tracked panels,
   and replace `node_added` with explicit registration of the few dialogs the
   UI creates.
6. Remove the per-frame `widget_layout.apply` or gate it on a dirty flag set by
   resize, `timed` changes and transient label visibility.
7. Make `discover_near` cheap in free skiing (spatial bucket or distance-sorted
   candidate list refreshed every few metres).

## Acceptance and verification

- [ ] `hud` scope and the added `interface_main` scope (wrap the `main.gd`
  interface lines temporarily) fall to well under 50 µs riding and near zero
  in menus, measured with `-ProfileFrameCosts` on the ordinary trace.
- [ ] `tests/interface_performance_suite.gd`, `tests/interface_suite.gd`,
  `tests/interface_layout_suite.gd`, `tests/hud_dial_suite.gd`,
  `tests/menu_navigation_suite.gd`, `tests/controller_prompts_suite.gd`,
  `tests/crash_recovery_suite.gd`, `tests/summit_return_suite.gd`,
  `tests/flavor_integration_suite.gd` and `tests/runtime_suite.gd` pass.
- [ ] Rendered inspection of riding HUD, pause, settings, crash menu with the
  crash clock, summit heading label and controller/keyboard prompt swaps shows
  identical content and cadence.
- [ ] One warmed candidate against the open-route baseline where the frame is
  CPU-bound; report frame means and p95/p99.
- [ ] Update [Presentation](../../docs/PRESENTATION.md) HUD cost wording,
  commit/push owned paths with a development note and Dev ID.

Human acceptance: none; readouts must be unchanged.

## Open questions

None

## Completion record

Pending implementation. Record scope timings, tests, rendered evidence, guide
updates and commit/push references.

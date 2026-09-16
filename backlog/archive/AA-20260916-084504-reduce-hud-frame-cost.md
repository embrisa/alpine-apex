---
id: "AA-20260916-084504-reduce-hud-frame-cost"
title: "Skip hidden HUD work and per-frame interface string and theme churn"
status: done
priority: P1
depends_on: []
created: "2026-09-16T08:45:04Z"
updated: "2026-09-16T18:45:07Z"
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

### Delivery, 2026-09-16: implemented on `main` (Fable, macOS checkout)

Implemented manually after Astra stopped; no scheduled claim. Owned paths:
`scripts/ui/hud.gd`, `hud_layout.gd`, `menu_navigation.gd`,
`controller_prompts.gd`, the interface lines of `scripts/main.gd`,
`scripts/world/mountain_flavor.gd`, plus `tests/mac_frame_probe.gd`
(`--probe-menu`) and the Presentation/Performance handoff guides.

What changed (readouts, cadence and focus routing preserved):

- `update_hud` returns after its notice/toast timers, layout check and run
  context when every instrument is hidden (menu open or H). Widget layout
  re-applies only when size, safe area, race mode, menu/preview state or a
  transient notice changes. Personal best, altitude/weather, split, run
  context and course specs format only when their inputs change; the impact
  tint theme override applies on change; `speed_kmh` is read once; band names
  are a `const`; the finish/state text is assigned once; the telemetry string
  is built only while the debug panel is visible (FPS label only while
  visible), still at 10 Hz.
- `update_crash_recovery` formats the clock only when the millisecond value or
  paused state changes and the Stand Up button only when its inputs change.
- `has_menu_background()` returns a cached flag refreshed by the registered
  views' `visibility_changed` (which already drove `_sync_menu_backdrop`).
  `main.gd` builds the mode label and controls footer once per frame; summit
  heading text caches by bearing; `Prompts.menu` memoises per family.
- `menu_navigation._process` sleeps while no scope exists and nothing is held;
  it wakes on any input event (`_device_used`), controller connection changes,
  window focus and visibility changes of every scope owner (menus, panels,
  workshop/library/navigation panels, loading overlay, HUD editor, camera
  preview toolbar, tracked popup windows). `node_added` stays connected:
  lazily created popups (colour pickers, dialogs) need it and its per-node cost
  is sub-microsecond, so the proposed explicit registration was declined.
- `discover_near` rescans placements only after the rider has travelled the
  exact triangle-inequality slack measured at the last scan.

Measured on the Apple M4 MacBook (Metal, bilinear 0.75, Standard mountain
free ski, `scripts/mac_frame_probe.sh`, 20 s after 240 warm-up frames; frame
time noise about +/-1.5 ms so only the `hud` scope is claimed):

| State | Before mean / p95 / p99 (us) | After mean / p95 / p99 (us) |
| --- | --- | --- |
| Riding | 147 / 212 / 240 | 44 / 69 / 77 |
| Pause menu open | 146 / 215 / 234 | 36 / 57 / 66 |

Frame means: baseline riding 27.5 and 30.2 ms, candidate riding 24.7 ms; menu 25.2 -> 20.8 ms (inside run noise). The riding scope target of "well under 50 us" is
met (44 us mean); menus are not literally zero because the layout/identity checks
and notice timers still run.

Automated (macOS, Godot 4.7.2): interface_suite 83/83, menu_navigation_suite
24/24, controller_prompts_suite 45/45, interface_layout_suite 95/95,
crash_recovery_suite 82/82 (after creating its missing artifacts folder; it
hangs otherwise on any checkout), flavor_integration_suite 37/37,
runtime_suite 192/192, native hud_dial_suite 33 paint cases byte-identical,
summit_return_suite 24/27 with the same three failures on unmodified `main`
(tuck-held drop-in and two race-boundary checks; pre-existing). Also headless: bright_ui_suite 74/74, interface_overhaul_suite 40/40, interface_feedback_suite 111/111, interface_art_playtest 156/160 and retained_interface_suite 247/248 with failures identical on unmodified main (title header logo, loading timer layout at three sizes, unavailable ghost explanation; pre-existing).
`tests/interface_performance_suite.gd` requires the Windows D3D12 engine and
was not run; rendered inspection of the readouts is the suite evidence above,
not a human review.

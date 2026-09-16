---
id: "AA-20260916-084514-reduce-menu-and-loading-interface-hitches"
title: "Remove menu, loading and navigation interface hitches"
status: ready
priority: P3
depends_on: []
created: "2026-09-16T08:45:14Z"
updated: "2026-09-16T08:45:14Z"
source_thread: null
---

# Remove menu, loading and navigation interface hitches

## Outcome

Menus, settings, the records panel, the loading overlay and the navigation
map stop causing per-frame redraws, stylebox churn, synchronous disk writes and
multi-millisecond stalls, with identical appearance and behaviour. This is a
polish task; riding FPS is owned by
[the HUD task](AA-20260916-084504-reduce-hud-frame-cost.md).

## Current state and evidence

Source inspected at Dev 43 / `a9c2acb` (2026-09-16):

- [`action_button.gd:23-26, 44-68, 67-104`](../../scripts/ui/action_button.gd):
  every visible primary button enables `_process` and calls `queue_redraw()`
  each frame for its pulse, redrawing a polyline outline and a theme box
  looked up by an Array key per draw; `refresh_prompt` duplicates six
  styleboxes and applies six overrides whenever the badge width changes, and
  focus changes the width (53 px badge versus a 52 px reserve), so each focus
  move re-keys two buttons; `visibility_changed` fans out to all buttons under
  Settings on open/close.
- [`hud.gd:590`](../../scripts/ui/hud.gd) and [`interface_feedback.gd:12-19, 82-87`](../../scripts/ui/interface_feedback.gd):
  the volume slider saves to disk and refreshes all buttons and layout on
  every step; [`settings_pages.gd:301`](../../scripts/ui/settings_pages.gd)
  with [`screen_shell.gd:32-35`](../../scripts/ui/screen_shell.gd) writes
  preferences and changes `content_scale_size` (full relayout) per slider step.
- [`hud.gd:341-345`](../../scripts/ui/hud.gd): tab page margins set theme
  constant overrides inside `resized` without an equality check, risking
  layout ping-pong around the scrollbar threshold.
- [`competitive_panel.gd:82-95`](../../scripts/ui/competitive_panel.gd)
  appends to `Label.text` in loops (up to about 23 re-shapes of a growing
  label); smaller instances in `mountain_library.gd:232-238` and `hud.gd:663-665`.
- [`loading_overlay.gd:254-283`](../../scripts/ui/loading_overlay.gd) sets two
  constant shader parameters, copies the job snapshot, reconciles estimates
  and formats the elapsed label every frame while loading; the load is
  main-thread-cooperative so this lengthens loads.
- [`session_navigation_panel.gd:285-308`](../../scripts/ui/session_navigation_panel.gd)
  and [`session_navigation_overlay.gd:9-46`](../../scripts/ui/session_navigation_overlay.gd)
  rebuild markers and `queue_redraw()` every frame while the map is open.
- [`hud_editor.gd:135-137`](../../scripts/ui/hud_editor.gd) performs a
  full-resolution GPU readback when opening the HUD editor (intended freeze
  image; about 33 MB at 4K).
- [`compact_menu.gd:169-175`](../../scripts/ui/compact_menu.gd) allocates a new
  stylebox and relayouts on every `refresh()`.

## Agreed decisions and scope

Own the listed `scripts/ui/` files. Preserve visuals, focus behaviour,
controller prompts, preference persistence semantics (values still saved,
just not per step) and the loading overlay's content and cadence as seen by
the player. Do not change the interface performance contract in
[INTERFACE_PERFORMANCE_RESULTS.json](../../docs/INTERFACE_PERFORMANCE_RESULTS.json)
except to improve it.

## Implementation approach

1. Pulse buttons via `modulate`/`self_modulate` on an overlay or a shader at
   most 30 Hz; cache derived styleboxes per key in a static Dictionary; raise
   the badge reserve so focus does not re-key; skip refresh when not visible in
   tree.
2. Persist slider preferences on `drag_ended`; refresh prompts only on
   `reduced_motion` changes; debounce `content_scale_size`.
3. Store the last margin inset and early-out in the tab page `resized` handler.
4. Build panel text in a local String and assign once.
5. Set constant loading shader parameters once; update the elapsed label and
   job snapshot at up to 10 Hz; skip snow redraw when the phase is unchanged.
6. Redraw the navigation overlay only when markers, target or selection
   changed; cache the panel rect per frame.
7. Optionally downscale the HUD editor freeze image before upload.

## Acceptance and verification

- [ ] `tests/interface_performance_suite.gd`, `tests/interface_settings_suite.gd`,
  `tests/interface_feedback_suite.gd`, `tests/interface_layout_suite.gd`,
  `tests/retained_interface_suite.gd`, `tests/menu_navigation_suite.gd`,
  `tests/session_navigation_suite.gd`, `tests/competitive_suite.gd`,
  `tests/startup_suite.gd` and `tests/runtime_suite.gd` pass.
- [ ] Rendered inspection of settings open/close, slider drags, records panel,
  loading overlay and the navigation map shows identical appearance; measured
  open/close and per-step costs fall (report before/after µs).
- [ ] Commit/push with a development note and Dev ID; update
  [Presentation](../../docs/PRESENTATION.md) only where a contract changes.

Human acceptance: none; appearance is unchanged.

## Open questions

None

## Completion record

Pending implementation. Record measured costs, tests, rendered evidence and
commit/push references.

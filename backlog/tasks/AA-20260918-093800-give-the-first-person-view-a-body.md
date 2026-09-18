---
id: "AA-20260918-093800-give-the-first-person-view-a-body"
title: "Give the first-person rider hands, arms and poles"
status: ready
priority: P1
depends_on: []
created: "2026-09-18T09:38:00Z"
updated: "2026-09-18T09:38:00Z"
source_thread: null
---

# Give the first-person rider hands, arms and poles

## Outcome

Riding in first person should feel like being the skier. Today the entire rider
is hidden the moment the close view is selected, so at 140 km/h in a deep tuck
the player sees two ski tips at the bottom of the screen and nothing else. No
hands, no forearms, no poles tucked under the arms. The view loses its single
strongest cue that a person is doing this, and there is nothing in frame that
reacts to speed, terrain or the rider's own effort.

## Current state and evidence

Rendered macOS probe captures on 2026-09-18 at `main` `d753926`, using
`scripts/mac_frame_probe.sh --probe-capture --probe-hold=... --probe-immortal
--probe-at-tick=3000 --first-person`. Retained as
`artifacts/mac_probe/look_fp_day.png` (90 km/h),
`look_fp_fast.png` (140 km/h) and `look_fp_snow.png` (snowfall).

- [`main.gd`](../../scripts/main.gd) line 744 sets
  `skier.body_pivot.visible = menu_view or skier.ragdoll.running or
  (summit_ready and presentation_camera!=camera_preview) or not
  first_person_presented`. Riding in first person makes every one of those false,
  so `body_pivot` is hidden outright.
- [`skier_visual.gd`](../../scripts/presentation/skier_visual.gd) shows what that
  removes: `body_pivot` owns `character` (line 48) and both poles (line 67). The
  skis are parented elsewhere and survive, which is why the captures show ski
  tips and nothing else.
- The hiding itself is necessary. The camera sits at eye height, so a full body
  would put the head and torso through the near plane. The gap is that nothing
  replaces it.
- A related but separately owned observation from the same captures: at 140 km/h
  the peripheral speed streaks do appear, so
  [`speed_periphery.gdshader`](../../assets/speed_periphery.gdshader) is working.
  `chase_camera.gd` line 155 derives `intensity = smoothstep(60.0,200.0,kmh)`, so
  the effect is roughly 12 percent at 90 km/h and only becomes obvious well
  above 120. Scene motion blur also defaults off at every preset. Whether the
  view needs more ground-rush at ordinary speeds is a separate question from this
  task; do not fold a speed-effect redesign into it.
- Camera profiles already distinguish the views:
  [`camera_settings.gd`](../../scripts/presentation/camera_settings.gd) has
  `VIEWS = ["chase","first_person"]`, per-view `eye_height` and `tuck_lowering`
  fields, and separate saved presets, so per-view presentation is an established
  pattern here.
- The animation system already produces the arm and pole motion this needs. Pole
  planting, tuck posture and hand placement are owned by the skier animation
  work; this task consumes that existing state rather than authoring new motion.

## Agreed decisions and scope

- Show what a rider would actually see of themselves: forearms, gloves and the
  poles, following the existing animated pose. The head, torso and anything that
  would clip the near plane stay hidden.
- Consume the existing animation. Do not author a separate first-person pose, a
  second skeleton or a decorative idle; the hands must agree with what the chase
  view shows the same rider doing at the same instant.
- Must not obstruct the line ahead. Hands and poles sit low and at the edges;
  readability of terrain at racing speed outranks how much of the rider is
  visible.
- Must survive every lifecycle transition already handled at line 744: crash and
  ragdoll, summit staging, camera preview, menu views and the chase handover.
  Switching views mid-run must not leave a floating arm or a hidden rider.
- Presentation only: no physics, no animation model change, no new equipment art
  if the existing production meshes can be reused.
- Out of scope: the speed-effect question above, first-person camera tuning,
  the HUD, and any change to the chase view.

## Implementation approach

1. Capture the reference first: first person at 90 and 140 km/h, in a turn, over
   a jump, on landing and during a crash handover, so the cases that must keep
   working are documented before the visibility rule changes.
2. Replace the wholesale `body_pivot` hide with a narrower rule that keeps the
   arms and poles while removing what clips. Whether that is a separate pivot, a
   per-surface visibility choice or a near-plane-aware cull is the implementer's
   call; keep line 744 as the single owner of the decision.
3. Verify against the chase view at matched instants. The same pose seen from
   outside and from inside must agree; a first-person-only fudge that looks wrong
   from the chase camera is not acceptable.
4. Check the transitions explicitly. Crash into ragdoll, ragdoll into recovery,
   summit staging and the camera preview all pass through this line.

## Acceptance and verification

- [ ] First-person captures at 90 and 140 km/h show forearms, gloves and poles in
  a believable tuck, with no clipping of head or torso through the near plane.
- [ ] The line ahead remains readable at racing speed; capture a turn and a
  landing, not only a straight tuck.
- [ ] Pose agrees with the chase view at matched solver ticks, including pole
  planting and tuck transitions.
- [ ] Crash, ragdoll, recovery, summit staging, camera preview, menu views and
  live view switching all behave correctly with no floating or missing geometry.
- [ ] Run the animation and runtime suites that own skier visibility, and the
  camera suites if the view rule changes.
- [ ] Bounded warmed before/after frame comparison in first person; extra visible
  geometry is expected to be small but is confirmed, with the noise floor stated.
- [ ] Update [Presentation](../../docs/PRESENTATION.md) and validate the backlog.

Human acceptance: how much of the rider should be visible, and whether it helps
or distracts at speed, is the user's call and is a completion gate.

## Open questions

None.

## Completion record

Pending implementation.

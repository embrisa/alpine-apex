extends SceneTree
var failures: Array[String] = []
var checks = 0
func _initialize(): call_deferred("run")
func check(value,label):
 checks += 1
 if not value: failures.append(label)
 print("PASS: " if value else "FAIL: ",label)
func run():
 set_meta("test_lab_fixture",true) # Exercise immediate lab restarts, not summit staging.
 var game = load("res://main.tscn").instantiate()
 game.automated = true
 root.add_child(game)
 await process_frame
 game.set_physics_process(false)
 game.set_process(false)
 check(game.sim.body.initialized,"Title scene starts with a complete attached rider pose")
 game.start_speed_lab(150)
 game.automated = false # Exercise input/crash lifecycle, retaining speed-lab ineligibility.
 check(not game.session.eligible,"Lifecycle fixture starts unranked")
 game._physics_process(1.0/120.0)
 game.active = false
 game._process(.016)
 var stopped = [game.skier.global_transform,game.skier.skis[0].global_transform,game.skier.skis[1].global_transform,game.skier.desired.duplicate()]
 var state = [game.sim.position,game.sim.velocity,game.sim.ticks,game.sim.body.roll,game.sim.body.joints.duplicate()]
 game.resume()
 var stable = true
 for alpha in [0.0,.25,.75,1.0]:
  game.skier.pose(game.sim,alpha)
  stable = stable and stopped==[game.skier.global_transform,game.skier.skis[0].global_transform,game.skier.skis[1].global_transform,game.skier.desired]
 check(stable,"Resume cannot rewind the rider or skis before the next physics tick")
 check(state==[game.sim.position,game.sim.velocity,game.sim.ticks,game.sim.body.roll,game.sim.body.joints],"Resume clears only interpolation history, preserving physical state")
 game.restart()
 game.session.eligible = false
 game._physics_process(1.0/120.0) # Observe neutral before a fresh hold.
 Input.action_press("jump")
 for i in range(24): game._physics_process(1.0/120.0)
 check(game.skier.animation.current.prepare>.95,"Live input wiring advances jump preparation at 120 Hz")
 game.active = false
 var frozen_motion = game.skier.animation.current.duplicate()
 for i in range(20): game._process(.016)
 check(game.skier.animation.current==frozen_motion,"Pause freezes the composed animation state")
 game.resume()
 for i in range(25): game._physics_process(1.0/120.0)
 Input.action_release("jump")
 game._physics_process(1.0/120.0)
 check(game.skier.animation.current.prepare<.01 and not game.sim.jump_executed and game.sim.jump_buffer_remaining==0,"A hold crossing a menu cannot retain readiness or fire a delayed hop")
 game.restart()
 game.session.eligible = false
 check(game.skier.animation.current.prepare==0 and game.skier.animation.landing_events==0,"Live restart resets animation phase and contact history")
 # Every new held action crossing a lifecycle boundary must be released first.
 for action in ["spin_left","flip_forward","grab"]:
  game._physics_process(1.0/120.0)
  Input.action_press(action)
  game._physics_process(1.0/120.0)
  game.active = false
  check(not game.air_controls_armed and game.intent.air_pitch==0 and game.intent.air_yaw==0 and not game.intent.grab,"Pause cancels new intent: "+action)
  game.resume()
  game._physics_process(1.0/120.0)
  check(game.intent.air_pitch==0 and game.intent.air_yaw==0 and not game.intent.grab,"Held action cannot rearm across pause: "+action)
  Input.action_release(action)
  game._physics_process(1.0/120.0)
  check(game.air_controls_armed,"Neutral input rearms new controls: "+action)
 game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
 check(not game.air_controls_armed,"Focus loss cancels pending air controls")
 game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
 game.restart(); game.session.eligible = false
 game._physics_process(1.0/120.0)
 Input.action_press("air_tilt_forward")
 game._physics_process(1.0/120.0)
 game.active = false
 check(not game.air_tilt_controls_armed and game.intent.air_tilt==0 and not game.sim.air_control.tilt_armed,"Pause clears ordinary pitch without resetting physical attitude")
 game.resume(); game._physics_process(1.0/120.0)
 check(game.intent.air_tilt==0 and not game.air_tilt_controls_armed,"Pitch held through pause stays blocked")
 Input.action_press("flip_backward"); game._physics_process(1.0/120.0)
 check(game.intent.air_pitch==-1.0,"Ordinary pitch rearming does not block a newly commanded flip")
 Input.action_release("flip_backward"); Input.action_release("air_tilt_forward")
 game._physics_process(1.0/120.0)
 check(game.air_tilt_controls_armed,"Centering rearms normal pitch after pause")
 Input.action_press("air_tilt_backward"); game._physics_process(1.0/120.0)
 game._controller_connection_changed(0,false)
 check(game.intent.air_tilt==0 and not game.air_tilt_controls_armed and not game.sim.air_control.tilt_armed,"Disconnect clears pending normal pitch")
 game._physics_process(1.0/120.0)
 check(game.intent.air_tilt==0,"Held pitch cannot rearm across disconnect")
 Input.action_release("air_tilt_backward"); game._physics_process(1.0/120.0)
 Input.action_press("air_tilt_forward"); game._physics_process(1.0/120.0)
 game.restart(); game.session.eligible = false
 check(game.intent.air_tilt==0 and not game.air_tilt_controls_armed and game.sim.air_control.tilt_angle==0,"Restart clears pending pitch and its previous flight allowance")
 game._physics_process(1.0/120.0)
 check(game.intent.air_tilt==0,"Pitch held through restart stays blocked until centered")
 Input.action_release("air_tilt_forward"); game._physics_process(1.0/120.0)
 for transition in ["pause","disconnect","restart","focus"]:
  game.sim.position.y += 500.0
  game.sim.velocity = Vector3(0,0,25)
  game.sim._begin_flight(Basis.IDENTITY)
  game._physics_process(1.0/120.0) # Center in flight arms stick flips.
  Input.action_press("trick_pitch_forward")
  game._physics_process(1.0/120.0)
  check(game.intent.air_pitch==1.0,"Live stick starts a flip without L1 before "+transition)
  match transition:
   "pause": game.active = false; game.resume()
   "disconnect": game._controller_connection_changed(0,false)
   "restart": game.restart(); game.session.eligible = false
   "focus":
    game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
    game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
    game.resume()
  check(not game.input_router.stick_flip_armed,"Lifecycle clears direct stick flip arming: "+transition)
  game.sim.position.y += 500.0; game.sim._begin_flight(Basis.IDENTITY)
  game._physics_process(1.0/120.0)
  check(game.intent.air_pitch==0,"Stick held through lifecycle change cannot restart a flip: "+transition)
  Input.action_release("trick_pitch_forward"); game._physics_process(1.0/120.0)
  Input.action_press("trick_pitch_backward"); game._physics_process(1.0/120.0)
  check(game.intent.air_pitch==-1.0,"Center then back restarts direct control: "+transition)
  Input.action_release("trick_pitch_backward"); game._physics_process(1.0/120.0)
 game.restart(); game.session.eligible = false
 game.camera.close_view = true
 game.sim.crash("LIFECYCLE TEST")
 game._physics_process(1.0/120.0)
 check(not game.active and game.skier.ragdoll.running and not game.camera.close_view,"Crash disables ski control, enables ragdoll and exits first-person view")
 game._process(.016)
 check(game.skier.body_pivot.visible and game.hud.menu_mode=="crashed","Physical body and crash menu remain visible")
 game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
 check(game.skier.ragdoll.frozen,"Focus loss pauses the crash")
 game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
 check(not game.skier.ragdoll.frozen,"Focus return resumes the unfinished crash")
 var registration_count = game.world.cloud_lighting.materials.size()
 for i in range(3):
  game.restart()
  game.session.eligible = false
  check(game.camera.close_view and not game.skier.ragdoll.running and game.sim.body.initialized,"Restart restores camera and authoritative body")
  game.sim.crash("LIFECYCLE TEST")
  game._physics_process(1.0/120.0)
 check(game.world.cloud_lighting.materials.size()==registration_count,"Repeated crash/restart cycles do not duplicate materials")
 game.skier.ragdoll.elapsed = 15.1
 game.skier.ragdoll._physics_process(.01)
 check(game.skier.ragdoll.frozen,"Crash physics stops at its bounded time limit")
 game.skier.ragdoll.stop()
 game.queue_free()
 await process_frame
 print("RIDER_LIFECYCLE_RESULTS ",JSON.stringify({"checks":checks,"failures":failures}))
 quit(0 if failures.is_empty() else 1)

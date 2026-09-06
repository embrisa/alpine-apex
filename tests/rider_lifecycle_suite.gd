extends SceneTree
var failures: Array[String] = []
var checks = 0
func _initialize(): call_deferred("run")
func check(value,label):
 checks += 1
 if not value: failures.append(label)
 print("PASS: " if value else "FAIL: ",label)
func run():
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

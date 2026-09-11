extends RefCounted
## Camera-only opening in nearby canopy. Never changes obstacles or rider input.
var window = Vector4(.5,.5,.44,.44)
var parameters = Vector4.ZERO # activation, full-depth limit, outer limit, unused
var initialized = false
var previous_actor = Vector3.ZERO

func update(camera: Camera3D, actor: Vector3, velocity: Vector3, dt: float, riding: bool, strength: float) -> void:
	var amount=clampf(strength/100.0,0.0,1.0) if is_finite(strength) else .6
	var enabled=riding and is_instance_valid(camera) and amount>0.0
	var blend=1.0-exp(-clampf(dt,0.0,.1)/.16)
	var reset=not initialized or actor.distance_squared_to(previous_actor)>900.0
	previous_actor=actor; initialized=true
	if reset: parameters.x=0.0
	parameters.x=lerpf(parameters.x,1.0 if enabled else 0.0,blend)
	if absf(parameters.x-(1.0 if enabled else 0.0))<.002: parameters.x=1.0 if enabled else 0.0
	if not enabled: return
	var speed=Vector2(velocity.x,velocity.z).length()
	var direction=velocity.normalized() if speed>1.0 else -camera.global_basis.z
	var focus=actor+direction*clampf(speed*.3,5.0,10.0)+Vector3.UP*.65
	var center=Vector2(.5,.5)
	if not camera.is_position_behind(focus):
		var size=camera.get_viewport().get_visible_rect().size
		if size.x>0.0 and size.y>0.0:
			var projected=camera.unproject_position(focus)/size
			center=Vector2(clampf(projected.x,.49,.51),clampf(projected.y,.49,.51))
	var current=Vector2(window.x,window.y)
	center=center if reset else current.lerp(center,blend)
	var radius=lerpf(.38,.48,amount)
	window=Vector4(center.x,center.y,radius,radius)
	var depth=clampf(camera.global_position.distance_to(actor)+lerpf(8.0,18.0,amount),8.0,28.0)
	parameters.y=depth*.78; parameters.z=depth

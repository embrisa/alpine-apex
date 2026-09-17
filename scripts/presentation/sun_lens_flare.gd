extends CompositorEffect
## Presentation-only sun lens response. Visibility lives on the GPU, never in physics.
const Compute = preload("res://assets/graphics/sun_lens_flare_compute.gd")
const CONTEXT = &"alpine_sun_lens_flare"
var _mutex = Mutex.new()
var _state: Dictionary = {}
var _epoch = 0
var _configuration: Array = []
var _seen_epoch = -1
var _previous_transform = Transform3D.IDENTITY
var _buffer_key: Array = []
var _rd: RenderingDevice
var _visibility_shader = RID()
var _draw_shader = RID()
var _visibility_pipeline = RID()
var _draw_pipeline = RID()
var _nearest = RID()
var _review_callback: Callable
var _report = {"unavailable":"","dispatches":0,"resets":0,"pixels":0,"sun_uv":Vector2.ZERO,"review_readbacks":0}

func _init() -> void:
	enabled = false
	effect_callback_type = EFFECT_CALLBACK_TYPE_POST_TRANSPARENT
	access_resolved_color = false
	access_resolved_depth = false
	if DisplayServer.get_name()=="headless":_report.unavailable="A rendered Forward+ window is required"
	elif RenderingServer.get_current_rendering_method()!="forward_plus":_report.unavailable="Forward+ is required"

static func requested_strength(riding: bool, optional: bool, reduced: bool, quality: int, energy: float, direction: Vector3) -> float:
	if not riding or not optional or reduced or quality<1 or not is_finite(energy) or not direction.is_finite(): return 0.0
	return clampf(energy/1.25,0,1)*smoothstep(0.01,0.12,direction.y)*(1.0 if quality==2 else .65)

static func project_sun(transform: Transform3D, projection: Projection, direction: Vector3) -> Dictionary:
	var local=transform.basis.inverse()*direction
	var clip=projection*Vector4(local.x,local.y,local.z,0.0)
	if clip.w<=0.00001: return {"strength":0.0,"uv":Vector2(-1,-1)}
	# RenderData carries the device Y correction; Camera3D's public projection
	# does not. Normalize both to the same top-left depth/color texture UV.
	var y=clip.y/clip.w*(-1.0 if projection.y.y<0 else 1.0)
	var uv=Vector2(clip.x/clip.w*.5+.5,.5-y*.5)
	var edge=minf(minf(uv.x,1-uv.x),minf(uv.y,1-uv.y))
	var centre=1-clampf((uv-Vector2.ONE*.5).length()*1.414,0,1)
	return {"strength":smoothstep(0,.08,edge)*(.25+.75*centre*centre),"uv":uv}

static func draw_bounds(uv: Vector2, size: Vector2i) -> Rect2i:
	var aspect=float(size.y)/maxf(size.x,1)
	var bounds=Rect2(uv-Vector2(.075*aspect,.075),Vector2(.15*aspect,.15))
	for row in [Vector2(.25,.024),Vector2(-.25,.040),Vector2(-.55,.055)]:
		var centre=Vector2.ONE*.5+(uv-Vector2.ONE*.5)*row.x
		var radius=Vector2(row.y*aspect,row.y)
		bounds=bounds.merge(Rect2(centre-radius,radius*2))
	var start=Vector2i((bounds.position*Vector2(size)).floor()).clamp(Vector2i.ZERO,size)
	var end=Vector2i((bounds.end*Vector2(size)).ceil()).clamp(Vector2i.ZERO,size)
	return Rect2i(start,end-start)

func update_state(weather, riding: bool, optional: bool, reduced: bool, quality: int, dt: float, cloud_height: float, configuration: Array, transform: Transform3D, projection: Projection) -> void:
	var strength=requested_strength(riding,optional,reduced,quality,weather.sun_energy,weather.sun_direction)
	if project_sun(transform,projection,weather.sun_direction).strength<=0:strength=0.0
	if not is_finite(dt) or dt<=0 or dt>.1: strength=0.0
	_mutex.lock()
	if not _report.unavailable.is_empty(): strength=0.0
	if configuration!=_configuration or (_state.get("strength",0.0)==0)!=(strength==0):
		_epoch+=1; _configuration=configuration.duplicate()
	_state={"strength":strength,"direction":weather.sun_direction,"tint":weather.sun_color,
		"cloud_offset":weather.cloud_offset,"coverage":weather.cloud_coverage,"weather_enabled":weather.enabled,
		"quality":quality,"dt":dt,"cloud_height":cloud_height,"epoch":_epoch}
	_mutex.unlock()
	_set_active(strength>0)

func _set_active(on: bool) -> void:
	if enabled==on:return
	access_resolved_color=on; access_resolved_depth=on; enabled=on

func suspend() -> void:
	_mutex.lock()
	if _state.get("strength",0.0)>0:_epoch+=1
	_state.strength=0.0
	_mutex.unlock()
	_set_active(false)

func status() -> Dictionary:
	_mutex.lock(); var result=_report.duplicate(); _mutex.unlock()
	return result

func sample_visibility_for_review(callback: Callable) -> void:
	# Explicit diagnostic only. Gameplay and timed probes never request readback.
	_mutex.lock();_review_callback=callback;_mutex.unlock()

func _fail(reason: String) -> void:
	_mutex.lock(); _report.unavailable=reason; _mutex.unlock()

func _compile(source: String) -> RID:
	var code=RDShaderSource.new(); code.source_compute=source
	var spirv=_rd.shader_compile_spirv_from_source(code)
	if not spirv.compile_error_compute.is_empty(): _fail(spirv.compile_error_compute); return RID()
	return _rd.shader_create_from_spirv(spirv)

func _setup() -> bool:
	if _draw_pipeline.is_valid():return true
	_rd=RenderingServer.get_rendering_device()
	if _rd==null:_fail("RenderingDevice unavailable");return false
	_visibility_shader=_compile(Compute.visibility_source()); _draw_shader=_compile(Compute.DRAW)
	if not _visibility_shader.is_valid() or not _draw_shader.is_valid():return false
	_visibility_pipeline=_rd.compute_pipeline_create(_visibility_shader)
	_draw_pipeline=_rd.compute_pipeline_create(_draw_shader)
	var sampler=RDSamplerState.new()
	sampler.repeat_u=RenderingDevice.SAMPLER_REPEAT_MODE_CLAMP_TO_EDGE
	sampler.repeat_v=RenderingDevice.SAMPLER_REPEAT_MODE_CLAMP_TO_EDGE
	_nearest=_rd.sampler_create(sampler)
	return _visibility_pipeline.is_valid() and _draw_pipeline.is_valid() and _nearest.is_valid()

static func _uniform(binding: int, kind: int, ids: Array) -> RDUniform:
	var uniform=RDUniform.new();uniform.binding=binding;uniform.uniform_type=kind
	for id in ids:uniform.add_id(id)
	return uniform

func _render_callback(_type: int, render_data: RenderData) -> void:
	_mutex.lock(); var state=_state.duplicate(); var failed=not _report.unavailable.is_empty(); _mutex.unlock()
	if state.get("strength",0.0)<=0 or failed:return
	var buffers=render_data.get_render_scene_buffers() as RenderSceneBuffersRD
	if buffers==null or buffers.get_view_count()!=1:_fail("Single-view Forward+ required");return
	var size=buffers.get_internal_size()
	if size.x<1 or size.y<1:return
	var data=render_data.get_render_scene_data()
	var transform=data.get_cam_transform()
	var projection=data.get_cam_projection()
	var projected=project_sun(transform,projection,state.direction)
	if projected.strength<=0:_seen_epoch=-1;return
	if not _setup():return
	var color=buffers.get_color_layer(0); var depth=buffers.get_depth_layer(0)
	var key=[color,size,buffers.get_scaling_3d_mode(),buffers.get_msaa_3d()]
	var reset=_seen_epoch!=state.epoch or key!=_buffer_key or transform.origin.distance_to(_previous_transform.origin)>10 or transform.basis.z.dot(_previous_transform.basis.z)<.707
	_seen_epoch=state.epoch;_previous_transform=transform;_buffer_key=key
	if not buffers.has_texture(CONTEXT,&"visibility"):
		buffers.create_texture(CONTEXT,&"visibility",RenderingDevice.DATA_FORMAT_R32G32_SFLOAT,RenderingDevice.TEXTURE_USAGE_STORAGE_BIT|RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT,RenderingDevice.TEXTURE_SAMPLES_1,Vector2i.ONE,1,1,false,false)
		reset=true
	var visibility=buffers.get_texture(CONTEXT,&"visibility")
	var format=_rd.texture_get_format(color)
	if format.format!=RenderingDevice.DATA_FORMAT_R16G16B16A16_SFLOAT or not (format.usage_bits&RenderingDevice.TEXTURE_USAGE_STORAGE_BIT):_fail("HDR storage color unavailable");return
	var visibility_set=UniformSetCacheRD.get_cache(_visibility_shader,0,[_uniform(0,RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE,[_nearest,depth]),_uniform(1,RenderingDevice.UNIFORM_TYPE_IMAGE,[visibility])])
	var draw_set=UniformSetCacheRD.get_cache(_draw_shader,0,[_uniform(0,RenderingDevice.UNIFORM_TYPE_IMAGE,[color]),_uniform(1,RenderingDevice.UNIFORM_TYPE_IMAGE,[visibility])])
	var bounds=draw_bounds(projected.uv,size)
	var tint: Color=state.tint
	var sun_radius=maxf(1.5,.0105*absf(projection.y.y)*size.y*.5)
	var constants=PackedFloat32Array([size.x,size.y,state.dt,float(reset),projected.uv.x,projected.uv.y,state.strength*projected.strength,sun_radius,tint.r,tint.g,tint.b,0,transform.origin.x,transform.origin.y,transform.origin.z,0,state.direction.x,state.direction.y,state.direction.z,float(state.weather_enabled),state.cloud_offset.x,state.cloud_offset.y,state.coverage,state.cloud_height,bounds.position.x,bounds.position.y,bounds.size.x,bounds.size.y,float(state.quality==2),0,0,0]).to_byte_array()
	_rd.draw_command_begin_label("Alpine Sun Lens Flare",Color(.9,.7,.3))
	var list=_rd.compute_list_begin()
	_rd.compute_list_bind_compute_pipeline(list,_visibility_pipeline)
	_rd.compute_list_bind_uniform_set(list,visibility_set,0)
	_rd.compute_list_set_push_constant(list,constants,128)
	_rd.compute_list_dispatch(list,1,1,1)
	_rd.compute_list_add_barrier(list)
	_rd.compute_list_bind_compute_pipeline(list,_draw_pipeline)
	_rd.compute_list_bind_uniform_set(list,draw_set,0)
	_rd.compute_list_set_push_constant(list,constants,128)
	_rd.compute_list_dispatch(list,ceili(bounds.size.x/8.0),ceili(bounds.size.y/8.0),1)
	_rd.compute_list_end(); _rd.draw_command_end_label()
	_mutex.lock()
	_report.dispatches+=1;_report.resets+=int(reset);_report.pixels=bounds.size.x*bounds.size.y;_report.sun_uv=projected.uv
	var review=_review_callback;_review_callback=Callable()
	_mutex.unlock()
	if review.is_valid():
		var values=_rd.texture_get_data(visibility,0).to_float32_array()
		_mutex.lock();_report.review_readbacks+=1;_mutex.unlock()
		review.call_deferred(values)

func _notification(what: int) -> void:
	if what==NOTIFICATION_PREDELETE:
		RenderingServer.call_on_render_thread(_free_gpu.bind([_visibility_pipeline,_draw_pipeline,_visibility_shader,_draw_shader,_nearest]))

static func _free_gpu(rids: Array) -> void:
	var device=RenderingServer.get_rendering_device()
	if device==null:return
	for rid in rids:
		if rid.is_valid():device.free_rid(rid)

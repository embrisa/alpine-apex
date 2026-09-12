extends CompositorEffect
## Riding-camera, single-frame HDR velocity blur. No simulation or color history.
const Compute = preload("res://assets/graphics/scene_motion_blur_compute.gd")
const CONTEXT = &"alpine_scene_motion_blur"
const CORRECTION = Projection(Vector4(1,0,0,0),Vector4(0,-1,0,0),Vector4(0,0,-1,0),Vector4(0,0,0,1))
var _mutex = Mutex.new()
var _state = {"strength":0.0,"dt":0.0,"epoch":0}
var _report = {"unavailable":"","dispatches":0,"resets":0,"scratch_bytes":0,"internal_pixels":Vector2i.ZERO}
var _configuration: Array = []
var _rd: RenderingDevice
var _blur_shader = RID()
var _copy_shader = RID()
var _blur_pipeline = RID()
var _copy_pipeline = RID()
var _linear = RID()
var _nearest = RID()
var _epoch = -1
var _buffer_key: Array = []
var _previous_transform = Transform3D.IDENTITY
var _previous_projection = Projection.IDENTITY
var _warmup = 2

func _init() -> void:
	enabled = false
	effect_callback_type = EFFECT_CALLBACK_TYPE_POST_TRANSPARENT
	access_resolved_color = false
	access_resolved_depth = false
	needs_motion_vectors = false
	_report.unavailable = unavailable_reason()

static func unavailable_reason() -> String:
	if DisplayServer.get_name()=="headless": return "a rendered Forward+ window is required."
	if RenderingServer.get_current_rendering_method()!="forward_plus": return "the Forward+ renderer is required."
	return ""

static func requested_strength(profile: Dictionary, riding: bool, optional: bool, reduced: bool) -> float:
	if not riding or not optional or reduced or profile.get("motion_blur_enabled")!=true: return 0.0
	var value = profile.get("motion_blur_strength",0.0)
	if typeof(value) not in [TYPE_FLOAT,TYPE_INT] or not is_finite(float(value)): return 0.0
	return clampf(float(value),0.0,100.0)/100.0

static func exposure_scale(strength: float, dt: float) -> float:
	# A fixed 1/120 s maximum exposure, independent of rendered/FG cadence.
	# Long stalls are cuts, not an opportunity to smear a whole screen.
	if not is_finite(dt) or dt<=0.0 or dt>0.1: return 0.0
	return clampf(strength,0.0,1.0)/(120.0*maxf(dt,1.0/500.0))

func update_state(profile: Dictionary, riding: bool, optional: bool, reduced: bool, dt: float, configuration: Array) -> void:
	var strength = requested_strength(profile,riding,optional,reduced)
	_mutex.lock()
	if not _report.unavailable.is_empty(): strength = 0.0
	if configuration!=_configuration or (_state.strength==0.0)!=(strength==0.0):
		_state.epoch += 1
		_configuration = configuration.duplicate()
	_state.strength = strength
	_state.dt = dt
	_mutex.unlock()
	_set_active(strength>0.0)

func _set_active(on: bool) -> void:
	# Disabled compositor flags are also removed: Native Off never requests a
	# motion pass or extra resolves. Reconstruction retains its independent needs.
	if enabled==on: return
	needs_motion_vectors = on
	access_resolved_color = on
	access_resolved_depth = on
	enabled = on

func suspend() -> void:
	_mutex.lock()
	if _state.strength>0.0: _state.epoch += 1
	_state.strength = 0.0
	_mutex.unlock()
	_set_active(false)

func status() -> Dictionary:
	_mutex.lock()
	var result = _report.duplicate()
	_mutex.unlock()
	return result

func _fail(reason: String) -> void:
	_mutex.lock()
	_report.unavailable = reason
	_mutex.unlock()
	# The main-thread owner sees this and removes requests on its next update.

func _compile(source_text: String) -> RID:
	var source = RDShaderSource.new()
	source.source_compute = source_text
	var spirv = _rd.shader_compile_spirv_from_source(source)
	if not spirv.compile_error_compute.is_empty():
		_fail("shader compilation failed: "+spirv.compile_error_compute)
		return RID()
	var shader = _rd.shader_create_from_spirv(spirv)
	if not shader.is_valid(): _fail("the blur shader could not be created.")
	return shader

func _setup() -> bool:
	if _blur_pipeline.is_valid() and _copy_pipeline.is_valid(): return true
	_rd = RenderingServer.get_rendering_device()
	if _rd==null: _fail("rendering device is unavailable."); return false
	_blur_shader = _compile(Compute.BLUR)
	_copy_shader = _compile(Compute.COPY)
	if not _blur_shader.is_valid() or not _copy_shader.is_valid(): return false
	_blur_pipeline = _rd.compute_pipeline_create(_blur_shader)
	_copy_pipeline = _rd.compute_pipeline_create(_copy_shader)
	var sampler = RDSamplerState.new()
	sampler.repeat_u = RenderingDevice.SAMPLER_REPEAT_MODE_CLAMP_TO_EDGE
	sampler.repeat_v = RenderingDevice.SAMPLER_REPEAT_MODE_CLAMP_TO_EDGE
	_nearest = _rd.sampler_create(sampler)
	sampler.min_filter = RenderingDevice.SAMPLER_FILTER_LINEAR
	sampler.mag_filter = RenderingDevice.SAMPLER_FILTER_LINEAR
	_linear = _rd.sampler_create(sampler)
	var ready = _blur_pipeline.is_valid() and _copy_pipeline.is_valid() and _linear.is_valid() and _nearest.is_valid()
	if not ready: _fail("blur pipeline or sampler allocation failed.")
	return ready

static func _uniform(binding: int, kind: int, ids: Array) -> RDUniform:
	var uniform = RDUniform.new()
	uniform.binding = binding
	uniform.uniform_type = kind
	for id in ids: uniform.add_id(id)
	return uniform

func _render_callback(_type: int, render_data: RenderData) -> void:
	_mutex.lock()
	var state = _state.duplicate()
	var failed: bool = not _report.unavailable.is_empty()
	_mutex.unlock()
	if state.strength<=0.0 or failed: return
	var buffers = render_data.get_render_scene_buffers() as RenderSceneBuffersRD
	if buffers==null or buffers.get_view_count()!=1: _fail("single-view Forward+ buffers are required."); return
	var size = buffers.get_internal_size()
	if size.x<1 or size.y<1: return
	var data = render_data.get_render_scene_data()
	var transform = data.get_cam_transform()
	var projection = data.get_cam_projection()
	var key = [size,buffers.get_target_size(),buffers.get_color_layer(0),buffers.get_scaling_3d_mode(),buffers.get_msaa_3d()]
	var scale = exposure_scale(state.strength,state.dt)
	var cut = _epoch!=state.epoch or key!=_buffer_key or scale==0.0 or transform.origin.distance_to(_previous_transform.origin)>10.0 or transform.basis.z.dot(_previous_transform.basis.z)<0.707
	if cut:
		_warmup = 2
		_mutex.lock(); _report.resets += 1; _mutex.unlock()
	var reprojection = CORRECTION*_previous_projection*Projection(_previous_transform.affine_inverse()*transform)*(CORRECTION*projection).inverse()
	_previous_transform = transform
	_previous_projection = projection
	_epoch = state.epoch
	_buffer_key = key
	if _warmup>0: _warmup -= 1; return
	if not _setup(): return
	var color = buffers.get_color_layer(0)
	var depth = buffers.get_depth_layer(0)
	var velocity = buffers.get_velocity_layer(0)
	if not color.is_valid() or not depth.is_valid() or not velocity.is_valid(): _fail("scene depth or motion vectors are unavailable."); return
	var format = _rd.texture_get_format(color)
	if format.format!=RenderingDevice.DATA_FORMAT_R16G16B16A16_SFLOAT or not (format.usage_bits & RenderingDevice.TEXTURE_USAGE_STORAGE_BIT):
		_fail("the scene color buffer does not support HDR storage."); return
	# RenderSceneBuffersRD owns this bounded scratch texture and frees it on
	# viewport reconfiguration/destruction; never retain buffers or RenderData.
	if not buffers.has_texture(CONTEXT,&"color"):
		buffers.create_texture(CONTEXT,&"color",format.format,RenderingDevice.TEXTURE_USAGE_STORAGE_BIT|RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT,RenderingDevice.TEXTURE_SAMPLES_1,size,1,1,false,false)
	var scratch = buffers.get_texture(CONTEXT,&"color")
	if not scratch.is_valid(): _fail("blur scratch allocation failed."); return
	var blur_set = UniformSetCacheRD.get_cache(_blur_shader,0,[
		_uniform(0,RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE,[_linear,color]),
		_uniform(1,RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE,[_nearest,depth]),
		_uniform(2,RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE,[_nearest,velocity]),
		_uniform(3,RenderingDevice.UNIFORM_TYPE_IMAGE,[scratch])])
	var copy_set = UniformSetCacheRD.get_cache(_copy_shader,0,[_uniform(0,RenderingDevice.UNIFORM_TYPE_IMAGE,[scratch]),_uniform(1,RenderingDevice.UNIFORM_TYPE_IMAGE,[color])])
	if not blur_set.is_valid() or not copy_set.is_valid(): _fail("blur buffer bindings are unavailable."); return
	var constants = PackedFloat32Array()
	for column in [reprojection.x,reprojection.y,reprojection.z,reprojection.w]:
		constants.append_array(PackedFloat32Array([column.x,column.y,column.z,column.w]))
	constants.append_array(PackedFloat32Array([size.x,size.y,scale,24.0*size.y/1080.0*state.strength,projection.get_z_near(),projection.get_z_far(),0,0]))
	_rd.draw_command_begin_label("Alpine Scene Motion Blur",Color(0.4,0.7,1.0))
	var list = _rd.compute_list_begin()
	_rd.compute_list_bind_compute_pipeline(list,_blur_pipeline)
	_rd.compute_list_bind_uniform_set(list,blur_set,0)
	_rd.compute_list_set_push_constant(list,constants.to_byte_array(),96)
	_rd.compute_list_dispatch(list,ceili(size.x/8.0),ceili(size.y/8.0),1)
	_rd.compute_list_add_barrier(list)
	_rd.compute_list_bind_compute_pipeline(list,_copy_pipeline)
	_rd.compute_list_bind_uniform_set(list,copy_set,0)
	_rd.compute_list_dispatch(list,ceili(size.x/8.0),ceili(size.y/8.0),1)
	_rd.compute_list_end()
	_rd.draw_command_end_label()
	_mutex.lock()
	_report.dispatches += 1
	_report.scratch_bytes = size.x*size.y*8
	_report.internal_pixels = size
	_mutex.unlock()

static func _free_gpu(rids: Array) -> void:
	var device = RenderingServer.get_rendering_device()
	if device==null: return
	for rid in rids:
		if rid.is_valid(): device.free_rid(rid)

func _notification(what: int) -> void:
	if what==NOTIFICATION_PREDELETE:
		RenderingServer.call_on_render_thread(_free_gpu.bind([_blur_pipeline,_copy_pipeline,_blur_shader,_copy_shader,_linear,_nearest]))

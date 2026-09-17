extends SceneTree
## Consumer contracts without mountain generation or a native GPU workload.
const Settings = preload("res://scripts/presentation/pc_graphics_settings.gd")
const Presets = preload("res://scripts/presentation/graphics_presets.gd")
const Profile = preload("res://scripts/presentation/graphics_quality.gd")
const Powder = preload("res://scripts/presentation/powder_surface.gd")
const GhostStack = preload("res://scripts/presentation/ghost_track_stack.gd")
const Tracks = preload("res://scripts/presentation/snow_tracks.gd")
const Assets = preload("res://scripts/presentation/alpine_assets.gd")
const Clouds = preload("res://scripts/presentation/cloud_lighting.gd")
var failures: Array[String] = []
var checks = 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	print("PASS: " if ok else "FAIL: ",label)
	if not ok: failures.append(label)
func run() -> void:
	check_sharpening()
	check_scenery_snow()
	check_scenery_shadows()
	check_foliage()
	check_track_uploads()
	print("GRAPHICS_OVERRIDE_RESULTS ",JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)

func check_sharpening() -> void:
	var settings = Settings.new()
	check(is_equal_approx(settings.sharpness,.825) and is_equal_approx(settings.viewport_sharpness(),.35),"Default sharpening preserves the established .35 viewport appearance")
	var prior_sdk_strength = -1.0
	for strength in [0.0,.25,.5,.825,1.0]:
		settings.set_graphics_value("sharpness",strength)
		# This is the conversion in the installed clustered renderer before the SDK.
		var sdk_strength = clampf(1.0-settings.viewport_sharpness()/2.0,0.0,1.0)
		check(is_equal_approx(sdk_strength,strength) and sdk_strength>prior_sdk_strength,"Sharpening %.3f reaches matching increasing SDK strength" % strength)
		prior_sdk_strength = sdk_strength
	settings.set_graphics_value("sharpness",-3.0)
	check(settings.sharpness==0.0 and settings.viewport_sharpness()==2.0,"Sharpening below range disables sharpening at the consumer")
	settings.set_graphics_value("sharpness",3.0)
	check(settings.sharpness==1.0 and settings.viewport_sharpness()==0.0,"Sharpening above range clamps to full strength")
	settings.restore({"sharpness":NAN})
	check(is_equal_approx(settings.viewport_sharpness(),.35),"Invalid persisted sharpening returns to the established default")
	settings.select_preset(10)
	settings.reset_group("Snow & particles")
	check(not settings.custom and is_equal_approx(settings.sharpness,.825),"Preset and group resets agree on the sharpening default")
	check(Presets.CONTROLS.contact_intensity[0]=="Contact shading in direct light" and Profile.numbered(7).contact_intensity==.20,"Contact control describes its direct-light consumer and preserves its .20 contribution")

func check_scenery_snow() -> void:
	var settings = Settings.new()
	for preset in range(1,11):
		settings.select_preset(preset)
		var cheap = settings.profile().snapshot()
		check(not cheap.offmap_snow_detail,"Preset %d keeps unmeasured distant deposits opt-in" % preset)
		settings.set_graphics_value("offmap_snow_detail",true)
		var enhanced = settings.profile().snapshot()
		check(enhanced.offmap_snow_detail and settings.custom,"Preset %d permits independent snow detail" % preset)
		enhanced.erase("offmap_snow_detail"); cheap.erase("offmap_snow_detail")
		check(enhanced==cheap,"Preset %d snow override preserves playable quality, geometry and coverage budgets" % preset)
	var path = "res://artifacts/scenery_snow/settings_test.cfg"
	DirAccess.make_dir_recursive_absolute("res://artifacts/scenery_snow")
	check(settings.save_preferences(path)==OK,"Snow override saves outside personal preferences")
	var reloaded = Settings.new(); reloaded.load_preferences(path)
	check(reloaded.profile().offmap_snow_detail,"Saved distant snow override survives reload")
	reloaded.reset_group("Snow & particles")
	check(reloaded.profile().offmap_snow_detail,"Playable snow group reset preserves scenery override")
	reloaded.reset_group("Scenery")
	check(not reloaded.profile().offmap_snow_detail,"Scenery reset restores cheap distant snow")
	reloaded.apply_arguments(["--offmap-snow-detail=on"])
	check(reloaded.profile().offmap_snow_detail,"Explicit capture/benchmark mode uses the saved override consumer")
	reloaded.apply_arguments(["--offmap-snow-detail=off"])
	check(not reloaded.profile().offmap_snow_detail,"Explicit cheap mode disables enhanced snow")
	reloaded.set_graphics_value("offmap_snow_detail",true); reloaded.select_preset(7)
	check(not reloaded.profile().offmap_snow_detail,"Preset selection clears enhanced snow override")
	reloaded.restore({"overrides":{"offmap_snow_detail":"true"}})
	check(not reloaded.profile().offmap_snow_detail,"Invalid persisted detail type retains cheap default")

func check_scenery_shadows() -> void:
	var settings=Settings.new()
	var all_off=true
	for preset in range(1,11): all_off=all_off and Profile.numbered(preset).offmap_shadow_quality==0
	check(all_off,"All presets leave distant mountain shadows optional")
	settings.select_preset(7)
	var original=settings.profile().snapshot()
	for value in [1,2,0]:
		settings.set_graphics_value("offmap_shadow_quality",value)
		var changed=settings.profile().snapshot()
		check(changed.offmap_shadow_quality==value,"Distant shadow quality reaches the effective profile")
		changed.offmap_shadow_quality=original.offmap_shadow_quality
		check(changed==original,"Distant shadow override preserves all other scenery, snow and gameplay shadow budgets")
	settings.apply_arguments(["--offmap-shadows=high"])
	var path="res://artifacts/scenery_mountain_shadows/settings.cfg"
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	check(settings.save_preferences(path)==OK,"Distant shadow selection saves to isolated preferences")
	var restored=Settings.new(); restored.load_preferences(path)
	check(restored.profile().offmap_shadow_quality==2,"Distant shadow quality survives reload")
	restored.reset_group("Lighting & shadows")
	check(restored.profile().offmap_shadow_quality==2,"Gameplay shadow reset leaves distant scenery independent")
	restored.reset_group("Scenery")
	check(restored.profile().offmap_shadow_quality==0,"Scenery reset restores Off")
	restored.restore({"overrides":{"offmap_shadow_quality":"high"}})
	check(restored.profile().offmap_shadow_quality==0,"Invalid persisted shadow type is rejected")

func check_foliage() -> void:
	var source = StandardMaterial3D.new()
	source.resource_name = "FC_Tree"
	var library = Assets.new(Clouds.new(),Profile.numbered(7))
	var material = library.material_for(source)
	for preset in [7,1]:
		for texture_tier in [0,2,1,0]:
			var profile = Profile.numbered(preset,{"texture_tier":texture_tier})
			library.apply_quality(profile)
			var suffix: String = ["_low","_balanced",""][texture_tier]
			var color: Resource = material.get_shader_parameter("foliage_texture")
			var normal: Resource = material.get_shader_parameter("foliage_normal_ao")
			check(color!=null and color.resource_path=="res://assets/graphics/trees/textures/foliage_color%s.res" % suffix,"Preset %d texture tier %d reaches resident foliage color" % [preset,texture_tier])
			check(normal!=null and normal.resource_path=="res://assets/graphics/trees/textures/foliage_normal_ao%s.res" % suffix,"Preset %d texture tier %d reaches resident foliage normal/AO" % [preset,texture_tier])
			var fresh = Assets.new(Clouds.new(),profile).material_for(source)
			check(fresh.get_shader_parameter("foliage_texture")==color and fresh.get_shader_parameter("foliage_normal_ao")==normal,"Late material creation and live reapplication use identical foliage variants")

func check_track_uploads() -> void:
	var required_strokes: int = Presets.MAX_TRACK_HISTORY+GhostStack.MAX_EXTRA_STROKES+Powder.LIVE_STROKES
	check(Powder.MAX_STROKES==required_strokes and Powder.BUFFER_BYTES==required_strokes*32,"Deformation allocation holds maximum player history, aggregate ghost history/live slots and two player footprints")
	var tracks = Tracks.new()
	tracks.lighting = Clouds.new()
	root.add_child(tracks)
	var mirror = PackedByteArray()
	mirror.resize(Powder.BUFFER_BYTES)
	var live = PackedFloat32Array([-.2,0,-.2,1.5,.24,.05,.5,1,.2,0,.2,1.5,.24,.06,.7,-1]).to_byte_array()
	# The exact sequence requested by the review also crosses all asset anchors.
	for preset in [7,8,10,7,1,7,10]:
		tracks.apply_quality(Profile.numbered(preset))
		var uploads = tracks.take_gpu_updates()
		uploads.append({"offset":tracks.capacity*Powder.STROKE_BYTES,"bytes":live})
		var valid = Powder.valid_submission(uploads,tracks.capacity+Powder.LIVE_STROKES)
		check(valid,"Preset %d history resize and live endpoints fit the real deformation allocation" % preset)
		if valid:
			apply_to_mirror(mirror,uploads)
			check(mirror.slice(0,tracks.capacity*32)==tracks.gpu_stamps.to_byte_array() and mirror.slice(tracks.capacity*32,(tracks.capacity+2)*32)==live,"Preset %d uploads reconstruct complete history and both live slots" % preset)
	# Partial producer spans on either side of the maximum-size ring wrap.
	for index in [tracks.capacity-2,tracks.capacity-1,0,1]:
		tracks.transforms[index] = Transform3D(Basis.IDENTITY,Vector3(index*.37,0,index*.61))
		tracks.corner_history[index] = Color(0,0,0,0)
		tracks.appearance_history[index] = Color(.03,.7,.2,1)
		tracks._upload(index)
	var wrapped = tracks.take_gpu_updates()
	check(wrapped.size()==2 and wrapped[0].offset==(tracks.capacity-2)*32 and wrapped[1].offset==0,"Maximum-capacity ring wrap emits two bounded dirty spans")
	wrapped.append({"offset":tracks.capacity*32,"bytes":live})
	var valid_wrap = Powder.valid_submission(wrapped,tracks.capacity+Powder.LIVE_STROKES)
	check(valid_wrap,"Maximum-capacity split spans plus live slots are dispatchable")
	if valid_wrap:
		apply_to_mirror(mirror,wrapped)
		check(mirror.slice(0,tracks.capacity*32)==tracks.gpu_stamps.to_byte_array() and mirror.slice(tracks.capacity*32,(tracks.capacity+Powder.LIVE_STROKES)*32)==live,"Split uploads preserve all maximum-capacity history and both live footprints")
	var aggregate_tail = [{"offset":(required_strokes-2)*32,"bytes":live}]
	check(Powder.valid_submission(aggregate_tail,required_strokes),"Final live footprints after all ghost slots fit the real allocation")
	check(not Powder.valid_submission(aggregate_tail,required_strokes-1),"Aggregate live upload rejects a truncated final slot")
	check(not Powder.valid_submission([],Powder.MAX_STROKES+1),"Dispatch count cannot read beyond the allocated buffer")
	check(not Powder.valid_submission([],1),"Dispatch count always reserves both live strokes")
	var one_stroke = live.slice(0,32)
	for bad in [
		{"offset":Powder.BUFFER_BYTES,"bytes":one_stroke},
		{"offset":Powder.BUFFER_BYTES-32,"bytes":live},
		{"offset":-32,"bytes":one_stroke},
		{"offset":1,"bytes":one_stroke},
		{"offset":0,"bytes":live.slice(0,31)},
		{"offset":0.0,"bytes":one_stroke},
		{"offset":0,"bytes":"invalid"},
		{"offset":0}]:
		check(not Powder.valid_submission([{"offset":0,"bytes":one_stroke},bad],Powder.MAX_STROKES),"An invalid upload rejects its entire batch before any GPU mutation: %s" % str(bad.get("offset")))
	check(not Powder.valid_submission([{"offset":64,"bytes":one_stroke}],2),"Upload endpoints also obey the current dispatch range after downsizing")
	tracks.free()

func apply_to_mirror(mirror: PackedByteArray, uploads: Array) -> void:
	for upload in uploads:
		for i in upload.bytes.size(): mirror[upload.offset+i] = upload.bytes[i]

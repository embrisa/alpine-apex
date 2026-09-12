extends Node3D
## Art batches use the existing obstacle list verbatim. No physics bodies here.
## Cosmetic selection only: separate from course / replay generation identity.
const SCENERY_VERSION = 5
const Obstacles = preload("res://scripts/world/obstacle_access.gd")
const TREE_FAMILIES = ["spruce","fir","pine","larch","birch","rowan","scots_pine","wind_pine","snag","split_snag","hollow_snag"]
const COLLECTION_FAMILY = {"spruce":"spruce","fir":"fir","pine":"pine","larch":"birch","birch":"birch","rowan":"birch","scots_pine":"pine","wind_pine":"pine","snag":"dead","split_snag":"broken","hollow_snag":"broken"}
const ROCK_FAMILIES = ["rock_granite","rock_slate","rock_boulder","rock_limestone","rock_gneiss","rock_split_rock","rock_outcrop"]
var assets
var quality
var batches: Array[MultiMeshInstance3D] = []
var scrub_candidates: Array[Transform3D] = []
var obstacle_count: int = 0
var family_counts: Dictionary = {}
var powder_caps
var powder_cap_count = 0
var tree_motion
var forest_shadow_material: ShaderMaterial
var contact_snow
var dense_woodlands = false
var density_forest
var build_job

func build(field, library, profile, terrain_snow: ShaderMaterial = null, checkpoint: Callable = Callable(), prepared_forest = null) -> void:
	build_job = field.job if "job" in field else null
	assets = library
	quality = profile
	tree_motion = preload("res://scripts/presentation/tree_motion.gd").new(assets,"res://assets/graphics/trees/branches.json")
	powder_caps = preload("res://scripts/presentation/powder_caps.gd").new(assets.lighting)
	contact_snow = preload("res://scripts/presentation/asset_snow_contacts.gd").new()
	add_child(contact_snow)
	obstacle_count = Obstacles.count(field)
	dense_woodlands = "GENERATOR_ID" in field and "GENERATOR_VERSION" in field and field.GENERATOR_ID=="alpine-drainage" and field.GENERATOR_VERSION>=12
	if dense_woodlands and field.GENERATOR_VERSION>=13:
		density_forest=preload("res://scripts/presentation/density_forest.gd").new()
		density_forest.job = build_job
		add_child(density_forest)
	var art_rng = RandomNumberGenerator.new()
	art_rng.seed = field.seed_value+61217+SCENERY_VERSION
	var groups: Dictionary = {}
	if prepared_forest:
		family_counts = prepared_forest.family_counts
		density_forest.use_prepared(prepared_forest)
		tree_motion.bind_prepared(prepared_forest,field.tree_data)
	for i in range(0 if prepared_forest else Obstacles.count(field)):
		if checkpoint.is_valid() and i%(512 if density_forest!=null else 128) == 0:
			await checkpoint.call("Placing trees · %d / %d" % [i,Obstacles.count(field)],100.0*i/maxi(1,Obstacles.count(field)))
		var ob = Obstacles.record(field,i)
		var family = _family(ob,art_rng)
		if field.has_method("stand_density") and (field.environment_weight(ob.position.x,ob.position.z)>0 if field.has_method("environment_weight") else field.sector_weight(ob.position.x,ob.position.z)>0):
			# Small coherent palettes keep dense stands legible and batched. The
			# legacy random stream still advances once per obstacle above.
			# Seeded local palettes avoid the repeating east-west species stripes
			# produced by a linear cell index modulo the three conifer families.
			var region = hash("%d:%d:%d" % [field.seed_value,floori(ob.position.x/256),floori(ob.position.z/256)])
			var mixed = 1 if posmod(hash(Vector2(ob.position.x,ob.position.z)),5)==0 else 0
			family = ["spruce","fir","pine"][posmod(region+mixed,3)] if ob.tree else ["rock_slate","rock_outcrop"][posmod(region,2)]
			# One bare family per region adds readable winter/dead silhouettes
			# while retaining coherent stands and their existing obstacle anchors.
			if ob.tree and posmod(hash(Vector2(ob.position.x,ob.position.z)),7)==0:
				family = ["birch","snag","split_snag"][posmod(region,3)]
		# Dense stands need smaller LOD groups: a distant group centre must not
		# promote hundreds of 130k-triangle trees around a nearby opening.
		var cell = 48.0 if dense_woodlands and ob.tree else 128.0
		# One derivative per family per region keeps the enlarged library batched.
		# Neighbouring regions expose all four crown / stone shapes over a descent.
		var variant_count = 2 if family=="rock_boulder" else 4
		var variant = 1+posmod(hash("%s_%d_%d_%d" % [family,floori(ob.position.x/cell),floori(ob.position.z/cell),field.seed_value]),variant_count)
		var asset_id = "%s_%d" % [family,variant]
		if ob.tree:
			asset_id = "forest_%s_%02d" % [COLLECTION_FAMILY[family],variant]
		elif not ob.tree:
			var kind = "buttress" if family in ["rock_outcrop","rock_split_rock"] else ("ledge" if family in ["rock_slate","rock_gneiss","rock_limestone"] else "boulder")
			asset_id = "pc_rock_%s_%d" % [kind,1+(variant-1)%2]
		family_counts[family] = family_counts.get(family,0)+1
		var key = "%d_%d_%s" % [floori(ob.position.x/cell),floori(ob.position.z/cell),asset_id]
		var capped: bool = ob.get("powder_cap",false) or (not ob.tree and field.has_method("snow_depth_at") and field.snow_depth_at(ob.position.x,ob.position.z)>.055 and field.contact_normal(ob.position.x,ob.position.z).y>.64)
		if capped: key += "_powder"
		if (density_forest==null or not ob.tree) and not groups.has(key):
			groups[key] = {"tree":ob.tree,"asset":asset_id,"transforms":[],"powder":capped,"height_m":19.0}
		if density_forest==null or not ob.tree: groups[key].height_m = maxf(groups[key].height_m,ob.height+2.0)
		# The generator's scale supplies young-to-mature sizes; rendering does
		# not change the physical obstacle's radius or height.
		var visual_scale: float = ob.scale
		if ob.tree: visual_scale *= 10.5/float(assets.tree_record(asset_id).height_m)
		var transform_value = Transform3D(Basis(Vector3.UP,ob.yaw).scaled(Vector3.ONE*visual_scale),ob.position)
		var depth: float = field.snow_depth_at(ob.position.x,ob.position.z) if field.has_method("snow_depth_at") else 0.0
		if ob.tree:
			var footprint = contact_snow.root_footprint(asset_id,assets)
			transform_value = contact_snow.seat_tree(field,transform_value,footprint)
			tree_motion.add_tree(transform_value,asset_id)
			var radius: float = contact_snow.root_radius(footprint,visual_scale)
			# V13 trunks are fully seated using the exact root footprint. Avoid
			# baking hundreds of cosmetic snow triangles for every distant trunk.
			if density_forest==null: contact_snow.add_contact(field,ob.position,Vector2.ONE*radius,ob.yaw,depth)
		elif capped:
			transform_value.origin.y -= powder_caps.BURIAL*ob.scale
			powder_cap_count += 1
			var bounds: AABB = assets.mesh(asset_id).get_aabb()
			var center = transform_value*bounds.get_center()
			contact_snow.add_contact(field,center,Vector2(bounds.size.x,bounds.size.z)*visual_scale*.46,ob.yaw,depth)
		if density_forest==null or not ob.tree: groups[key].transforms.append(transform_value)
		if density_forest!=null and ob.tree:
			density_forest.add_tree(asset_id,transform_value,ob.height+2.0)
	var uploaded = 0
	for group in groups.values():
		if group.tree:
			if density_forest!=null: continue
			for lod in range(3):
				_batch(assets.mesh("%s_lod%d" % [group.asset,lod]),group.transforms,lod,group.height_m)
			if group.asset.begins_with("pc_") or group.asset.begins_with("td_") or group.asset.begins_with("forest_"):
				_batch(assets.tree_shadow(group.asset),group.transforms,5,group.height_m)
		else:
			_batch(assets.mesh(group.asset),group.transforms,3)
			if group.powder:
				_batch(powder_caps.mesh_for(group.asset,assets.mesh(group.asset)),group.transforms,3)
				batches[-1].set_meta("powder_cap",true)
		uploaded += 1
		if checkpoint.is_valid() and uploaded%12 == 0:
			await checkpoint.call("Building forest scenery · %d / %d sections" % [uploaded,groups.size()],100.0*uploaded/groups.size())
	groups.clear()
	if density_forest!=null: await density_forest.finish(self,checkpoint)
	if build_job and build_job.is_cancelled(): return
	# Use the terrain's textures, exposure mask and cloud lighting so the skirt
	# joins the snow without a differently coloured ring. Keep its own material:
	# the local ski-track patch must not discard these small raised contacts.
	var contact_material: ShaderMaterial
	if terrain_snow:
		contact_material = terrain_snow.duplicate()
		contact_material.set_shader_parameter("powder_patch_enabled",false)
		assets.surface_materials.append(contact_material)
		assets.lighting.register(contact_material)
	else: contact_material = assets.terrain_material()
	await contact_snow.finish(contact_material,profile,checkpoint)
	# Small scrub is scenery, kept out of the corridor and away from trunk centers.
	var rng = RandomNumberGenerator.new()
	rng.seed = field.seed_value+82091
	var scrub_groups: Dictionary = {}
	for i in range(600):
		var x = rng.randf_range(field.X_MIN+64,-field.X_MIN-64) if field.is_summit_mountain() else rng.randf_range(-220,220)
		var z = rng.randf_range(field.Z_MIN+64,-field.Z_MIN-64) if field.is_summit_mountain() else rng.randf_range(80,1550)
		if field.is_summit_mountain() and Vector2(x,z).length()<1900: continue
		if absf(x)<45.0:
			continue
		var p = Vector3(x,field.sample(x,z).height,z)
		var transform_value = Transform3D(Basis(Vector3.UP,rng.randf_range(-PI,PI)).scaled(Vector3.ONE*rng.randf_range(.55,1.1)),p)
		scrub_candidates.append(transform_value)
		var key = "%d_%d_%d" % [floori(x/32),floori(z/32),i%2+1]
		if not scrub_groups.has(key): scrub_groups[key] = {"variant":i%2+1,"transforms":[]}
		scrub_groups[key].transforms.append(transform_value)
	for group in scrub_groups.values():
		_batch(assets.mesh("scrub_%d" % group.variant),group.transforms,4)
	apply_quality(profile)

func _family(ob: Dictionary, rng: RandomNumberGenerator) -> String:
	var choice = rng.randf()
	# Sheltered shoulders admit more birch/rowan; broad patches vary the larch
	# and fir mix. Never move or add a collidable tree to achieve this pattern.
	var shoulder = smoothstep(60.0,260.0,absf(ob.position.x))
	var patch = .5+.5*sin(ob.position.z*.009+ob.position.x*.014)
	if ob.tree:
		if choice<.105: return ["snag","split_snag","hollow_snag"][rng.randi_range(0,2)]
		if choice<.205-shoulder*.04: return ["birch","rowan"][rng.randi_range(0,1)]
		if choice<.34+patch*.04: return "larch"
		if choice<.50: return "fir"
		if choice<.64: return "pine"
		if choice<.76: return "scots_pine"
		if choice<.88: return "wind_pine"
		return "spruce"
	return ROCK_FAMILIES[mini(ROCK_FAMILIES.size()-1,int(choice*ROCK_FAMILIES.size()))]

static func prepare_tree_batch(transforms: Array, height_m: float, local_bounds: AABB = AABB()) -> Dictionary:
	var packed = PackedFloat32Array()
	packed.resize(transforms.size()*12)
	var bounds = AABB(transforms[0].origin,Vector3.ZERO)
	for i in transforms.size():
		var t: Transform3D = transforms[i]
		# RenderingServer's 3D MultiMesh buffer is three row-major vec4s.
		var values = [t.basis.x.x,t.basis.y.x,t.basis.z.x,t.origin.x,
			t.basis.x.y,t.basis.y.y,t.basis.z.y,t.origin.y,
			t.basis.x.z,t.basis.y.z,t.basis.z.z,t.origin.z]
		for j in 12: packed[i*12+j] = values[j]
		bounds = bounds.expand(t.origin)
	if local_bounds.has_volume():
		bounds = transforms[0]*local_bounds
		for pose in transforms: bounds = bounds.merge(pose*local_bounds)
	else:
		bounds.position -= Vector3(10,.5,10)
		bounds.size += Vector3(20,height_m,20)
	return {"buffer":packed,"bounds":bounds,"multimeshes":{}}

func _batch(mesh: Mesh, transforms: Array, lod: int, height_m: float = 19.0, prepared: Dictionary = {}) -> void:
	var forest_asset: String = mesh.get_meta("forest_asset","")
	if prepared.is_empty() and not forest_asset.is_empty():
		prepared = prepare_tree_batch(transforms,height_m,assets.tree_render_bounds(forest_asset))
	var mm: MultiMesh
	if not prepared.is_empty() and prepared.multimeshes.has(mesh):
		# Middle and shadow instances use the same immutable geometry/placement.
		# Their material overrides, LOD uniforms and visibility stay per instance.
		mm = prepared.multimeshes[mesh]
	else:
		mm = MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mesh
		mm.instance_count = transforms.size() if prepared.is_empty() else prepared.buffer.size()/12
		if prepared.is_empty():
			for i in range(transforms.size()): mm.set_instance_transform(i,transforms[i])
		else:
			# Set the precomputed bound before uploading so the renderer does not
			# transform every mesh bound again while building its own AABB.
			mm.custom_aabb = prepared.bounds
			mm.buffer = prepared.buffer
			prepared.multimeshes[mesh] = mm
	var instance = MultiMeshInstance3D.new()
	instance.multimesh = mm
	# Only fixed rocks contribute. Wind-driven trees and camera-facing cards
	# receive GI without leaving stale geometry in the distance field.
	instance.gi_mode = GeometryInstance3D.GI_MODE_STATIC if lod==3 else GeometryInstance3D.GI_MODE_DISABLED
	# Far cards turn in their shader; include their rotated width in culling bounds.
	instance.extra_cull_margin = 10.0 if lod==2 else .2
	instance.set_meta("art_lod",lod)
	var material = mesh.surface_get_material(0)
	var pc_tree = (lod<3 or lod==5) and material is ShaderMaterial and "pc_" in material.shader.resource_path
	instance.set_meta("pc_tree",pc_tree)
	instance.set_meta("forest_tree",pc_tree and ("pc_forest_tree" in material.shader.resource_path or material.resource_name.begins_with("FC_Impostor")))
	if lod==5 and instance.get_meta("forest_tree"):
		# The stable shadow proxy needs only geometry and distance coverage;
		# it does not evaluate needle lighting or interactive branch rotations.
		if not forest_shadow_material:
			forest_shadow_material=ShaderMaterial.new()
			forest_shadow_material.shader=preload("res://assets/graphics/pc_forest_shadow.gdshader")
		instance.material_override=forest_shadow_material
	if pc_tree:
		# One identical conservative AABB for all three LODs gives the engine
		# and shader exactly the same centre, including the tilted slope.
		var bounds: AABB
		if not prepared.is_empty(): bounds = prepared.bounds
		else:
			bounds = AABB(transforms[0].origin,Vector3.ZERO)
			for transform_value in transforms: bounds = bounds.expand(transform_value.origin)
			bounds.position -= Vector3(10,.5,10)
			bounds.size += Vector3(20,height_m,20)
		instance.custom_aabb = bounds
		instance.extra_cull_margin = 0.0
		instance.set_instance_shader_parameter("pc_lod_center",bounds.get_center())
		if not forest_asset.is_empty():
			var record: Dictionary = assets.tree_record(forest_asset)
			if record.has("crown_radius"):
				instance.set_instance_shader_parameter("pc_lod_individual",true)
				var c: Array = record.crown_center
				instance.set_instance_shader_parameter("pc_crown_bounds",Vector4(c[0],c[1],c[2],record.crown_radius))
	add_child(instance)
	instance.set_meta("batch_slot",batches.size())
	batches.append(instance)

func remove_batch(instance: MultiMeshInstance3D) -> void:
	# This is an unordered ownership list, not scene/render order. Avoid scanning
	# thousands of distant cards for each retiring detail/shadow instance.
	var slot: int = instance.get_meta("batch_slot")
	assert(slot>=0 and slot<batches.size() and batches[slot]==instance)
	var last: MultiMeshInstance3D = batches.back()
	batches[slot] = last
	last.set_meta("batch_slot",slot)
	batches.pop_back()
	instance.remove_meta("batch_slot")

func apply_quality(profile) -> void:
	quality = profile
	if powder_caps: profile.apply_snow_material(powder_caps.material)
	if contact_snow: contact_snow.apply_quality(profile)
	configure_batches(profile,batches)

func configure_batches(profile, instances: Array) -> void:
	for instance in instances:
		var lod: int = instance.get_meta("art_lod")
		var near_m: float = profile.tree_near_m
		var mid_m: float = profile.tree_mid_m
		var shadow_m: float = minf(160,profile.shadow_distance_m)
		if instance.get_meta("forest_tree",false):
			# Individual needle geometry matters nearby; the directional atlas
			# carries the crown silhouette after needles are smaller than a pixel.
			near_m = near_m*[25.0,40.0,55.0][profile.level]/[40.0,70.0,95.0][profile.level]
			mid_m = mid_m*[90.0,120.0,150.0][profile.level]/[135.0,220.0,280.0][profile.level]
			shadow_m = minf(shadow_m,[35.0,60.0,85.0][profile.level])
			if dense_woodlands:
				near_m = [6.0,10.0,12.0][profile.level]*profile.tree_near_m/[40.0,70.0,95.0][profile.level]
				mid_m = [34.0,48.0,64.0][profile.level]*profile.tree_mid_m/[135.0,220.0,280.0][profile.level]
				shadow_m = [20.0,26.0,32.0][profile.level]
		instance.visibility_range_begin = [0.0,near_m,mid_m,0.0,0.0,0.0][lod]
		instance.visibility_range_end = [near_m,mid_m,profile.tree_far_m,profile.tree_far_m,profile.scrub_distance_m,shadow_m][lod]
		# Small hysteresis prevents threshold flicker without alpha-blended forests.
		instance.visibility_range_begin_margin = 12.0 if lod in [1,2] else 0.0
		instance.visibility_range_end_margin = 12.0
		if instance.get_meta("powder_cap",false): instance.visibility_range_end = [90.0,150.0,220.0][profile.level]
		if instance.get_meta("pc_tree",false):
			var begin = instance.visibility_range_begin
			var end = instance.visibility_range_end
			var fade_m = 5.0 if dense_woodlands else 10.0
			instance.set_instance_shader_parameter("pc_lod_ranges",Vector4(begin,end,fade_m,float(lod)))
			# The shader owns the transition; broad culling bounds retain both
			# opaque meshes while their complementary coverage changes.
			instance.visibility_range_begin = maxf(0.0,begin-fade_m-1.0) if begin>0 else 0.0
			instance.visibility_range_end = end+fade_m+1.0
			instance.visibility_range_begin_margin = 0.0
			instance.visibility_range_end_margin = 0.0
			if instance.get_meta("density_tree",false) or instance.get_instance_shader_parameter("pc_lod_individual")==true:
				# Individual shader distance selects each tree; batch-centre culling
				# must conservatively include its horizontal extent and tree height.
				var padding=instance.custom_aabb.size.length()*.5
				instance.visibility_range_begin=0.0
				instance.visibility_range_end=end+fade_m+padding
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if lod in [0,1,3] else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if instance.get_meta("pc_tree",false):
			# One stable mid-detail shadow silhouette, independent of visible LOD.
			instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY if lod==5 else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if lod==4:
			instance.multimesh.visible_instance_count = maxi(0,roundi(instance.multimesh.instance_count*profile.scrub_density))

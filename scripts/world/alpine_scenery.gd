extends Node3D
## Art batches use the existing obstacle list verbatim. No physics bodies here.
## Cosmetic selection only: separate from course / replay generation identity.
const SCENERY_VERSION = 4
const TREE_FAMILIES = ["spruce","fir","pine","larch","birch","rowan","scots_pine","wind_pine","snag","split_snag","hollow_snag"]
const ROCK_FAMILIES = ["rock_granite","rock_slate","rock_boulder","rock_limestone","rock_gneiss","rock_split_rock","rock_outcrop"]
var assets
var quality
var batches: Array[MultiMeshInstance3D] = []
var scrub_candidates: Array[Transform3D] = []
var obstacle_count: int = 0
var family_counts: Dictionary = {}

func build(field, library, profile) -> void:
	assets = library
	quality = profile
	obstacle_count = field.obstacles.size()
	var art_rng = RandomNumberGenerator.new()
	art_rng.seed = field.seed_value+61217+SCENERY_VERSION
	var groups: Dictionary = {}
	for i in range(field.obstacles.size()):
		var ob = field.obstacles[i]
		var family = _family(ob,art_rng)
		if field.has_method("stand_density") and field.sector_weight(ob.position.x,ob.position.z)>0:
			# Small coherent palettes keep dense stands legible and batched. The
			# legacy random stream still advances once per obstacle above.
			var region = floori(ob.position.x/256)+floori(ob.position.z/256)*3
			var mixed = 1 if posmod(hash(Vector2(ob.position.x,ob.position.z)),5)==0 else 0
			family = ["spruce","fir","pine"][posmod(region+mixed,3)] if ob.tree else ["rock_slate","rock_outcrop"][posmod(region,2)]
		var cell = 128.0
		# One derivative per family per region keeps the enlarged library batched.
		# Neighbouring regions expose all four crown / stone shapes over a descent.
		var variant_count = 3 if family=="spruce" else (2 if family=="rock_boulder" else 4)
		var variant = 1+posmod(hash("%s_%d_%d_%d" % [family,floori(ob.position.x/cell),floori(ob.position.z/cell),field.seed_value]),variant_count)
		var asset_id = "%s_%d" % [family,variant]
		if ob.tree and family in ["spruce","fir","pine"]:
			asset_id = "pc_%s_%d" % [family,1+(variant-1)%3]
		elif not ob.tree:
			var kind = "buttress" if family in ["rock_outcrop","rock_split_rock"] else ("ledge" if family in ["rock_slate","rock_gneiss","rock_limestone"] else "boulder")
			asset_id = "pc_rock_%s_%d" % [kind,1+(variant-1)%2]
		family_counts[family] = family_counts.get(family,0)+1
		var key = "%d_%d_%s" % [floori(ob.position.x/cell),floori(ob.position.z/cell),asset_id]
		if not groups.has(key):
			groups[key] = {"tree":ob.tree,"asset":asset_id,"transforms":[]}
		# Existing 0.65–1.65 tree / 0.8–3.3 rock scales provide young-to-mature
		# sizes without changing the physical obstacle's radius or height.
		var transform_value = Transform3D(Basis(Vector3.UP,ob.yaw).scaled(Vector3.ONE*ob.scale),ob.position)
		groups[key].transforms.append(transform_value)
	for group in groups.values():
		if group.tree:
			for lod in range(3):
				_batch(assets.mesh("%s_lod%d" % [group.asset,lod]),group.transforms,lod)
			if group.asset.begins_with("pc_"):
				_batch(assets.mesh("%s_lod1" % group.asset),group.transforms,5)
		else:
			_batch(assets.mesh(group.asset),group.transforms,3)
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

func _batch(mesh: Mesh, transforms: Array, lod: int) -> void:
	var mm = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = transforms.size()
	for i in range(transforms.size()): mm.set_instance_transform(i,transforms[i])
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
	if pc_tree:
		# One identical conservative AABB for all three LODs gives the engine
		# and shader exactly the same centre, including the tilted slope.
		var bounds = AABB(transforms[0].origin,Vector3.ZERO)
		for transform_value in transforms: bounds = bounds.expand(transform_value.origin)
		bounds.position -= Vector3(10,.5,10)
		bounds.size += Vector3(20,19,20)
		instance.custom_aabb = bounds
		instance.extra_cull_margin = 0.0
		instance.set_instance_shader_parameter("pc_lod_center",bounds.get_center())
	add_child(instance)
	batches.append(instance)

func apply_quality(profile) -> void:
	quality = profile
	for instance in batches:
		var lod: int = instance.get_meta("art_lod")
		instance.visibility_range_begin = [0.0,profile.tree_near_m,profile.tree_mid_m,0.0,0.0,0.0][lod]
		instance.visibility_range_end = [profile.tree_near_m,profile.tree_mid_m,profile.tree_far_m,profile.tree_far_m,profile.scrub_distance_m,minf(160,profile.shadow_distance_m)][lod]
		# Small hysteresis prevents threshold flicker without alpha-blended forests.
		instance.visibility_range_begin_margin = 12.0 if lod in [1,2] else 0.0
		instance.visibility_range_end_margin = 12.0
		if instance.get_meta("pc_tree",false):
			var begin = instance.visibility_range_begin
			var end = instance.visibility_range_end
			instance.set_instance_shader_parameter("pc_lod_ranges",Vector4(begin,end,10.0,float(lod)))
			# The shader owns the transition; broad culling bounds retain both
			# opaque meshes while their complementary coverage changes.
			instance.visibility_range_begin = maxf(0.0,begin-11.0) if begin>0 else 0.0
			instance.visibility_range_end = end+11.0
			instance.visibility_range_begin_margin = 0.0
			instance.visibility_range_end_margin = 0.0
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if lod in [0,1,3] else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if instance.get_meta("pc_tree",false):
			# One stable mid-detail shadow silhouette, independent of visible LOD.
			instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY if lod==5 else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if lod==4:
			instance.multimesh.visible_instance_count = maxi(0,roundi(instance.multimesh.instance_count*profile.scrub_density))

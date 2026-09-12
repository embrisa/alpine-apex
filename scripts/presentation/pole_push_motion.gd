extends Resource
## Editable Blender control-action export, SI/model axes. No root-motion channel.
@export var source = "art_source/animation/pole_push_v1/cycle.json"
@export var phases = PackedFloat32Array()
@export var hips_degrees = PackedFloat32Array()
@export var spine_degrees = PackedFloat32Array()
@export var wrists = PackedVector3Array() # lateral distance, shoulder-relative Y/Z
@export var trails = PackedVector3Array() # shaft direction, mirrored in X

func sample(at: float) -> Dictionary:
	assert(phases.size()>=2 and wrists.size()==phases.size() and trails.size()==phases.size())
	at = fposmod(at,1.0)
	var end = 1
	while end<phases.size()-1 and at>phases[end]: end += 1
	var weight = smoothstep(phases[end-1],phases[end],at)
	return {"hips":lerpf(hips_degrees[end-1],hips_degrees[end],weight),
		"spine":lerpf(spine_degrees[end-1],spine_degrees[end],weight),
		"wrist":wrists[end-1].lerp(wrists[end],weight),
		"trail":trails[end-1].lerp(trails[end],weight).normalized()}

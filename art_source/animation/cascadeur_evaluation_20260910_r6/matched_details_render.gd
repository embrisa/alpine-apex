extends "res://tests/pose_reference_render.gd"
## Reuse maintained rendering, restoring the baseline's exact detail cameras.
var baseline_cameras={}
func position_cameras(row:Dictionary,normal:Vector3,name:String):
	assert(details)
	if baseline_cameras.is_empty():
		var base="cascadeur-20260910-r5" if folder.ends_with("-source") else "cascadeur-20260910-r6-production"
		baseline_cameras=read("res://artifacts/pose_review/revisions/"+base+"/details.json").scenarios
	for record in baseline_cameras[name]:
		if int(record.frame)!=int(row.frame):continue
		for i in cameras.size():
			var data=record.cameras[i]
			cameras[i].global_transform=unpack_t(data.transform)
			cameras[i].size=data.size
		return
	assert(false,"Missing matched baseline detail camera")

extends MeshInstance3D
## Read-only receipt on the actual native equipment MeshInstance3D. With engine
## physics interpolation disabled, VisualInstance3D submits its global transform
## on this same notification. Reading global_transform at frame_pre_draw alone
## cannot establish that the RenderingServer received a late change.
var submitted_transform = Transform3D.IDENTITY
var submitted_process_frame = -1
var submission_count = 0

func _notification(what: int) -> void:
	if what==NOTIFICATION_TRANSFORM_CHANGED and is_visible_in_tree():
		submitted_transform = global_transform
		submitted_process_frame = Engine.get_process_frames()
		submission_count += 1

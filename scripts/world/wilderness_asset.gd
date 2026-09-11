extends Resource
## One authored background, with pre-seated batches for all quality presets.
@export var asset_id: String = "alpine_valleys_01"
@export var presentation_version: int = 3
@export var metadata: Dictionary = {}
@export var levels: Array[Dictionary] = []
@export var apron_heights: PackedFloat32Array
@export var apron_reference: PackedFloat32Array
@export var apron_normals: PackedVector3Array
@export var apron_masks: PackedColorArray
@export var apron_blends: PackedFloat32Array

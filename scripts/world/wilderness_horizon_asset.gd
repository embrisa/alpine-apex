extends Resource
## Optional, light-independent companion to one immutable background geometry tier.
const VERSION = 1
const EXTENT_M = 36000.0
const EXCLUDED_RADIUS_M = 3900.0
const FULL_RADIUS_M = 4300.0
@export var payload_version: int = VERSION
@export var source_asset_id: String
@export var source_version: int
@export var footprint_revision: int
@export var geometry_tier: int
@export var quality: int
@export var directions: int
@export var size: int
@export var extent_m: float = EXTENT_M
@export var excluded_radius_m: float = EXCLUDED_RADIUS_M
@export var full_radius_m: float = FULL_RADIUS_M
@export var layers: Array[Image] = []
@export var provenance: Dictionary

func valid_for(source, tier: int, requested_quality: int) -> bool:
	if payload_version!=VERSION or source_asset_id!=source.asset_id or source_version!=source.presentation_version: return false
	if footprint_revision!=source.metadata.get("footprint_revision") or geometry_tier!=tier or quality!=requested_quality: return false
	if quality not in [1,2] or size!=[0,128,256][quality] or directions!=[0,16,32][quality]: return false
	if extent_m!=EXTENT_M or excluded_radius_m!=EXCLUDED_RADIUS_M or full_radius_m!=FULL_RADIUS_M: return false
	if layers.size()!=directions/4: return false
	for image in layers:
		if image==null or image.get_width()!=size or image.get_height()!=size or image.get_format()!=Image.FORMAT_RGBAH or image.has_mipmaps(): return false
		if image.get_data_size()!=size*size*8: return false
	return true

func payload_bytes() -> int: return size*size*directions*2

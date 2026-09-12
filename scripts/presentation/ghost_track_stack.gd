extends RefCounted
## One GPU consumer composes player history and independent ghost rings. Ghost
## live sections occupy two retained slots each; player live sections stay last.
const GHOST_CAPACITY = 320
const MAX_GHOSTS = 10
const MAX_EXTRA_STROKES = MAX_GHOSTS*(GHOST_CAPACITY+2)
var player
var ghosts: Array = []
var generation = 0
var capacity: int:
	get: return player.capacity+ghosts.size()*(GHOST_CAPACITY+2)
var revision: int:
	get:
		var result: int = generation+player.revision
		for history in ghosts: result += history.revision
		return result
var material: ShaderMaterial:
	get: return player.material
var foot_history:
	get: return player.foot_history

func set_histories(value: Array) -> void:
	ghosts = value
	generation += 1000000
	player.gpu_full_upload = true
	for history in ghosts: history.gpu_full_upload = true

func live_gpu_strokes() -> PackedFloat32Array:
	return player.live_gpu_strokes()

func surface_materials() -> Array:
	var result: Array = [player.material]
	for history in ghosts: result.append(history.material)
	return result

func take_gpu_updates(force_full: bool = false) -> Array:
	var updates: Array = player.take_gpu_updates(force_full)
	var offset: int = player.capacity*32
	for history in ghosts:
		for update in history.take_gpu_updates(force_full):
			updates.append({"offset":offset+update.offset,"bytes":update.bytes})
		updates.append({"offset":offset+GHOST_CAPACITY*32,"bytes":history.live_gpu_strokes().to_byte_array()})
		offset += (GHOST_CAPACITY+2)*32
	return updates

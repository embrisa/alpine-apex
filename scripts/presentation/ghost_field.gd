extends Node3D
## Snapshot the session-selected roster at attempt start. No PB comparison state.
const Ghost = preload("res://scripts/presentation/personal_best_ghost.gd")
const Palette = preload("res://scripts/presentation/ghost_palette.gd")
const Stack = preload("res://scripts/presentation/ghost_track_stack.gd")
var ghosts: Array = []
var enabled = true
var track_stack = Stack.new()
var colors: Dictionary = {}
var attempt = -1
var roster: Array = []
var source_assets
var player_history
var field
var profile
var player_visual
var player_tint = Color(-1,-1,-1)
var atlas_color = Color.WHITE
var powder_surface
var tracks_enabled = true # focused comparison harness; not a player preference

func bind(assets, history, surface, quality, rider, powder = null) -> void:
	source_assets = assets; player_history = history; field = surface; profile = quality; player_visual = rider
	powder_surface = powder
	track_stack.player = history
	atlas_color = _atlas_color(rider)

func refresh_colors(runs: Array) -> void:
	var tint: Color = player_visual.appearance.values.Clothing.tint
	var next: Color = tint*atlas_color
	var identities: Array = []
	for row in runs: identities.append(row.id)
	if next==player_tint and identities==roster: return
	player_tint = next; roster = identities
	colors = Palette.assignment(runs,next)
	for ghost in ghosts: ghost.color = colors.get(ghost.run_id,ghost.color)

func sync_attempt(session) -> void:
	refresh_colors(session.ghost_runs)
	if attempt==session.attempt_id: return
	clear()
	attempt = session.attempt_id
	var histories: Array = []
	for row in session.reference_ghosts:
		var ghost = Ghost.new()
		ghost.run_id = row.id; ghost.replay = row.replay
		ghost.color = colors.get(row.id,Color("24c5c5"))
		ghost.source_assets = source_assets; ghost.player_history = player_history
		ghost.profile = profile; ghost.field = field
		add_child(ghost); ghosts.append(ghost); histories.append(ghost.snow_tracks)
	track_stack.set_histories(histories)
	if powder_surface:
		for history in histories: powder_surface.register_receiver(history.material)

func clear() -> void:
	for ghost in ghosts:
		if powder_surface: powder_surface.receivers.erase(ghost.snow_tracks.material)
		remove_child(ghost); ghost.queue_free()
	ghosts.clear()
	if track_stack.player: track_stack.set_histories([])

func update_ghosts(session, time: float, position_value: Vector3, show_in_world: bool, paused: bool) -> void:
	sync_attempt(session)
	visible = enabled and show_in_world
	for ghost in ghosts:
		ghost.enabled = enabled
		ghost.update_ghost(time,position_value,show_in_world,paused,tracks_enabled)
		ghost.snow_tracks.visible = enabled and show_in_world and tracks_enabled

func set_enabled(value: bool) -> void:
	if enabled==value: return
	enabled = value
	visible = value
	for ghost in ghosts: ghost.reset_history()

func apply_quality(value) -> void:
	profile = value
	for ghost in ghosts: ghost.apply_quality(value)
	track_stack.generation += 1000000

static func _atlas_color(rider) -> Color:
	var texture = rider.material_probe().get_shader_parameter("albedo_texture")
	if not texture is Texture2D: return Color.WHITE
	var image: Image = texture.get_image()
	if image==null or image.is_empty(): return Color.WHITE
	if image.is_compressed() and image.decompress()!=OK: return Color.WHITE
	image.resize(16,16,Image.INTERPOLATE_BILINEAR)
	var total = Vector3.ZERO
	for y in 16:
		for x in 16:
			var c = image.get_pixel(x,y)
			total += Vector3(c.r,c.g,c.b)
	total /= 256.0
	return Color(total.x,total.y,total.z)

extends RefCounted
## Shared named wind asset. Each caller owns its playback and private loop settings.
const FOREST_01 = "res://assets/audio/ambience/wind/wind_forest_01.ogg"
const FOREST_01_LOOP_OFFSET = 0.25
# The supplied recording has a much wider crest factor than the old noise loop.
# Its runtime copy is peak-levelled; this trim keeps loading ambience quiet.
const LOADING_VOLUME_DB = -12.0

static func forest_loop() -> AudioStreamOggVorbis:
	var source = load(FOREST_01) as AudioStreamOggVorbis
	if not source: return null
	var stream = source.duplicate() as AudioStreamOggVorbis
	stream.loop = true
	stream.loop_offset = FOREST_01_LOOP_OFFSET
	return stream

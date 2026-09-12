extends RefCounted
## Authored visibility rules. Independent of solver and presentation quality.
const VERSION = 1
const PRESETS = ["clear","cloudy","snowfall","rain","snowstorm","thunderstorm"]
const ORDINARY = ["clear","cloudy","snowfall","rain"]
const TIMES = {"dawn":6.5,"day":12.0,"dusk":17.5,"night":0.0}
const STORM_DELAY = 1200.0

static func time_band(hour: float) -> String:
	if hour>=5.0 and hour<8.0: return "dawn"
	if hour>=8.0 and hour<16.0: return "day"
	if hour>=16.0 and hour<19.0: return "dusk"
	return "night"

static func label(preset: String, time: String) -> String:
	return "%s · %s" % [preset.capitalize(),time.capitalize()]

static func seed_for(identity: String) -> int:
	return identity.sha256_text().substr(0,15).hex_to_int()

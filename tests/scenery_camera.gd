extends RefCounted
## Explicit diagnostic framing; never writes the player's camera preferences.
static func configure(settings) -> void:
	settings.update_profile("chase",{"rest_tilt":-12.0,"fast_tilt":-12.0,"rest_fov":68.0,"fast_fov":68.0,
		"rest_distance":5.0,"fast_distance":5.0,"rest_height":3.0,"fast_height":3.0,"slope_follow":0.0})

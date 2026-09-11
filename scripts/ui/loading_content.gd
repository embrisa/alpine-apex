extends RefCounted
## Production-derived copy and bindings; provenance is in docs/LOADING_CONTENT.md.
const COUNT = 7

static func tip(index: int, device: String = "keyboard") -> String:
	var keyboard = device not in ["playstation","xbox","gamepad"]
	match posmod(index,COUNT):
		0:
			var hop = "Space" if keyboard else ("R2" if device == "playstation" else ("RT" if device == "xbox" else "the right trigger"))
			return "Release %s to hop while supported. Holding it longer does not increase jump power." % hop
		1:
			var brake = "S or Down Arrow" if keyboard else ("L2" if device == "playstation" else ("LT" if device == "xbox" else "the left trigger"))
			return "Hold %s to brake." % brake
		2:
			return "Hold W or Up Arrow to tuck. Sustained steering opens your stance." if keyboard else "Push the left stick forward to tuck. Sustained steering opens your stance."
		3:
			return "In the air, I / K controls forward / backward flips." if keyboard else "In the air, center the left stick, then push forward or back to flip."
		4:
			return "Tucking reduces air drag. Gravity supplies your downhill acceleration."
		5:
			return "Airborne rotation changes your landing orientation, not your flight path."
		_:
			return "Press C to change riding camera." if keyboard else ("Press R1 to change riding camera." if device == "playstation" else ("Press RB to change riding camera." if device == "xbox" else "Press the right shoulder button to change riding camera."))

extends RefCounted
## Production-derived copy and bindings; provenance is in docs/ASSETS.md.
const COUNT = 7
const Prompts = preload("res://scripts/ui/controller_prompts.gd")

static func tip(index: int, device: String = "keyboard") -> String:
	var keyboard = device not in ["playstation","xbox","gamepad"]
	match posmod(index,COUNT):
		0:
			var hop = Prompts.binding("jump","keyboard" if keyboard else device)
			return "Release %s to hop while supported. Holding it longer does not increase jump power." % hop
		1:
			var brake = Prompts.binding("brake","keyboard" if keyboard else device)
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
			return "Press %s to change riding camera." % Prompts.binding("camera_mode","keyboard" if keyboard else device)

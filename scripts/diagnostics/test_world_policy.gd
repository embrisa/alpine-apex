extends RefCounted
## Applies only to automated processes; ordinary game startup remains unchanged.
static func automated() -> bool:
	return not OS.get_environment("ALPINE_VALIDATION_ROOT").is_empty() or "--script" in OS.get_cmdline_args() or "-s" in OS.get_cmdline_args()

static func full_mountain_allowed() -> bool:
	return not automated() or (OS.get_environment("ALPINE_FULL_MOUNTAIN")=="1" and not OS.get_environment("ALPINE_FULL_MOUNTAIN_REASON").strip_edges().is_empty())

static func require_full(operation: String) -> bool:
	if full_mountain_allowed(): return true
	push_error("TEST_MAP_POLICY: %s requires -FullMountain and -FullMountainReason on the validation wrapper. Select a targeted fixture for local checks." % operation)
	return false

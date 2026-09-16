extends RefCounted
## Test-only wall times. These are diagnostic stages, never rendered FPS.
var suite: String
var stage: String = ""
var started: int = 0
var rows: Array[Dictionary] = []

func _init(suite_name: String) -> void:
	suite = suite_name

func mark(next_stage: String) -> void:
	if not stage.is_empty():
		var row := {"suite":suite,"stage":stage,"milliseconds":(Time.get_ticks_usec()-started)/1000.0}
		rows.append(row)
		print("TEST_STAGE ",JSON.stringify(row))
	stage = next_stage
	started = Time.get_ticks_usec()
	if not stage.is_empty(): print("TEST_STAGE_START ",suite," ",stage)

func finish() -> void:
	mark("")
	var directory := OS.get_environment("ALPINE_TEST_TIMINGS_DIRECTORY")
	if directory.is_empty(): directory = "res://artifacts/validation_timings"
	DirAccess.make_dir_recursive_absolute(directory)
	var file := preload("res://tests/test_report.gd").open_write(directory.path_join(suite+".timings.json"))
	if file == null:
		push_error("Cannot write test timings: "+directory)
		return
	file.store_string(JSON.stringify(rows,"\t"))

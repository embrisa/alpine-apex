extends RefCounted
## One explicitly retained historical stimulus for a current defect regression.
## Production replay compatibility is never relaxed by this test-only loader.
const Inputs = preload("res://tests/performance_input.gd")
const PATH = "res://tests/fixtures/steering_jank_001.json"

static func load_inputs(field) -> Dictionary:
	var data = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	assert(data.regression_fixture=="steering_jank_001" and int(data.identity.model)==32)
	assert(int(data.identity.generator)==field.GENERATOR_VERSION and data.identity.height==field.height_checksum and data.identity.obstacles==field.obstacle_checksum,"Regression terrain changed; replace the explicitly retained fixture")
	assert(Inputs.expand(data).is_empty() and data.input_fields==Inputs.FIELDS and int(data.command_ticks)==1)
	assert(data.commands.size()==1104 and int(data.result.ticks)==1104)
	for command in data.commands: assert(Inputs.valid(command))
	return data

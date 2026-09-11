extends "res://tests/wilderness_benchmark.gd"
## See the shared ABBA harness. Select the explicitly frozen v2 baseline.
func comparison_fixture():
	return preload("res://tests/offmap_v2_fixture.gd").new()

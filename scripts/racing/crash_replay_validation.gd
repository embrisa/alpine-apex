extends RefCounted
## Cross-check inactive tick masks against closed recovery intervals. Shape-only
## validation cannot detect a valid-looking time shift or a disguised riding tick.
const DT = 1.0/120.0
# Tick-grid arithmetic accumulates rounding; stored boundary identity never uses this tolerance.
const EPSILON = .000001

static func valid(replay, intervals: Array, best: float) -> bool:
	var prior_end = -1.0
	for interval in intervals:
		var start: float = interval[0]
		var end: float = interval[1]
		if start<0.0 or start<prior_end or end<start or end>best: return false
		if absf(start-roundf(start/DT)*DT)>EPSILON or absf(end-roundf(end/DT)*DT)>EPSILON: return false
		if not _has_time(replay.sample_times,start) or not _has_time(replay.sample_times,end): return false
		if not _has_time(replay.pose_times,start) or not _has_time(replay.pose_times,end): return false
		prior_end = end
	var interval_index = 0
	for tick in replay.tick_kinds.size():
		var start = tick*DT
		while interval_index<intervals.size() and intervals[interval_index][1]<=start+EPSILON:
			interval_index += 1
		var inactive: bool = interval_index<intervals.size() and start>=intervals[interval_index][0]-EPSILON and start<intervals[interval_index][1]-EPSILON
		if replay.tick_kinds[tick]!=(1 if inactive else 0): return false
		if inactive:
			for field in replay.INPUT_WIDTH:
				if replay.inputs[tick*replay.INPUT_WIDTH+field]!=0.0: return false
	return true

static func _has_time(times: PackedFloat64Array, time: float) -> bool:
	var low = 0
	var high = times.size()-1
	while low<=high:
		var middle = (low+high)/2
		if times[middle]==time: return true
		if times[middle]<time: low = middle+1
		else: high = middle-1
	return false

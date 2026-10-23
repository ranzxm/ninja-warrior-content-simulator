class_name RunSession
extends RefCounted

## Authoritative competition state machine, ordered route validator, and timer for M1a.

signal state_changed(new_state: RunState, state_name: String)
signal time_updated(elapsed_sec: float, remaining_sec: float)
signal run_started(run_id: String)
signal run_completed(
	run_id: String,
	final_state: RunState,
	elapsed_sec: float,
	reason: String,
	last_obstacle_id: String
)
signal obstacle_updated(
	obstacle_id: String,
	obstacle_name: String,
	status_text: String,
	completed_count: int,
	total: int
)

enum RunState {
	READY,
	RUNNING,
	FINISHED,
	FAILED,
	TIMEOUT,
}

const STATE_NAMES: Dictionary = {
	RunState.READY: "READY",
	RunState.RUNNING: "RUNNING",
	RunState.FINISHED: "FINISHED",
	RunState.FAILED: "FAILED",
	RunState.TIMEOUT: "TIMEOUT",
}

static var _monotonic_counter: int = 0

var run_id: String = ""
var state: RunState = RunState.READY
var elapsed_sec: float = 0.0
var time_limit_sec: float = 120.0
var failure_reason: String = ""

var current_obstacle_id: String = ""
var current_obstacle_name: String = ""
var current_obstacle_status: String = "READY"
var last_entered_obstacle_id: String = ""
var last_completed_obstacle_id: String = ""
var last_obstacle_id: String = ""
var last_obstacle_name: String = ""
var current_obstacle_index: int = 0
var total_obstacles: int = 0

var required_obstacle_ids: Array[String] = []
var completed_obstacle_ids: Array[String] = []

var _obstacle_states: Dictionary = {}
var _obstacle_enabled: Dictionary = {}


func _init(initial_time_limit_sec: float = 120.0, obstacle_count: int = 6) -> void:
	time_limit_sec = maxf(1.0, initial_time_limit_sec)
	total_obstacles = maxi(0, obstacle_count)
	reset_to_ready()


func configure_route(obstacle_ids: Array[String], enabled_map: Dictionary = {}) -> void:
	required_obstacle_ids.clear()
	_obstacle_states.clear()
	_obstacle_enabled.clear()

	for id_str: String in obstacle_ids:
		var clean_id: String = id_str.strip_edges()
		if not clean_id.is_empty() and not required_obstacle_ids.has(clean_id):
			required_obstacle_ids.append(clean_id)
			_obstacle_states[clean_id] = ObstacleBase.TraversalState.NOT_STARTED
			_obstacle_enabled[clean_id] = bool(enabled_map.get(clean_id, true))

	total_obstacles = required_obstacle_ids.size()


func set_obstacle_enabled(obstacle_id: String, enabled_flag: bool) -> void:
	if _obstacle_enabled.has(obstacle_id):
		_obstacle_enabled[obstacle_id] = enabled_flag


func reset_to_ready(new_time_limit_sec: float = -1.0, obstacle_count: int = -1) -> void:
	if new_time_limit_sec > 0.0:
		time_limit_sec = new_time_limit_sec
	if obstacle_count >= 0 and required_obstacle_ids.is_empty():
		total_obstacles = obstacle_count
	elif not required_obstacle_ids.is_empty():
		total_obstacles = required_obstacle_ids.size()

	_monotonic_counter += 1
	run_id = "run_%d_%04d" % [int(Time.get_unix_time_from_system()), _monotonic_counter]
	state = RunState.READY
	elapsed_sec = 0.0
	failure_reason = ""
	current_obstacle_id = ""
	current_obstacle_name = "Ready at Start"
	current_obstacle_status = "READY"
	last_entered_obstacle_id = ""
	last_completed_obstacle_id = ""
	last_obstacle_id = ""
	last_obstacle_name = ""
	current_obstacle_index = 0
	completed_obstacle_ids.clear()

	for req_id: String in required_obstacle_ids:
		_obstacle_states[req_id] = ObstacleBase.TraversalState.NOT_STARTED

	state_changed.emit(state, get_state_name())
	time_updated.emit(elapsed_sec, get_remaining_sec())
	obstacle_updated.emit("", current_obstacle_name, current_obstacle_status, 0, total_obstacles)


func start_run() -> bool:
	if state != RunState.READY:
		return false
	state = RunState.RUNNING
	elapsed_sec = 0.0
	failure_reason = ""
	state_changed.emit(state, get_state_name())
	run_started.emit(run_id)
	time_updated.emit(elapsed_sec, get_remaining_sec())
	return true


func tick(delta: float, is_paused: bool = false) -> void:
	if state != RunState.RUNNING or is_paused or delta <= 0.0:
		return

	elapsed_sec += delta
	if elapsed_sec >= time_limit_sec:
		elapsed_sec = time_limit_sec
		time_updated.emit(elapsed_sec, 0.0)
		trigger_timeout()
	else:
		time_updated.emit(elapsed_sec, get_remaining_sec())


func record_obstacle_entered(obstacle_id: String, display_name: String, is_obs_enabled: bool = true) -> bool:
	if state != RunState.RUNNING or not is_obs_enabled:
		return false
	var clean_id: String = obstacle_id.strip_edges()
	if clean_id.is_empty():
		return false
	if _obstacle_enabled.has(clean_id) and not bool(_obstacle_enabled[clean_id]):
		return false

	if not required_obstacle_ids.is_empty():
		var expected_idx: int = completed_obstacle_ids.size()
		if expected_idx >= required_obstacle_ids.size():
			return false
		if required_obstacle_ids[expected_idx] != clean_id:
			return false
		var cur_state: int = int(_obstacle_states.get(clean_id, ObstacleBase.TraversalState.NOT_STARTED))
		if cur_state != ObstacleBase.TraversalState.NOT_STARTED:
			return false
	else:
		if int(_obstacle_states.get(clean_id, ObstacleBase.TraversalState.NOT_STARTED)) != ObstacleBase.TraversalState.NOT_STARTED:
			return false

	_obstacle_states[clean_id] = ObstacleBase.TraversalState.ENTERED
	current_obstacle_id = clean_id
	current_obstacle_name = display_name
	current_obstacle_status = "IN PROGRESS"
	last_entered_obstacle_id = clean_id
	last_obstacle_id = clean_id
	last_obstacle_name = display_name
	current_obstacle_index = completed_obstacle_ids.size()

	obstacle_updated.emit(
		current_obstacle_id,
		current_obstacle_name,
		current_obstacle_status,
		get_completed_count(),
		total_obstacles
	)
	return true


func record_obstacle_completed(obstacle_id: String, display_name: String, is_obs_enabled: bool = true) -> bool:
	if state != RunState.RUNNING or not is_obs_enabled:
		return false
	var clean_id: String = obstacle_id.strip_edges()
	if clean_id.is_empty():
		return false
	if _obstacle_enabled.has(clean_id) and not bool(_obstacle_enabled[clean_id]):
		return false

	var cur_state: int = int(_obstacle_states.get(clean_id, ObstacleBase.TraversalState.NOT_STARTED))
	if cur_state != ObstacleBase.TraversalState.ENTERED:
		return false

	if not required_obstacle_ids.is_empty():
		var expected_idx: int = completed_obstacle_ids.size()
		if expected_idx >= required_obstacle_ids.size() or required_obstacle_ids[expected_idx] != clean_id:
			return false

	_obstacle_states[clean_id] = ObstacleBase.TraversalState.COMPLETED
	if not completed_obstacle_ids.has(clean_id):
		completed_obstacle_ids.append(clean_id)

	current_obstacle_id = clean_id
	current_obstacle_name = display_name
	current_obstacle_status = "CLEARED"
	last_completed_obstacle_id = clean_id
	last_obstacle_id = clean_id
	last_obstacle_name = display_name
	current_obstacle_index = completed_obstacle_ids.size()

	obstacle_updated.emit(
		current_obstacle_id,
		current_obstacle_name,
		current_obstacle_status,
		get_completed_count(),
		total_obstacles
	)
	return true


func can_finish_run() -> bool:
	if state != RunState.RUNNING:
		return false
	for req_id: String in required_obstacle_ids:
		if not bool(_obstacle_enabled.get(req_id, true)):
			return false
		var st: int = int(_obstacle_states.get(req_id, ObstacleBase.TraversalState.NOT_STARTED))
		if st != ObstacleBase.TraversalState.COMPLETED:
			return false
	if completed_obstacle_ids.size() != required_obstacle_ids.size():
		return false
	return true


func finish_run() -> bool:
	if not can_finish_run():
		return false
	state = RunState.FINISHED
	failure_reason = ""
	state_changed.emit(state, get_state_name())
	run_completed.emit(run_id, state, elapsed_sec, "STAGE CLEAR", last_obstacle_id)
	return true


func fail_run(reason: String = "Out of Bounds", obstacle_id: String = "") -> bool:
	if state != RunState.RUNNING:
		return false
	failure_reason = reason.strip_edges() if not reason.strip_edges().is_empty() else "Course Hazard"
	if not obstacle_id.strip_edges().is_empty():
		last_obstacle_id = obstacle_id.strip_edges()
	state = RunState.FAILED
	state_changed.emit(state, get_state_name())
	run_completed.emit(run_id, state, elapsed_sec, failure_reason, last_obstacle_id)
	return true


func trigger_timeout() -> bool:
	if state != RunState.RUNNING:
		return false
	elapsed_sec = time_limit_sec
	failure_reason = "Time Limit Exceeded"
	state = RunState.TIMEOUT
	state_changed.emit(state, get_state_name())
	run_completed.emit(run_id, state, elapsed_sec, failure_reason, last_obstacle_id)
	return true


func get_completed_count() -> int:
	return completed_obstacle_ids.size()


func get_obstacle_traversal_state(obstacle_id: String) -> int:
	return int(_obstacle_states.get(obstacle_id, ObstacleBase.TraversalState.NOT_STARTED))


func is_terminal() -> bool:
	return state == RunState.FINISHED or state == RunState.FAILED or state == RunState.TIMEOUT


func get_state_name() -> String:
	return String(STATE_NAMES.get(state, "READY"))


func get_remaining_sec() -> float:
	return maxf(0.0, time_limit_sec - elapsed_sec)


static func format_time_ms(seconds: float) -> String:
	var clamped: float = maxf(0.0, seconds)
	var total_ms: int = int(round(clamped * 1000.0))
	var minutes: int = total_ms / 60000
	var secs: int = (total_ms % 60000) / 1000
	var millis: int = total_ms % 1000
	return "%02d:%02d.%03d" % [minutes, secs, millis]

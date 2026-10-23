class_name RunSession
extends RefCounted

## Authoritative competition state machine and timer for M1a.
## ponytail: in-memory session state for M1a; add JSON run history persistence in M2b.

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
signal obstacle_updated(obstacle_id: String, obstacle_name: String, index: int, total: int)

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
var last_obstacle_id: String = ""
var last_obstacle_name: String = ""
var current_obstacle_index: int = 0
var total_obstacles: int = 0


func _init(initial_time_limit_sec: float = 120.0, obstacle_count: int = 6) -> void:
	time_limit_sec = maxf(1.0, initial_time_limit_sec)
	total_obstacles = maxi(0, obstacle_count)
	reset_to_ready()


func reset_to_ready(new_time_limit_sec: float = -1.0, obstacle_count: int = -1) -> void:
	if new_time_limit_sec > 0.0:
		time_limit_sec = new_time_limit_sec
	if obstacle_count >= 0:
		total_obstacles = obstacle_count

	_monotonic_counter += 1
	run_id = "run_%d_%04d" % [int(Time.get_unix_time_from_system()), _monotonic_counter]
	state = RunState.READY
	elapsed_sec = 0.0
	failure_reason = ""
	last_obstacle_id = ""
	last_obstacle_name = ""
	current_obstacle_index = 0

	state_changed.emit(state, get_state_name())
	time_updated.emit(elapsed_sec, get_remaining_sec())
	obstacle_updated.emit("", "Ready at Start", 0, total_obstacles)


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


func finish_run() -> bool:
	if state != RunState.RUNNING:
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


func record_obstacle_progress(obstacle_id: String, display_name: String, index: int) -> void:
	if state != RunState.RUNNING:
		return
	last_obstacle_id = obstacle_id
	last_obstacle_name = display_name
	current_obstacle_index = clampi(index, 0, maxi(total_obstacles, index))
	obstacle_updated.emit(last_obstacle_id, last_obstacle_name, current_obstacle_index, total_obstacles)


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

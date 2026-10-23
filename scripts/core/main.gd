class_name MainApp
extends Node3D

## Root coordinator for M1a competition lifecycle, ordered route validation, dynamic obstacle simulation,
## HUD/result synchronization, and pause/retry flow.

signal session_restarted()
signal pause_toggled(is_paused: bool)

@export var arena_path: NodePath = NodePath("Stage01Demo")
@export var player_path: NodePath = NodePath("Player")
@export var hud_path: NodePath = NodePath("UILayer/GameplayHud")
@export var pause_menu_path: NodePath = NodePath("UILayer/PauseMenu")

var run_session: RunSession = RunSession.new()
var _is_paused: bool = false

@onready var _arena: Node3D = _resolve_arena_node()
@onready var _player: PlayerController = get_node_or_null(player_path) as PlayerController
@onready var _hud: GameplayHud = get_node_or_null(hud_path) as GameplayHud
@onready var _pause_menu: PauseMenu = get_node_or_null(pause_menu_path) as PauseMenu


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_connect_session_signals()
	_connect_arena_signals()

	if _player != null:
		_player.process_mode = Node.PROCESS_MODE_PAUSABLE
		if not _player.state_changed.is_connected(_on_player_state_changed):
			_player.state_changed.connect(_on_player_state_changed)

	if _hud != null and not _hud.retry_requested.is_connected(restart_session):
		_hud.retry_requested.connect(restart_session)

	if _pause_menu != null:
		if not _pause_menu.resume_requested.is_connected(_on_resume_requested):
			_pause_menu.resume_requested.connect(_on_resume_requested)
		if not _pause_menu.restart_requested.is_connected(restart_session):
			_pause_menu.restart_requested.connect(restart_session)
		if not _pause_menu.quit_requested.is_connected(quit_application):
			_pause_menu.quit_requested.connect(quit_application)

	restart_session()


func _physics_process(delta: float) -> void:
	run_session.tick(delta, _is_paused)
	if _is_paused or run_session.is_terminal():
		return
	if _arena != null and _player != null and _arena.has_method("is_below_fail_plane"):
		if bool(_arena.call("is_below_fail_plane", _player.global_position)):
			var obs_id: String = ""
			if _arena.has_method("get_last_obstacle_id"):
				obs_id = String(_arena.call("get_last_obstacle_id"))
			_handle_player_fall("Fell below course boundary", obs_id)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		toggle_pause()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("restart"):
		restart_session()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("toggle_hud") and not _is_paused:
		if _hud != null:
			_hud.toggle_clean_feed()
		get_viewport().set_input_as_handled()


func restart_session() -> void:
	set_paused(false)
	if _hud != null:
		_hud.hide_result()

	var time_limit: float = 120.0
	var obstacle_count: int = 0
	if _arena is StageDemoArena:
		var stage_arena: StageDemoArena = _arena as StageDemoArena
		stage_arena.reset_all_obstacles()
		time_limit = stage_arena.time_limit_sec
		obstacle_count = stage_arena.get_obstacle_count()
		run_session.configure_route(
			stage_arena.get_required_obstacle_ids(),
			stage_arena.get_obstacle_enabled_map()
		)
		if _hud != null:
			_hud.set_stage_name(stage_arena.stage_name)
	elif _arena != null and _arena.has_method("reset_all_obstacles"):
		_arena.call("reset_all_obstacles")

	run_session.reset_to_ready(time_limit, obstacle_count)
	respawn_player()
	session_restarted.emit()


func respawn_player() -> void:
	if _player == null:
		return
	var spawn_xform: Transform3D = Transform3D(Basis.IDENTITY, Vector3(0.0, 0.0, 2.4))
	if _arena != null and _arena.has_method("get_spawn_transform"):
		spawn_xform = _arena.call("get_spawn_transform")
	_player.reset_to_transform(spawn_xform)
	_player.controls_enabled = not _is_paused
	var cam_rig: ThirdPersonCamera = _player.get_camera_rig()
	if cam_rig != null and not _is_paused:
		cam_rig.capture_mouse()
	if _hud != null:
		_hud.set_player_state_text(_player.get_state_name())


func toggle_pause() -> void:
	set_paused(not _is_paused)


func set_paused(paused_state: bool) -> void:
	_is_paused = paused_state
	if is_inside_tree():
		get_tree().paused = _is_paused

	if _pause_menu != null:
		_pause_menu.set_open(_is_paused)

	if _hud != null:
		_hud.set_mode_text("PAUSED" if _is_paused else "PLAY")

	if _player != null:
		_player.controls_enabled = (not _is_paused) and (not run_session.is_terminal())
		var cam_rig: ThirdPersonCamera = _player.get_camera_rig()
		if cam_rig != null:
			if _is_paused or run_session.is_terminal():
				cam_rig.release_mouse()
			else:
				cam_rig.capture_mouse()

	pause_toggled.emit(_is_paused)


func is_paused() -> bool:
	return _is_paused


func get_run_session() -> RunSession:
	return run_session


func get_player() -> PlayerController:
	return _player


func get_arena() -> Node3D:
	return _arena


func get_hud() -> GameplayHud:
	return _hud


func get_pause_menu() -> PauseMenu:
	return _pause_menu


func quit_application() -> void:
	if is_inside_tree():
		get_tree().paused = false
	if _player != null and _player.get_camera_rig() != null:
		_player.get_camera_rig().release_mouse()
	if is_inside_tree():
		get_tree().quit()


func _resolve_arena_node() -> Node3D:
	var node: Node3D = get_node_or_null(arena_path) as Node3D
	if node != null:
		return node
	return get_node_or_null("PrototypeArena") as Node3D


func _connect_session_signals() -> void:
	if not run_session.state_changed.is_connected(_on_run_state_changed):
		run_session.state_changed.connect(_on_run_state_changed)
	if not run_session.time_updated.is_connected(_on_run_time_updated):
		run_session.time_updated.connect(_on_run_time_updated)
	if not run_session.obstacle_updated.is_connected(_on_run_obstacle_updated):
		run_session.obstacle_updated.connect(_on_run_obstacle_updated)
	if not run_session.run_completed.is_connected(_on_run_completed):
		run_session.run_completed.connect(_on_run_completed)


func _connect_arena_signals() -> void:
	if _arena is StageDemoArena:
		var stage_arena: StageDemoArena = _arena as StageDemoArena
		if not stage_arena.start_gate_crossed.is_connected(_on_start_gate_crossed):
			stage_arena.start_gate_crossed.connect(_on_start_gate_crossed)
		if not stage_arena.finish_zone_reached.is_connected(_on_finish_zone_reached):
			stage_arena.finish_zone_reached.connect(_on_finish_zone_reached)
		if not stage_arena.player_fell.is_connected(_on_stage_player_fell):
			stage_arena.player_fell.connect(_on_stage_player_fell)
		if not stage_arena.obstacle_entered.is_connected(_on_stage_obstacle_entered):
			stage_arena.obstacle_entered.connect(_on_stage_obstacle_entered)
		if not stage_arena.obstacle_completed.is_connected(_on_stage_obstacle_completed):
			stage_arena.obstacle_completed.connect(_on_stage_obstacle_completed)
	elif _arena is PrototypeArena:
		var proto_arena: PrototypeArena = _arena as PrototypeArena
		if not proto_arena.player_fell.is_connected(_on_prototype_player_fell):
			proto_arena.player_fell.connect(_on_prototype_player_fell)


func _on_start_gate_crossed(_body: PlayerController) -> void:
	if run_session.state == RunSession.RunState.READY:
		run_session.start_run()


func _on_finish_zone_reached(_body: PlayerController) -> void:
	if run_session.state != RunSession.RunState.RUNNING:
		return
	if _arena is StageDemoArena:
		var stage_arena: StageDemoArena = _arena as StageDemoArena
		for obs: ObstacleBase in stage_arena.get_obstacles():
			run_session.set_obstacle_enabled(obs.obstacle_id, obs.is_enabled)
	run_session.finish_run()


func _on_stage_player_fell(_body: PlayerController, reason: String, obstacle_id: String) -> void:
	if not _is_paused:
		_handle_player_fall(reason, obstacle_id)


func _on_prototype_player_fell(_body: Node3D) -> void:
	if not _is_paused:
		_handle_player_fall("Fell into Prototype Hazard", "")


func _on_stage_obstacle_entered(obstacle: ObstacleBase, _index: int, _total: int) -> void:
	if run_session.state != RunSession.RunState.RUNNING or not obstacle.is_enabled:
		return
	run_session.set_obstacle_enabled(obstacle.obstacle_id, obstacle.is_enabled)
	if run_session.record_obstacle_entered(obstacle.obstacle_id, obstacle.display_name, obstacle.is_enabled):
		obstacle.mark_entered()


func _on_stage_obstacle_completed(obstacle: ObstacleBase, _index: int, _total: int) -> void:
	if run_session.state != RunSession.RunState.RUNNING or not obstacle.is_enabled:
		return
	run_session.set_obstacle_enabled(obstacle.obstacle_id, obstacle.is_enabled)
	if run_session.record_obstacle_completed(obstacle.obstacle_id, obstacle.display_name, obstacle.is_enabled):
		obstacle.mark_completed()


func _handle_player_fall(reason: String, obstacle_id: String) -> void:
	if run_session.is_terminal():
		return
	if run_session.state == RunSession.RunState.READY:
		# Safe recovery in READY without creating a fake RUNNING -> FAILED attempt
		respawn_player()
		return
	run_session.fail_run(reason, obstacle_id)


func _on_run_state_changed(new_state: RunSession.RunState, state_name: String) -> void:
	if _hud != null:
		_hud.set_run_state_text(state_name)
	if _arena is StageDemoArena:
		var stage_arena: StageDemoArena = _arena as StageDemoArena
		if new_state == RunSession.RunState.RUNNING:
			stage_arena.start_obstacles_simulation()
		else:
			stage_arena.stop_obstacles_simulation()


func _on_run_time_updated(elapsed_sec: float, remaining_sec: float) -> void:
	if _hud != null:
		_hud.set_timer_values(elapsed_sec, remaining_sec)


func _on_run_obstacle_updated(
	_obstacle_id: String,
	obstacle_name: String,
	status_text: String,
	completed_count: int,
	total: int
) -> void:
	if _hud != null:
		_hud.set_obstacle_progress(obstacle_name, status_text, completed_count, total)


func _on_run_completed(
	_run_id: String,
	final_state: RunSession.RunState,
	elapsed_sec: float,
	reason: String,
	last_obstacle_id: String
) -> void:
	if _arena is StageDemoArena:
		(_arena as StageDemoArena).stop_obstacles_simulation()
	if _player != null:
		_player.controls_enabled = false
		_player.velocity = Vector3.ZERO
		if _player.get_camera_rig() != null:
			_player.get_camera_rig().release_mouse()
	if _hud != null:
		_hud.show_result(
			final_state,
			elapsed_sec,
			reason,
			last_obstacle_id,
			run_session.get_completed_count(),
			run_session.total_obstacles
		)


func _on_player_state_changed(_new_state: PlayerController.LocomotionState, state_name: String) -> void:
	if _hud != null:
		_hud.set_player_state_text(state_name)


func _on_resume_requested() -> void:
	set_paused(false)

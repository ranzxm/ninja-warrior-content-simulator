class_name MainApp
extends Node3D

## Root coordinator for M1a/M1b competition lifecycle, PLAY/EDIT mode switching,
## ordered route validation, pause-aware dynamic obstacle simulation, and HUD/Editor synchronization.

signal session_restarted()
signal pause_toggled(is_paused: bool)
signal mode_changed(new_mode: AppMode, mode_name: String)

enum AppMode {
	PLAY,
	EDIT,
}

@export var arena_path: NodePath = NodePath("Stage01Demo")
@export var player_path: NodePath = NodePath("Player")
@export var editor_camera_path: NodePath = NodePath("EditorCamera")
@export var hud_path: NodePath = NodePath("UILayer/GameplayHud")
@export var editor_ui_path: NodePath = NodePath("UILayer/ArenaEditor")
@export var pause_menu_path: NodePath = NodePath("UILayer/PauseMenu")

var run_session: RunSession = RunSession.new()
var app_mode: AppMode = AppMode.PLAY
var _is_paused: bool = false
var _confirm_stop_run_dialog: ConfirmationDialog = null

@onready var _arena: Node3D = _resolve_arena_node()
@onready var _player: PlayerController = get_node_or_null(player_path) as PlayerController
@onready var _editor_camera: EditorCamera = get_node_or_null(editor_camera_path) as EditorCamera
@onready var _hud: GameplayHud = get_node_or_null(hud_path) as GameplayHud
@onready var _editor: ArenaEditor = get_node_or_null(editor_ui_path) as ArenaEditor
@onready var _pause_menu: PauseMenu = get_node_or_null(pause_menu_path) as PauseMenu


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_connect_session_signals()
	_connect_arena_signals()

	if _player != null:
		_player.process_mode = Node.PROCESS_MODE_PAUSABLE
		if not _player.state_changed.is_connected(_on_player_state_changed):
			_player.state_changed.connect(_on_player_state_changed)

	if _hud != null:
		if not _hud.retry_requested.is_connected(restart_session):
			_hud.retry_requested.connect(restart_session)
		if not _hud.edit_mode_requested.is_connected(_on_hud_edit_mode_requested):
			_hud.edit_mode_requested.connect(_on_hud_edit_mode_requested)

	if _editor != null and _arena is StageDemoArena:
		_editor.setup(_arena as StageDemoArena, _editor_camera)
		if not _editor.test_play_requested.is_connected(enter_play_mode):
			_editor.test_play_requested.connect(enter_play_mode)

	if _pause_menu != null:
		if not _pause_menu.resume_requested.is_connected(_on_resume_requested):
			_pause_menu.resume_requested.connect(_on_resume_requested)
		if not _pause_menu.restart_requested.is_connected(restart_session):
			_pause_menu.restart_requested.connect(restart_session)
		if not _pause_menu.quit_requested.is_connected(quit_application):
			_pause_menu.quit_requested.connect(quit_application)

	_ensure_confirm_stop_run_dialog()
	restart_session()


func _physics_process(delta: float) -> void:
	if app_mode != AppMode.PLAY:
		return
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
	if event.is_action_pressed("toggle_editor"):
		if app_mode == AppMode.PLAY:
			enter_edit_mode(false)
		else:
			enter_play_mode()
		get_viewport().set_input_as_handled()
		return

	if app_mode != AppMode.PLAY:
		return

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


func enter_edit_mode(force_stop_run: bool = false) -> bool:
	if app_mode == AppMode.EDIT:
		return true

	if run_session.state == RunSession.RunState.RUNNING and not force_stop_run:
		if _confirm_stop_run_dialog != null:
			_confirm_stop_run_dialog.popup_centered()
		return false

	set_paused(false)
	app_mode = AppMode.EDIT

	if _arena is StageDemoArena:
		var stage_arena: StageDemoArena = _arena as StageDemoArena
		stage_arena.stop_obstacles_simulation()
		stage_arena.reset_all_obstacles()
		stage_arena.set_editor_mode(true)
		run_session.reset_to_ready(stage_arena.time_limit_sec, stage_arena.get_obstacle_count())

	if _player != null:
		_player.controls_enabled = false
		_player.velocity = Vector3.ZERO
		_player.visible = false
		var p_cam: ThirdPersonCamera = _player.get_camera_rig()
		if p_cam != null:
			p_cam.release_mouse()
			if p_cam.get_camera() != null:
				p_cam.get_camera().current = false

	if _hud != null:
		_hud.hide_result()
		_hud.visible = false

	if _editor_camera != null:
		_editor_camera.set_active(true)

	if _editor != null:
		_editor.set_editor_active(true)

	mode_changed.emit(app_mode, "EDIT")
	return true


func enter_play_mode() -> bool:
	if app_mode == AppMode.PLAY:
		return true

	if _editor != null:
		var report: Dictionary = _editor.validate_current_arena(true)
		if not bool(report.get("valid", false)):
			return false

	var preserved_dirty: bool = _editor.is_dirty if _editor != null else false

	app_mode = AppMode.PLAY
	if _editor != null:
		_editor.set_editor_active(false)
		_editor.is_dirty = preserved_dirty

	if _editor_camera != null:
		_editor_camera.set_active(false)

	if _arena is StageDemoArena:
		(_arena as StageDemoArena).set_editor_mode(false)

	if _player != null:
		_player.visible = true
		var p_cam: ThirdPersonCamera = _player.get_camera_rig()
		if p_cam != null and p_cam.get_camera() != null:
			p_cam.get_camera().current = true

	if _hud != null:
		_hud.visible = true
		_hud.set_mode_text("PLAY")

	restart_session()
	mode_changed.emit(app_mode, "PLAY")
	return true


func restart_session() -> void:
	set_paused(false)
	if _hud != null:
		_hud.hide_result()

	var time_limit: float = 120.0
	var obstacle_count: int = 0
	if _arena is StageDemoArena:
		var stage_arena: StageDemoArena = _arena as StageDemoArena
		stage_arena.set_editor_mode(app_mode == AppMode.EDIT)
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
	_player.visible = (app_mode == AppMode.PLAY)
	_player.controls_enabled = (app_mode == AppMode.PLAY) and (not _is_paused)
	var cam_rig: ThirdPersonCamera = _player.get_camera_rig()
	if cam_rig != null and app_mode == AppMode.PLAY and not _is_paused:
		cam_rig.capture_mouse()
	if _hud != null:
		_hud.set_player_state_text(_player.get_state_name())


func toggle_pause() -> void:
	set_paused(not _is_paused)


func set_paused(paused_state: bool) -> void:
	_is_paused = paused_state
	if is_inside_tree():
		get_tree().paused = _is_paused

	if _arena is StageDemoArena:
		(_arena as StageDemoArena).set_obstacles_paused(_is_paused)

	if _pause_menu != null:
		_pause_menu.set_open(_is_paused)

	if _hud != null and app_mode == AppMode.PLAY:
		_hud.set_mode_text("PAUSED" if _is_paused else "PLAY")

	if _player != null:
		_player.controls_enabled = (app_mode == AppMode.PLAY) and (not _is_paused) and (not run_session.is_terminal())
		var cam_rig: ThirdPersonCamera = _player.get_camera_rig()
		if cam_rig != null and app_mode == AppMode.PLAY:
			if _is_paused or run_session.is_terminal():
				cam_rig.release_mouse()
			else:
				cam_rig.capture_mouse()

	pause_toggled.emit(_is_paused)


func is_paused() -> bool:
	return _is_paused


func get_app_mode() -> AppMode:
	return app_mode


func get_run_session() -> RunSession:
	return run_session


func get_player() -> PlayerController:
	return _player


func get_arena() -> Node3D:
	return _arena


func get_editor() -> ArenaEditor:
	return _editor


func get_editor_camera() -> EditorCamera:
	return _editor_camera


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


func _ensure_confirm_stop_run_dialog() -> void:
	if _confirm_stop_run_dialog != null:
		return
	var ui_layer: Node = get_node_or_null("UILayer")
	if ui_layer == null:
		return
	_confirm_stop_run_dialog = ConfirmationDialog.new()
	_confirm_stop_run_dialog.title = "Stop Active Run?"
	_confirm_stop_run_dialog.dialog_text = "A competition run is currently in progress. Stop the run and enter EDIT mode?"
	_confirm_stop_run_dialog.confirmed.connect(func() -> void: enter_edit_mode(true))
	ui_layer.add_child(_confirm_stop_run_dialog)


func _on_hud_edit_mode_requested() -> void:
	enter_edit_mode(false)


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
	if app_mode != AppMode.PLAY:
		return
	if run_session.state == RunSession.RunState.READY:
		run_session.start_run()


func _on_finish_zone_reached(_body: PlayerController) -> void:
	if app_mode != AppMode.PLAY or run_session.state != RunSession.RunState.RUNNING:
		return
	if _arena is StageDemoArena:
		var stage_arena: StageDemoArena = _arena as StageDemoArena
		for obs: ObstacleBase in stage_arena.get_obstacles():
			run_session.set_obstacle_enabled(obs.get_obstacle_instance_id(), obs.is_enabled)
	run_session.finish_run()


func _on_stage_player_fell(_body: PlayerController, reason: String, obstacle_id: String) -> void:
	if app_mode == AppMode.PLAY and not _is_paused:
		_handle_player_fall(reason, obstacle_id)


func _on_prototype_player_fell(_body: Node3D) -> void:
	if app_mode == AppMode.PLAY and not _is_paused:
		_handle_player_fall("Fell into Prototype Hazard", "")


func _on_stage_obstacle_entered(obstacle: ObstacleBase, _index: int, _total: int) -> void:
	if app_mode != AppMode.PLAY or run_session.state != RunSession.RunState.RUNNING or not obstacle.is_enabled:
		return
	var inst_id: String = obstacle.get_obstacle_instance_id()
	run_session.set_obstacle_enabled(inst_id, obstacle.is_enabled)
	if run_session.record_obstacle_entered(inst_id, obstacle.display_name, obstacle.is_enabled):
		obstacle.mark_entered()


func _on_stage_obstacle_completed(obstacle: ObstacleBase, _index: int, _total: int) -> void:
	if app_mode != AppMode.PLAY or run_session.state != RunSession.RunState.RUNNING or not obstacle.is_enabled:
		return
	var inst_id: String = obstacle.get_obstacle_instance_id()
	run_session.set_obstacle_enabled(inst_id, obstacle.is_enabled)
	if run_session.record_obstacle_completed(inst_id, obstacle.display_name, obstacle.is_enabled):
		obstacle.mark_completed()


func _handle_player_fall(reason: String, obstacle_id: String) -> void:
	if app_mode != AppMode.PLAY or run_session.is_terminal():
		return
	if run_session.state == RunSession.RunState.READY:
		respawn_player()
		return
	run_session.fail_run(reason, obstacle_id)


func _on_run_state_changed(new_state: RunSession.RunState, state_name: String) -> void:
	if _hud != null:
		_hud.set_run_state_text(state_name)
	if _arena is StageDemoArena:
		var stage_arena: StageDemoArena = _arena as StageDemoArena
		if new_state == RunSession.RunState.RUNNING and app_mode == AppMode.PLAY:
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

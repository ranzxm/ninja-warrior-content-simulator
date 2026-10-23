class_name MainApp
extends Node3D

## Root coordinator for M0 playable foundation: spawn, fall recovery, restart, pause, and HUD sync.
## ponytail: direct scene coordinator for M0; split out RunSession state machine in M1a.

signal session_restarted()
signal pause_toggled(is_paused: bool)

@export var arena_path: NodePath = NodePath("PrototypeArena")
@export var player_path: NodePath = NodePath("Player")
@export var hud_path: NodePath = NodePath("UILayer/GameplayHud")
@export var pause_menu_path: NodePath = NodePath("UILayer/PauseMenu")

var _is_paused: bool = false

@onready var _arena: PrototypeArena = get_node_or_null(arena_path) as PrototypeArena
@onready var _player: PlayerController = get_node_or_null(player_path) as PlayerController
@onready var _hud: GameplayHud = get_node_or_null(hud_path) as GameplayHud
@onready var _pause_menu: PauseMenu = get_node_or_null(pause_menu_path) as PauseMenu


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if _player_valid() and _arena != null:
		if not _arena.player_fell.is_connected(_on_player_fell):
			_arena.player_fell.connect(_on_player_fell)

	if _player != null:
		_player.process_mode = Node.PROCESS_MODE_PAUSABLE
		if not _player.state_changed.is_connected(_on_player_state_changed):
			_player.state_changed.connect(_on_player_state_changed)

	if _pause_menu != null:
		if not _pause_menu.resume_requested.is_connected(_on_resume_requested):
			_pause_menu.resume_requested.connect(_on_resume_requested)
		if not _pause_menu.restart_requested.is_connected(restart_session):
			_pause_menu.restart_requested.connect(restart_session)
		if not _pause_menu.quit_requested.is_connected(quit_application):
			_pause_menu.quit_requested.connect(quit_application)

	restart_session()


func _physics_process(_delta: float) -> void:
	if _is_paused:
		return
	if _arena != null and _player != null:
		if _arena.is_below_fail_plane(_player.global_position):
			respawn_player()


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
	respawn_player()
	session_restarted.emit()


func respawn_player() -> void:
	if _player == null:
		return
	var spawn_xform: Transform3D = Transform3D(Basis.IDENTITY, Vector3(0.0, 1.5, 10.0))
	if _arena != null:
		spawn_xform = _arena.get_spawn_transform()
	_player.reset_to_transform(spawn_xform)
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
		_player.controls_enabled = not _is_paused
		var cam_rig: ThirdPersonCamera = _player.get_camera_rig()
		if cam_rig != null:
			if _is_paused:
				cam_rig.release_mouse()
			else:
				cam_rig.capture_mouse()

	pause_toggled.emit(_is_paused)


func is_paused() -> bool:
	return _is_paused


func get_player() -> PlayerController:
	return _player


func get_arena() -> PrototypeArena:
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


func _player_valid() -> bool:
	return _player != null


func _on_player_fell(_body: Node3D) -> void:
	if not _is_paused:
		respawn_player()


func _on_player_state_changed(_new_state: PlayerController.LocomotionState, state_name: String) -> void:
	if _hud != null:
		_hud.set_player_state_text(state_name)


func _on_resume_requested() -> void:
	set_paused(false)

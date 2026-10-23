extends SceneTree

## Headless smoke test for Milestone M0 (Playable Foundation).
## Run with: godot --headless --path . -s res://tests/smoke_test_m0.gd

var _failures: Array[String] = []


func _initialize() -> void:
	var main_packed: PackedScene = load("res://scenes/app/main.tscn") as PackedScene
	_assert_true(main_packed != null, "main.tscn must load as PackedScene")
	if main_packed == null:
		_finish()
		return

	var main_node: MainApp = main_packed.instantiate() as MainApp
	_assert_true(main_node != null, "main.tscn root must be MainApp")
	root.add_child(main_node)

	var player: PlayerController = main_node.get_player()
	var arena: PrototypeArena = main_node.get_arena()
	var hud: GameplayHud = main_node.get_hud()
	var pause_menu: PauseMenu = main_node.get_pause_menu()

	_assert_true(player != null, "PlayerController node must exist")
	_assert_true(arena != null, "PrototypeArena node must exist")
	_assert_true(hud != null, "GameplayHud node must exist")
	_assert_true(pause_menu != null, "PauseMenu node must exist")

	if player != null and arena != null and hud != null and pause_menu != null:
		var spawn_pos: Vector3 = arena.get_spawn_transform().origin
		_assert_true(player.global_position.distance_to(spawn_pos) < 0.01, "Player must spawn at SpawnPoint")
		_assert_true(hud.get_mode_text() == "MODE: PLAY", "HUD must start in PLAY mode")
		_assert_true(not pause_menu.visible, "PauseMenu must start hidden")

		# Verify camera orbit and vertical clamp
		var cam_rig: ThirdPersonCamera = player.get_camera_rig()
		_assert_true(cam_rig != null, "ThirdPersonCamera rig must be linked to Player")
		if cam_rig != null:
			cam_rig.apply_look_delta(Vector2(120.0, -5000.0))
			cam_rig._physics_process(0.1)
			var max_rad: float = deg_to_rad(cam_rig.max_pitch_deg) + 0.001
			_assert_true(cam_rig.get_pitch() <= max_rad, "Camera pitch must clamp to max_pitch_deg")

		# Verify camera-relative movement vector
		var move_dir: Vector3 = player.compute_camera_relative_direction(Vector2(0.0, -1.0))
		_assert_true(move_dir.length() > 0.99, "Camera-relative movement vector must be normalized")

		# Verify pause and resume flow
		main_node.set_paused(true)
		_assert_true(main_node.is_paused(), "MainApp must enter paused state")
		_assert_true(pause_menu.visible, "PauseMenu must be visible when paused")
		_assert_true(hud.get_mode_text() == "MODE: PAUSED", "HUD must show PAUSED mode")
		_assert_true(not player.controls_enabled, "Player controls must disable while paused")

		main_node.set_paused(false)
		_assert_true(not main_node.is_paused(), "MainApp must resume from pause")
		_assert_true(not pause_menu.visible, "PauseMenu must hide on resume")
		_assert_true(hud.get_mode_text() == "MODE: PLAY", "HUD must return to PLAY mode")

		# Verify fall detection and restart reset
		player.global_position = Vector3(4.0, -10.0, -5.0)
		player.velocity = Vector3(3.0, -12.0, -4.0)
		_assert_true(arena.is_below_fail_plane(player.global_position), "Arena must detect position below fail plane")
		main_node.restart_session()
		_assert_true(player.global_position.distance_to(spawn_pos) < 0.01, "Restart must restore player to SpawnPoint")
		_assert_true(player.velocity.length() < 0.001, "Restart must zero player velocity")

	main_node.queue_free()
	_finish()


func _assert_true(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
		push_error("SMOKE_TEST_FAIL: " + message)


func _finish() -> void:
	if _failures.is_empty():
		print("SMOKE_TEST_M0: PASS")
		quit(0)
	else:
		print("SMOKE_TEST_M0: FAIL (%d failures)" % _failures.size())
		quit(1)

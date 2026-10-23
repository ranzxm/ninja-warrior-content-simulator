extends SceneTree

## Headless smoke and physics test suite for Milestone M1a (Core Competition & 6 Modular Obstacles).
## Run with: godot --headless --path . -s res://tests/smoke_test_m1a.gd

const OBSTACLE_SCENE_PATHS: Array[String] = [
	"res://scenes/obstacles/obs_01_stepping_pads.tscn",
	"res://scenes/obstacles/obs_02_balance_beam.tscn",
	"res://scenes/obstacles/obs_03_moving_platform.tscn",
	"res://scenes/obstacles/obs_04_rotating_sweeper.tscn",
	"res://scenes/obstacles/obs_05_swinging_pendulum.tscn",
	"res://scenes/obstacles/obs_06_warped_wall.tscn",
]

var _failures: Array[String] = []
var _main_node: MainApp = null
var _frame: int = 0
var _completed_signal_count: int = 0
var _plat_start_player_z: float = 0.0
var _warped_wall_jumped: bool = false


func _initialize() -> void:
	var main_packed: PackedScene = load("res://scenes/app/main.tscn") as PackedScene
	_assert_true(main_packed != null, "1. main.tscn must load")
	if main_packed == null:
		_finish()
		return

	_main_node = main_packed.instantiate() as MainApp
	_assert_true(_main_node != null, "1b. main.tscn root must be MainApp")
	root.add_child(_main_node)


func _physics_process(_delta: float) -> bool:
	_frame += 1
	if _frame == 2:
		_run_contract_and_state_checks()
		_setup_moving_platform_physics_check()
		return false

	if _frame > 2 and _frame <= 32:
		return false

	if _frame == 33:
		_verify_moving_platform_physics_check()
		_setup_sweeper_and_pendulum_physics_check()
		return false

	if _frame > 33 and _frame <= 58:
		return false

	if _frame == 59:
		_verify_sweeper_physics_check()
		_setup_pendulum_physics_check()
		return false

	if _frame > 59 and _frame <= 80:
		return false

	if _frame == 81:
		_verify_pendulum_physics_check()
		_setup_warped_wall_physics_check()
		return false

	if _frame > 81 and _frame <= 165:
		_step_warped_wall_input()
		return false

	if _frame == 166:
		_verify_warped_wall_physics_check()
		_main_node.queue_free()
		_finish()
		return true

	return false


func _run_contract_and_state_checks() -> void:
	var session: RunSession = _main_node.get_run_session()
	var player: PlayerController = _main_node.get_player()
	var stage: StageDemoArena = _main_node.get_arena() as StageDemoArena
	var hud: GameplayHud = _main_node.get_hud()

	_assert_true(session != null, "RunSession must exist on MainApp")
	_assert_true(player != null, "PlayerController must exist on MainApp")
	_assert_true(stage != null, "1c. StageDemoArena must be loaded as active arena")
	_assert_true(hud != null, "GameplayHud must exist on MainApp")
	if session == null or player == null or stage == null or hud == null:
		return

	session.run_completed.connect(_on_run_completed_counted)

	# 2 & 3. All 6 obstacle prefabs instantiate + valid IDs, anchors, and validation
	for path: String in OBSTACLE_SCENE_PATHS:
		var packed: PackedScene = load(path) as PackedScene
		_assert_true(packed != null, "2. Obstacle prefab must load: " + path)
		if packed != null:
			var inst: ObstacleBase = packed.instantiate() as ObstacleBase
			_assert_true(inst != null, "2b. Obstacle must inherit ObstacleBase: " + path)
			root.add_child(inst)
			_assert_true(inst.validate_configuration(), "3. Obstacle configuration must be valid: " + path)
			_assert_true(not inst.obstacle_id.is_empty(), "3b. Obstacle ID must be non-empty: " + path)
			_assert_true(not inst.get_obstacle_type().is_empty(), "3c. Obstacle type must be non-empty: " + path)
			_assert_true(
				inst.get_entry_position().distance_to(inst.get_exit_position()) > 1.0,
				"3d. Entry and exit anchors must be distinct: " + path
			)
			# 13. Invalid obstacle configuration rejected safely
			var rejected: bool = not inst.apply_parameters({
				"pad_count": -5,
				"beam_length": -2.0,
				"movement_distance": -4.0,
				"rotation_speed": -3.0,
				"swing_period": -1.0,
				"wall_height": -2.0,
			})
			_assert_true(rejected, "13. Invalid obstacle parameters must be rejected: " + path)
			_assert_true(inst.validate_configuration(), "13b. Obstacle remains valid after rejecting invalid params: " + path)
			root.remove_child(inst)
			inst.free()

	var stage_obstacles: Array[ObstacleBase] = stage.get_obstacles()
	_assert_true(stage_obstacles.size() == 6, "StageDemoArena must contain all 6 obstacles in sequence")

	# 4. READY state initializes correctly
	_main_node.restart_session()
	var first_run_id: String = session.run_id
	_assert_true(session.state == RunSession.RunState.READY, "4. Session starts in READY state")
	_assert_true(is_zero_approx(session.elapsed_sec), "4b. Timer starts at 0.0")
	_assert_true(hud.get_timer_text() == "TIME: 00:00.000", "4c. HUD displays 00:00.000 in READY")
	_assert_true(not first_run_id.is_empty(), "4d. RunSession generates non-empty run_id")

	# 5. RUNNING state starts the timer
	var started: bool = session.start_run()
	_assert_true(started, "5. start_run() succeeds from READY")
	_assert_true(session.state == RunSession.RunState.RUNNING, "5b. State is RUNNING")
	session.tick(1.25, false)
	_assert_true(absf(session.elapsed_sec - 1.25) < 0.001, "5c. Timer advances during RUNNING")

	# 6. Timer does not advance while paused
	session.tick(2.0, true)
	_assert_true(absf(session.elapsed_sec - 1.25) < 0.001, "6. Timer must not advance while paused")

	# 7. FAILED cannot transition to FINISHED and does not instantly respawn player
	_completed_signal_count = 0
	player.global_position = Vector3(0.0, -3.5, -15.0)
	var failed_ok: bool = session.fail_run("Test Hazard", "obs_02_balance_beam")
	_assert_true(failed_ok, "7. fail_run() succeeds from RUNNING")
	_assert_true(session.state == RunSession.RunState.FAILED, "7b. State is FAILED")
	_assert_true(hud.is_result_visible() and hud.get_result_banner_text() == "FAILED", "7c. HUD shows FAILED banner")
	_assert_true(player.global_position.z < -10.0, "7d. FAILED does not instantly respawn player before retry")
	_assert_true(not session.finish_run(), "7e. FAILED cannot transition to FINISHED")
	_assert_true(not session.fail_run("Duplicate fail"), "7f. FAILED cannot emit duplicate fail")
	_assert_true(_completed_signal_count == 1, "7g. Terminal signal emitted exactly once for FAILED")

	# 10. Retry restores READY state and generates new run_id
	_main_node.restart_session()
	_assert_true(session.state == RunSession.RunState.READY, "10. Retry restores READY state")
	_assert_true(session.run_id != first_run_id, "10b. Retry generates a new unique run_id")
	_assert_true(not hud.is_result_visible(), "10c. Retry hides result overlay")

	# 8 & 12. FINISHED cannot transition to FAILED and cannot duplicate completion
	_completed_signal_count = 0
	session.start_run()
	session.tick(0.75, false)
	_main_node._on_finish_zone_reached(player)
	_main_node._on_finish_zone_reached(player)
	_assert_true(session.state == RunSession.RunState.FINISHED, "8. Finish trigger transitions to FINISHED")
	_assert_true(hud.is_result_visible() and hud.get_result_banner_text() == "STAGE CLEAR", "8b. HUD shows STAGE CLEAR")
	_assert_true(not session.fail_run("Late fail"), "8c. FINISHED cannot transition to FAILED")
	_assert_true(_completed_signal_count == 1, "12. Duplicate finish trigger only completes once")

	# 9. TIMEOUT triggers once
	_main_node.restart_session()
	_completed_signal_count = 0
	session.start_run()
	session.tick(session.time_limit_sec + 5.0, false)
	session.tick(1.0, false)
	_assert_true(session.state == RunSession.RunState.TIMEOUT, "9. Exceeding time limit triggers TIMEOUT")
	_assert_true(absf(session.elapsed_sec - session.time_limit_sec) < 0.001, "9b. Timer clamps at time_limit_sec")
	_assert_true(hud.is_result_visible() and hud.get_result_banner_text() == "TIME UP", "9c. HUD shows TIME UP")
	_assert_true(not session.trigger_timeout(), "9d. TIMEOUT cannot trigger twice")
	_assert_true(_completed_signal_count == 1, "9e. TIMEOUT emits run_completed once")

	# 11. Retry resets all moving obstacles (MovingPlatform, RotatingSweeper, SwingingPendulum)
	var moving_plat: ObstacleMovingPlatform = stage_obstacles[2] as ObstacleMovingPlatform
	var sweeper: ObstacleRotatingSweeper = stage_obstacles[3] as ObstacleRotatingSweeper
	var pendulum: ObstacleSwingingPendulum = stage_obstacles[4] as ObstacleSwingingPendulum
	_assert_true(moving_plat != null and sweeper != null and pendulum != null, "11a. Dynamic obstacles cast cleanly")
	if moving_plat != null and sweeper != null and pendulum != null:
		moving_plat._physics_process(0.8)
		sweeper._physics_process(0.8)
		pendulum._physics_process(0.8)
		_assert_true(moving_plat.get_progress() > 0.05, "11b. MovingPlatform advances during physics step")
		_assert_true(absf(sweeper.get_current_angle_rad()) > 0.05, "11c. RotatingSweeper rotates during physics step")
		_assert_true(pendulum.get_elapsed_time() > 0.5, "11d. SwingingPendulum advances elapsed time")

		_main_node.restart_session()
		_assert_true(is_zero_approx(moving_plat.get_progress()), "11e. Retry resets MovingPlatform progress to 0")
		_assert_true(is_zero_approx(sweeper.get_current_angle_rad()), "11f. Retry resets RotatingSweeper angle to initial")
		_assert_true(is_zero_approx(pendulum.get_elapsed_time()), "11g. Retry resets SwingingPendulum elapsed time to 0")

	# 14. Existing M0 behavior remains intact (clean feed, pause, PrototypeArena)
	var prev_state: RunSession.RunState = session.state
	hud.toggle_clean_feed()
	_assert_true(not hud.visible, "14a. Clean feed hides HUD")
	_assert_true(session.state == prev_state, "14b. Clean feed does not alter RunSession state")
	hud.toggle_clean_feed()
	_assert_true(hud.visible, "14c. Clean feed restores HUD")

	var proto_packed: PackedScene = load("res://scenes/gameplay/prototype_arena.tscn") as PackedScene
	_assert_true(proto_packed != null, "14d. M0 prototype_arena.tscn remains available")


func _setup_moving_platform_physics_check() -> void:
	_main_node.restart_session()
	_main_node.get_run_session().start_run()
	var stage: StageDemoArena = _main_node.get_arena() as StageDemoArena
	var moving_plat: ObstacleMovingPlatform = stage.get_obstacles()[2] as ObstacleMovingPlatform
	var player: PlayerController = _main_node.get_player()
	var plat_pos: Vector3 = moving_plat.get_platform_body().global_position
	player.reset_to_transform(Transform3D(Basis.IDENTITY, Vector3(plat_pos.x, 0.05, plat_pos.z)))
	_plat_start_player_z = player.global_position.z


func _verify_moving_platform_physics_check() -> void:
	var player: PlayerController = _main_node.get_player()
	var moved_z: float = _plat_start_player_z - player.global_position.z
	_assert_true(moved_z > 0.4, "15a. Physics check: MovingPlatform carries standing player along -Z (moved %.2fm)" % moved_z)


func _setup_sweeper_and_pendulum_physics_check() -> void:
	_main_node.restart_session()
	_main_node.get_run_session().start_run()
	var stage: StageDemoArena = _main_node.get_arena() as StageDemoArena
	var sweeper: ObstacleRotatingSweeper = stage.get_obstacles()[3] as ObstacleRotatingSweeper
	var player: PlayerController = _main_node.get_player()
	# Place player on sweeper deck in front of the rotating arm at x = 1.2, z = center - 0.35
	var center_z: float = sweeper.global_position.z - 3.5
	player.reset_to_transform(Transform3D(Basis.IDENTITY, Vector3(1.2, 0.02, center_z - 0.35)))


func _verify_sweeper_physics_check() -> void:
	var player: PlayerController = _main_node.get_player()
	var stage: StageDemoArena = _main_node.get_arena() as StageDemoArena
	var sweeper: ObstacleRotatingSweeper = stage.get_obstacles()[3] as ObstacleRotatingSweeper
	var center_z: float = sweeper.global_position.z - 3.5
	var displaced: float = Vector2(player.global_position.x - 1.2, player.global_position.z - (center_z - 0.35)).length()
	_assert_true(displaced > 0.15, "15b. Physics check: RotatingSweeper arm displaces player (delta=%.2fm)" % displaced)


func _setup_pendulum_physics_check() -> void:
	_main_node.restart_session()
	_main_node.get_run_session().start_run()
	var stage: StageDemoArena = _main_node.get_arena() as StageDemoArena
	var pendulum: ObstacleSwingingPendulum = stage.get_obstacles()[4] as ObstacleSwingingPendulum
	var player: PlayerController = _main_node.get_player()
	var center_z: float = pendulum.global_position.z - 3.5
	player.reset_to_transform(Transform3D(Basis.IDENTITY, Vector3(0.0, 0.02, center_z)))


func _verify_pendulum_physics_check() -> void:
	var player: PlayerController = _main_node.get_player()
	var displaced_x: float = absf(player.global_position.x)
	_assert_true(displaced_x > 0.2, "15c. Physics check: SwingingPendulum bob displaces player laterally (dx=%.2fm)" % displaced_x)


func _setup_warped_wall_physics_check() -> void:
	_main_node.restart_session()
	_main_node.get_run_session().start_run()
	var stage: StageDemoArena = _main_node.get_arena() as StageDemoArena
	var warped_wall: ObstacleWarpedWall = stage.get_obstacles()[5] as ObstacleWarpedWall
	var player: PlayerController = _main_node.get_player()
	var entry_pos: Vector3 = warped_wall.get_entry_position()
	player.reset_to_transform(Transform3D(Basis.IDENTITY, Vector3(entry_pos.x, entry_pos.y + 0.02, entry_pos.z - 0.3)))
	_warped_wall_jumped = false


func _step_warped_wall_input() -> void:
	var player: PlayerController = _main_node.get_player()
	if _warped_wall_jumped and player.global_position.y >= 3.15 and player.is_on_floor():
		player.set_override_input(Vector2.ZERO, false, false)
		return
	var should_jump: bool = false
	if not _warped_wall_jumped and player.global_position.y >= 1.75 and player.is_on_floor():
		should_jump = true
		_warped_wall_jumped = true
	player.set_override_input(Vector2(0.0, -1.0), true, should_jump)


func _verify_warped_wall_physics_check() -> void:
	var player: PlayerController = _main_node.get_player()
	player.clear_override_input()
	_assert_true(
		player.global_position.y >= 3.1,
		"15d. Physics check: Player climbs Warped Wall onto summit deck (y=%.2f)" % player.global_position.y
	)


func _on_run_completed_counted(
	_run_id: String,
	_final_state: RunSession.RunState,
	_elapsed_sec: float,
	_reason: String,
	_last_obstacle_id: String
) -> void:
	_completed_signal_count += 1


func _assert_true(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
		push_error("SMOKE_TEST_M1A_FAIL: " + message)


func _finish() -> void:
	if _failures.is_empty():
		print("SMOKE_TEST_M1A: PASS")
		quit(0)
	else:
		print("SMOKE_TEST_M1A: FAIL (%d failures)" % _failures.size())
		quit(1)

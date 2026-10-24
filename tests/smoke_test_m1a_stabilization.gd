extends SceneTree

## Comprehensive stabilization & regression suite for Milestone M1a (Groups A–F, 44 test cases).
## Run with: godot --headless --path . -s res://tests/smoke_test_m1a_stabilization.gd

const OBSTACLE_SCENES: Dictionary = {
	"stepping_pads": "res://scenes/obstacles/obs_01_stepping_pads.tscn",
	"balance_beam": "res://scenes/obstacles/obs_02_balance_beam.tscn",
	"moving_platform": "res://scenes/obstacles/obs_03_moving_platform.tscn",
	"rotating_sweeper": "res://scenes/obstacles/obs_04_rotating_sweeper.tscn",
	"swinging_pendulum": "res://scenes/obstacles/obs_05_swinging_pendulum.tscn",
	"warped_wall": "res://scenes/obstacles/obs_06_warped_wall.tscn",
}

var _failures: Array[String] = []
var _passed_checks: int = 0
var _main_node: MainApp = null
var _frame: int = 0
var _completed_signals: int = 0
var _plat_initial_z: float = 0.0
var _warped_jumped: bool = false


func _initialize() -> void:
	var main_packed: PackedScene = load("res://scenes/app/main.tscn") as PackedScene
	_assert_true(main_packed != null, "A0. main.tscn must load")
	if main_packed == null:
		_finish()
		return
	_main_node = main_packed.instantiate() as MainApp
	root.add_child(_main_node)


func _physics_process(_delta: float) -> bool:
	_frame += 1
	if _frame == 2:
		_test_group_a_competition_lifecycle()
		_test_group_b_completion_integrity()
		_test_group_c_obstacle_activation()
		return false

	if _frame == 3:
		_verify_group_c_restored_raycasts()
		_test_group_d_parameter_contract_and_roundtrip()
		_test_group_e_deterministic_lifecycle()
		_test_group_f_m0_regression()
		_setup_e29_moving_platform_physics()
		return false

	if _frame > 2 and _frame <= 32:
		return false

	if _frame == 33:
		_verify_e29_moving_platform_physics()
		_setup_e30_sweeper_physics()
		return false

	if _frame > 33 and _frame <= 58:
		return false

	if _frame == 59:
		_verify_e30_sweeper_physics()
		_setup_e31_pendulum_physics()
		return false

	if _frame > 59 and _frame <= 80:
		return false

	if _frame == 81:
		_verify_e31_pendulum_physics()
		_setup_e36_warped_wall_physics()
		return false

	if _frame > 81 and _frame <= 165:
		_step_e36_warped_wall_input()
		return false

	if _frame == 166:
		_verify_e36_warped_wall_physics()
		root.remove_child(_main_node)
		_main_node.free()
		_main_node = null
		_finish()
		return true

	return false


func _test_group_a_competition_lifecycle() -> void:
	var session: RunSession = _main_node.get_run_session()
	var player: PlayerController = _main_node.get_player()
	var stage: StageDemoArena = _main_node.get_arena() as StageDemoArena
	var hud: GameplayHud = _main_node.get_hud()

	if not session.run_completed.is_connected(_on_session_completed):
		session.run_completed.connect(_on_session_completed)

	# A1. READY initializes correctly
	_main_node.restart_session()
	var run_id_1: String = session.run_id
	_assert_true(session.state == RunSession.RunState.READY, "A1. Session initializes in READY")
	_assert_true(is_zero_approx(session.elapsed_sec), "A1b. Elapsed time starts at 0.0")
	_assert_true(hud.get_run_state_text() == "RUN: READY", "A1c. HUD displays RUN: READY")

	# A2. StartGate begins RUNNING once; obstacle entry in READY does not start run; fall in READY recovers safely
	var obs_first: ObstacleBase = stage.get_obstacles()[0]
	_main_node._on_stage_obstacle_entered(obs_first, 1, 6)
	_assert_true(session.state == RunSession.RunState.READY, "A2a. Entering obstacle before StartGate does not start run")

	player.global_position = Vector3(0.0, -5.0, 2.0)
	_main_node._handle_player_fall("Fell in READY", "")
	_assert_true(session.state == RunSession.RunState.READY, "A2b. Falling in READY recovers without fake FAILED run")
	_assert_true(player.global_position.distance_to(stage.get_spawn_transform().origin) < 0.05, "A2c. Falling in READY returns player to SpawnPoint")

	_main_node._on_start_gate_crossed(player)
	_assert_true(session.state == RunSession.RunState.RUNNING, "A2d. Crossing StartGate transitions READY -> RUNNING")
	_assert_true(not session.start_run(), "A2e. StartGate cannot start run a second time while RUNNING")

	# A3 & A4. Timer increases only when RUNNING and stops when paused
	session.tick(0.0, false)
	session.tick(1.5, false)
	_assert_true(is_equal_approx(session.elapsed_sec, 1.5), "A3. Timer advances when RUNNING")
	session.tick(3.0, true)
	_assert_true(is_equal_approx(session.elapsed_sec, 1.5), "A4. Timer does not advance while paused")

	# A5 & A6. Terminal states stop timer progression and reject invalid transitions
	_completed_signals = 0
	_assert_true(session.fail_run("Hazard Test", "obs_01_stepping_pads"), "A5a. RUNNING -> FAILED succeeds")
	session.tick(2.0, false)
	_assert_true(is_equal_approx(session.elapsed_sec, 1.5), "A5b. Timer stops in FAILED state")
	_assert_true(not session.finish_run(), "A6a. FAILED cannot transition to FINISHED")
	_assert_true(not session.trigger_timeout(), "A6b. FAILED cannot transition to TIMEOUT")
	_assert_true(not session.start_run(), "A6c. FAILED cannot start_run without reset")
	_assert_true(_completed_signals == 1, "A6d. Terminal signal emitted once")

	# A7 & A8. Retry generates new run ID and resets state, player, and obstacles
	_main_node.restart_session()
	_assert_true(session.state == RunSession.RunState.READY, "A7a. Retry restores READY")
	_assert_true(session.run_id != run_id_1, "A7b. Retry generates new unique run_id")
	_assert_true(is_zero_approx(session.elapsed_sec), "A8a. Retry zeroes elapsed time")
	_assert_true(session.get_completed_count() == 0, "A8b. Retry clears completed obstacles")


func _test_group_b_completion_integrity() -> void:
	var session: RunSession = _main_node.get_run_session()
	var player: PlayerController = _main_node.get_player()
	var stage: StageDemoArena = _main_node.get_arena() as StageDemoArena
	var hud: GameplayHud = _main_node.get_hud()
	var obstacles: Array[ObstacleBase] = stage.get_obstacles()

	_main_node.restart_session()
	_main_node._on_start_gate_crossed(player)

	var obs1: ObstacleBase = obstacles[0]
	var obs2: ObstacleBase = obstacles[1]
	var obs4: ObstacleBase = obstacles[3]

	# B10. Exit without valid entry does not complete an obstacle
	_main_node._on_stage_obstacle_completed(obs1, 1, 6)
	_assert_true(session.get_completed_count() == 0, "B10. Exit without prior entry is rejected")
	_assert_true(obs1.get_traversal_state() == ObstacleBase.TraversalState.NOT_STARTED, "B10b. Obstacle remains NOT_STARTED")

	# B9. Entry alone does not complete an obstacle
	_main_node._on_stage_obstacle_entered(obs1, 1, 6)
	_assert_true(obs1.get_traversal_state() == ObstacleBase.TraversalState.ENTERED, "B9a. Entry marks obstacle ENTERED")
	_assert_true(session.get_completed_count() == 0, "B9b. Entry alone keeps completed count at 0")
	_assert_true(hud.get_obstacle_text().contains("[IN PROGRESS]"), "B9c. HUD shows [IN PROGRESS]")
	_assert_true(hud.get_completed_text() == "COMPLETED: 0/6", "B9d. HUD shows COMPLETED: 0/6 on entry")

	# B13a. Entering obstacle 4 before completing obstacle 1 is rejected
	_main_node._on_stage_obstacle_entered(obs4, 4, 6)
	_assert_true(obs4.get_traversal_state() == ObstacleBase.TraversalState.NOT_STARTED, "B13a. Out-of-order entry is rejected")

	# B11. Valid entry followed by exit completes it
	_main_node._on_stage_obstacle_completed(obs1, 1, 6)
	_assert_true(obs1.get_traversal_state() == ObstacleBase.TraversalState.COMPLETED, "B11a. Valid exit marks obstacle COMPLETED")
	_assert_true(session.get_completed_count() == 1, "B11b. Completed count increments to 1")
	_assert_true(hud.get_obstacle_text().contains("[CLEARED]"), "B11c. HUD shows [CLEARED]")
	_assert_true(hud.get_completed_text() == "COMPLETED: 1/6", "B11d. HUD shows COMPLETED: 1/6")

	# B12. Duplicate exit or re-entry cannot increment progress twice
	_main_node._on_stage_obstacle_completed(obs1, 1, 6)
	_main_node._on_stage_obstacle_entered(obs1, 1, 6)
	_main_node._on_stage_obstacle_completed(obs1, 1, 6)
	_assert_true(session.get_completed_count() == 1, "B12. Duplicate exit/re-entry does not inflate progress")

	# B13b. Out-of-order completion on obstacle 4 before obstacle 2 is rejected
	_main_node._on_stage_obstacle_entered(obs4, 4, 6)
	_main_node._on_stage_obstacle_completed(obs4, 4, 6)
	_assert_true(session.get_completed_count() == 1, "B13b. Out-of-order completion is rejected")

	# B14. Early FinishZone cannot finish the run
	_main_node._on_finish_zone_reached(player)
	_assert_true(session.state == RunSession.RunState.RUNNING, "B14a. Early FinishZone is rejected while obstacles incomplete")
	_assert_true(not hud.is_result_visible(), "B14b. HUD does not display STAGE CLEAR on early FinishZone")

	# Complete remaining obstacles 2..6 in order
	for idx: int in range(1, obstacles.size()):
		var obs: ObstacleBase = obstacles[idx]
		_main_node._on_stage_obstacle_entered(obs, idx + 1, 6)
		_main_node._on_stage_obstacle_completed(obs, idx + 1, 6)

	_assert_true(session.get_completed_count() == 6, "B15a. All 6 obstacles completed in sequence")

	# Verify disabled required obstacle blocks finishing
	obs2.is_enabled = false
	_main_node._on_finish_zone_reached(player)
	_assert_true(session.state == RunSession.RunState.RUNNING, "B15b. Disabled required obstacle prevents finishing")
	obs2.is_enabled = true

	# B15 & B16. Six valid ordered completions with all enabled permit finishing once
	_completed_signals = 0
	_main_node._on_finish_zone_reached(player)
	_main_node._on_finish_zone_reached(player)
	_assert_true(session.state == RunSession.RunState.FINISHED, "B15c. FinishZone succeeds after all 6 obstacles completed")
	_assert_true(_completed_signals == 1, "B16. Terminal completion signal emitted once")


func _test_group_c_obstacle_activation() -> void:
	var stage: StageDemoArena = _main_node.get_arena() as StageDemoArena
	var player: PlayerController = _main_node.get_player()
	var obstacles: Array[ObstacleBase] = stage.get_obstacles()
	var space_state: PhysicsDirectSpaceState3D = stage.get_world_3d().direct_space_state

	_main_node.restart_session()
	_main_node._on_start_gate_crossed(player)

	for obs: ObstacleBase in obstacles:
		var probe_target: Vector3 = _get_obstacle_solid_point(obs)
		var probe_from: Vector3 = probe_target + Vector3(0.0, 2.5, 0.0)
		var probe_to: Vector3 = probe_target + Vector3(0.0, -2.5, 0.0)
		var query_enabled: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(probe_from, probe_to, 5)
		var hit_when_enabled: Dictionary = space_state.intersect_ray(query_enabled)
		_assert_true(not hit_when_enabled.is_empty(), "C17_ray_on. Enabled obstacle blocks physics ray: " + obs.obstacle_id)

		# C17, C18, C19: Disable obstacle
		obs.start_simulation()
		obs.is_enabled = false
		_assert_true(not obs.visible, "C17a. Disabled obstacle is hidden: " + obs.obstacle_id)
		_assert_true(not obs.is_simulation_running(), "C19a. Disabled obstacle stops simulation: " + obs.obstacle_id)
		_assert_true(_all_collisions_disabled(obs), "C17b. All CollisionObject3D/CollisionShape3D disabled: " + obs.obstacle_id)

		var hit_when_disabled: Dictionary = space_state.intersect_ray(query_enabled)
		_assert_true(hit_when_disabled.is_empty(), "C17_ray_off. Disabled obstacle does NOT block physics ray: " + obs.obstacle_id)

		# Trigger signals must be suppressed while disabled
		var prev_entered: String = _main_node.get_run_session().last_entered_obstacle_id
		obs._on_entry_trigger_body_entered(player)
		obs._on_exit_trigger_body_entered(player)
		obs._on_hazard_zone_body_entered(player)
		_assert_true(
			_main_node.get_run_session().last_entered_obstacle_id == prev_entered,
			"C18a. Disabled obstacle suppresses entry/exit triggers: " + obs.obstacle_id
		)
		_assert_true(
			_main_node.get_run_session().state == RunSession.RunState.RUNNING,
			"C18b. Disabled obstacle suppresses hazard triggers: " + obs.obstacle_id
		)

		# C20 & C21: Multiple enable/disable cycles restore collision cleanly
		obs.is_enabled = true
		obs.is_enabled = false
		obs.is_enabled = true
		_assert_true(obs.visible, "C20a. Re-enabled obstacle is visible: " + obs.obstacle_id)
		_assert_true(_all_collisions_restored(obs), "C20b. Re-enabled obstacle restores collision layers & shapes: " + obs.obstacle_id)


func _verify_group_c_restored_raycasts() -> void:
	var stage: StageDemoArena = _main_node.get_arena() as StageDemoArena
	var space_state: PhysicsDirectSpaceState3D = stage.get_world_3d().direct_space_state
	for obs: ObstacleBase in stage.get_obstacles():
		var probe_target: Vector3 = _get_obstacle_solid_point(obs)
		var probe_from: Vector3 = probe_target + Vector3(0.0, 2.5, 0.0)
		var probe_to: Vector3 = probe_target + Vector3(0.0, -2.5, 0.0)
		var query_restored: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(probe_from, probe_to, 5)
		var hit_restored: Dictionary = space_state.intersect_ray(query_restored)
		_assert_true(not hit_restored.is_empty(), "C20_ray_restored. Re-enabled obstacle blocks physics ray again: " + obs.obstacle_id)


func _test_group_d_parameter_contract_and_roundtrip() -> void:
	var custom_configs: Dictionary = {
		"stepping_pads": {
			"pad_count": 5,
			"pad_dimensions": [2.1, 0.5, 1.9],
			"gap_distance": 1.1,
			"height_variation": 0.2,
			"lateral_offset": 0.6,
		},
		"balance_beam": {
			"beam_length": 9.5,
			"beam_width": 0.75,
			"beam_height": 0.55,
		},
		"moving_platform": {
			"movement_distance": 6.0,
			"movement_speed": 3.2,
			"travel_mode": "LOOP",
			"initial_direction": -1,
			"platform_size": [3.2, 0.5, 3.0],
		},
		"rotating_sweeper": {
			"rotation_speed": 2.4,
			"rotation_direction": -1,
			"arm_length": 5.2,
			"arm_height": 0.65,
			"initial_angle_deg": 45.0,
			"push_strength": 11.0,
		},
		"swinging_pendulum": {
			"swing_amplitude_deg": 55.0,
			"swing_period": 3.0,
			"pendulum_length": 3.8,
			"initial_phase_deg": 30.0,
			"knockback_speed": 12.5,
		},
		"warped_wall": {
			"wall_height": 3.6,
			"wall_width": 4.2,
			"curve_profile": 1.2,
		},
	}

	for obs_type: String in OBSTACLE_SCENES.keys():
		var path: String = String(OBSTACLE_SCENES[obs_type])
		var packed: PackedScene = load(path) as PackedScene
		var inst_a: ObstacleBase = packed.instantiate() as ObstacleBase
		root.add_child(inst_a)

		var cfg: Dictionary = custom_configs[obs_type] as Dictionary
		var applied_a: bool = inst_a.apply_parameters(cfg)
		_assert_true(applied_a, "D22a. Valid non-default config accepted for " + obs_type)

		var exported_params: Dictionary = inst_a.get_parameters()
		var json_str: String = JSON.stringify(exported_params)
		var parsed_json: Variant = JSON.parse_string(json_str)
		_assert_true(typeof(parsed_json) == TYPE_DICTIONARY, "D22b. JSON round-trip parses as Dictionary for " + obs_type)

		var inst_b: ObstacleBase = packed.instantiate() as ObstacleBase
		root.add_child(inst_b)
		var applied_b: bool = inst_b.apply_parameters(parsed_json as Dictionary)
		_assert_true(applied_b, "D22c. Parsed JSON config applies cleanly to fresh prefab for " + obs_type)

		_assert_true(
			_dictionaries_approx_equal(inst_a.get_parameters(), inst_b.get_parameters()),
			"D22d. Parameter round-trip matches for " + obs_type
		)
		_assert_true(
			inst_a.get_entry_position().distance_to(inst_b.get_entry_position()) < 0.001,
			"D28a. EntryAnchor matches after round-trip for " + obs_type
		)
		_assert_true(
			inst_a.get_exit_position().distance_to(inst_b.get_exit_position()) < 0.001,
			"D28b. ExitAnchor matches after round-trip for " + obs_type
		)

		# D27. Verify mesh and collision dimensions agree after update
		_verify_geometry_dimensions_match(inst_b, obs_type)

		# D23, D24, D25, D26: Atomic rejection of unknown keys, bad types, NaN/INF, and out-of-range values
		var snapshot_before: Dictionary = inst_b.get_parameters().duplicate(true)

		var first_key: String = String(cfg.keys()[0])
		var atomic_bad_unknown: Dictionary = cfg.duplicate(true)
		atomic_bad_unknown["unknown_illegal_param"] = 42
		_assert_true(not inst_b.apply_parameters(atomic_bad_unknown), "D25. Unknown parameter key rejected for " + obs_type)

		var atomic_bad_type: Dictionary = cfg.duplicate(true)
		atomic_bad_type[first_key] = "invalid_string_for_number"
		_assert_true(not inst_b.apply_parameters(atomic_bad_type), "D23. Invalid parameter type rejected for " + obs_type)

		var atomic_bad_nan: Dictionary = cfg.duplicate(true)
		atomic_bad_nan[first_key] = NAN
		_assert_true(not inst_b.apply_parameters(atomic_bad_nan), "D24a. NaN rejected for " + obs_type)

		var atomic_bad_range: Dictionary = cfg.duplicate(true)
		atomic_bad_range[first_key] = -999.0
		_assert_true(not inst_b.apply_parameters(atomic_bad_range), "D24b. Out-of-range value rejected for " + obs_type)

		_assert_true(
			_dictionaries_approx_equal(snapshot_before, inst_b.get_parameters()),
			"D26. Failed parameter updates are atomic and preserve previous state for " + obs_type
		)

		root.remove_child(inst_a)
		root.remove_child(inst_b)
		inst_a.free()
		inst_b.free()


func _test_group_e_deterministic_lifecycle() -> void:
	var session: RunSession = _main_node.get_run_session()
	var stage: StageDemoArena = _main_node.get_arena() as StageDemoArena
	var obstacles: Array[ObstacleBase] = stage.get_obstacles()
	var mplat: ObstacleMovingPlatform = obstacles[2] as ObstacleMovingPlatform
	var sweeper: ObstacleRotatingSweeper = obstacles[3] as ObstacleRotatingSweeper
	var pendulum: ObstacleSwingingPendulum = obstacles[4] as ObstacleSwingingPendulum

	# E32. Dynamic obstacles freeze at initial phase in READY
	_main_node.restart_session()
	_assert_true(session.state == RunSession.RunState.READY, "E32a. Session is READY")
	mplat._physics_process(0.5)
	sweeper._physics_process(0.5)
	pendulum._physics_process(0.5)
	_assert_true(is_zero_approx(mplat.get_progress()), "E32b. MovingPlatform stays frozen at 0 in READY")
	_assert_true(is_zero_approx(sweeper.get_current_angle_rad()), "E32c. RotatingSweeper stays frozen in READY")
	_assert_true(is_zero_approx(pendulum.get_elapsed_time()), "E32d. SwingingPendulum stays frozen in READY")

	# E33 & E35. Dynamic obstacles run in RUNNING and progress deterministically for identical step sequences
	session.start_run()
	for _i: int in range(20):
		mplat._physics_process(1.0 / 60.0)
		sweeper._physics_process(1.0 / 60.0)
		pendulum._physics_process(1.0 / 60.0)

	var run1_plat: float = mplat.get_progress()
	var run1_sweep: float = sweeper.get_current_angle_rad()
	var run1_pend: float = pendulum.get_current_angle_rad()
	_assert_true(run1_plat > 0.05 and absf(run1_sweep) > 0.05 and absf(run1_pend) > 0.05, "E33. Dynamic obstacles animate in RUNNING")

	# E34. Dynamic obstacles freeze in terminal states
	session.fail_run("Lifecycle freeze check")
	mplat._physics_process(0.5)
	sweeper._physics_process(0.5)
	pendulum._physics_process(0.5)
	_assert_true(is_equal_approx(mplat.get_progress(), run1_plat), "E34a. MovingPlatform freezes in FAILED")
	_assert_true(is_equal_approx(sweeper.get_current_angle_rad(), run1_sweep), "E34b. RotatingSweeper freezes in FAILED")
	_assert_true(is_equal_approx(pendulum.get_current_angle_rad(), run1_pend), "E34c. SwingingPendulum freezes in FAILED")

	# E35. Retry restores initial phase and reproduces identical phase after 20 ticks
	_main_node.restart_session()
	_assert_true(is_zero_approx(mplat.get_progress()), "E35a. Retry resets MovingPlatform phase")
	session.start_run()
	for _i: int in range(20):
		mplat._physics_process(1.0 / 60.0)
		sweeper._physics_process(1.0 / 60.0)
		pendulum._physics_process(1.0 / 60.0)
	_assert_true(is_equal_approx(mplat.get_progress(), run1_plat), "E35b. Deterministic MovingPlatform progression")
	_assert_true(is_equal_approx(sweeper.get_current_angle_rad(), run1_sweep), "E35c. Deterministic RotatingSweeper progression")
	_assert_true(is_equal_approx(pendulum.get_current_angle_rad(), run1_pend), "E35d. Deterministic SwingingPendulum progression")


func _test_group_f_m0_regression() -> void:
	var player: PlayerController = _main_node.get_player()
	var hud: GameplayHud = _main_node.get_hud()
	var pause_menu: PauseMenu = _main_node.get_pause_menu()

	_main_node.restart_session()
	var dir_vec: Vector3 = player.compute_camera_relative_direction(Vector2(0.0, -1.0))
	_assert_true(dir_vec.length() > 0.99, "F37. Camera-relative WASD direction functional")
	_assert_true(player.sprint_speed > player.walk_speed, "F38. Sprint speed configuration valid")
	_assert_true(player.jump_velocity > 0.0, "F39. Jump velocity configuration valid")

	var cam_rig: ThirdPersonCamera = player.get_camera_rig()
	cam_rig.apply_look_delta(Vector2(50.0, -4000.0))
	cam_rig._physics_process(0.1)
	_assert_true(cam_rig.get_pitch() <= deg_to_rad(cam_rig.max_pitch_deg) + 0.001, "F40. Camera orbit pitch clamp functional")

	_main_node.set_paused(true)
	_assert_true(_main_node.is_paused() and pause_menu.visible, "F41a. Pause opens PauseMenu")
	_main_node.set_paused(false)
	_assert_true(not _main_node.is_paused() and not pause_menu.visible, "F41b. Resume hides PauseMenu")

	_main_node.restart_session()
	_assert_true(_main_node.get_run_session().state == RunSession.RunState.READY, "F42. Restart functional")

	hud.toggle_clean_feed()
	_assert_true(not hud.visible, "F43a. Clean feed hides HUD")
	hud.toggle_clean_feed()
	_assert_true(hud.visible, "F43b. Clean feed restores HUD")

	var proto_packed: PackedScene = load("res://scenes/gameplay/prototype_arena.tscn") as PackedScene
	_assert_true(proto_packed != null, "F44. Original M0 prototype_arena.tscn available")


func _setup_e29_moving_platform_physics() -> void:
	_main_node.restart_session()
	_main_node.get_run_session().start_run()
	var stage: StageDemoArena = _main_node.get_arena() as StageDemoArena
	var moving_plat: ObstacleMovingPlatform = stage.get_obstacles()[2] as ObstacleMovingPlatform
	var player: PlayerController = _main_node.get_player()
	var plat_pos: Vector3 = moving_plat.get_platform_body().global_position
	player.reset_to_transform(Transform3D(Basis.IDENTITY, Vector3(plat_pos.x, 0.05, plat_pos.z)))
	_plat_initial_z = player.global_position.z


func _verify_e29_moving_platform_physics() -> void:
	var player: PlayerController = _main_node.get_player()
	var moved_z: float = _plat_initial_z - player.global_position.z
	_assert_true(moved_z > 0.4, "E29. MovingPlatform physically carries standing player (moved %.2fm)" % moved_z)


func _setup_e30_sweeper_physics() -> void:
	_main_node.restart_session()
	_main_node.get_run_session().start_run()
	var stage: StageDemoArena = _main_node.get_arena() as StageDemoArena
	var sweeper: ObstacleRotatingSweeper = stage.get_obstacles()[3] as ObstacleRotatingSweeper
	var player: PlayerController = _main_node.get_player()
	var center_z: float = sweeper.global_position.z - 3.5
	player.reset_to_transform(Transform3D(Basis.IDENTITY, Vector3(1.2, 0.02, center_z - 0.35)))


func _verify_e30_sweeper_physics() -> void:
	var player: PlayerController = _main_node.get_player()
	var stage: StageDemoArena = _main_node.get_arena() as StageDemoArena
	var sweeper: ObstacleRotatingSweeper = stage.get_obstacles()[3] as ObstacleRotatingSweeper
	var center_z: float = sweeper.global_position.z - 3.5
	var displaced: float = Vector2(player.global_position.x - 1.2, player.global_position.z - (center_z - 0.35)).length()
	_assert_true(displaced > 0.15, "E30. RotatingSweeper physically displaces player (delta=%.2fm)" % displaced)


func _setup_e31_pendulum_physics() -> void:
	_main_node.restart_session()
	_main_node.get_run_session().start_run()
	var stage: StageDemoArena = _main_node.get_arena() as StageDemoArena
	var pendulum: ObstacleSwingingPendulum = stage.get_obstacles()[4] as ObstacleSwingingPendulum
	var player: PlayerController = _main_node.get_player()
	var center_z: float = pendulum.global_position.z - 3.5
	player.reset_to_transform(Transform3D(Basis.IDENTITY, Vector3(0.0, 0.02, center_z)))


func _verify_e31_pendulum_physics() -> void:
	var player: PlayerController = _main_node.get_player()
	var displaced_x: float = absf(player.global_position.x)
	_assert_true(displaced_x > 0.2, "E31. SwingingPendulum physically displaces player (dx=%.2fm)" % displaced_x)


func _setup_e36_warped_wall_physics() -> void:
	_main_node.restart_session()
	_main_node.get_run_session().start_run()
	var stage: StageDemoArena = _main_node.get_arena() as StageDemoArena
	var warped_wall: ObstacleWarpedWall = stage.get_obstacles()[5] as ObstacleWarpedWall
	var player: PlayerController = _main_node.get_player()
	var entry_pos: Vector3 = warped_wall.get_entry_position()
	player.reset_to_transform(Transform3D(Basis.IDENTITY, Vector3(entry_pos.x, entry_pos.y + 0.02, entry_pos.z - 0.3)))
	_warped_jumped = false


func _step_e36_warped_wall_input() -> void:
	var player: PlayerController = _main_node.get_player()
	if _warped_jumped and player.global_position.y >= 3.15 and player.is_on_floor():
		player.set_override_input(Vector2.ZERO, false, false)
		return
	var should_jump: bool = false
	if not _warped_jumped and player.global_position.y >= 1.75 and player.is_on_floor():
		should_jump = true
		_warped_jumped = true
	player.set_override_input(Vector2(0.0, -1.0), true, should_jump)


func _verify_e36_warped_wall_physics() -> void:
	var player: PlayerController = _main_node.get_player()
	player.clear_override_input()
	_assert_true(
		player.global_position.y >= 3.1,
		"E36. Warped Wall physically traversable onto summit TopDeck (y=%.2f)" % player.global_position.y
	)


func _verify_geometry_dimensions_match(obs: ObstacleBase, obs_type: String) -> void:
	match obs_type:
		"stepping_pads":
			var sp: ObstacleSteppingPads = obs as ObstacleSteppingPads
			var bodies: Array[StaticBody3D] = sp.get_pad_bodies()
			_assert_true(bodies.size() == sp.pad_count, "D27a. SteppingPads body count matches pad_count")
			if not bodies.is_empty():
				var m: MeshInstance3D = bodies[0].get_node("MeshInstance3D") as MeshInstance3D
				var c: CollisionShape3D = bodies[0].get_node("CollisionShape3D") as CollisionShape3D
				_assert_true(
					(m.mesh as BoxMesh).size.distance_to((c.shape as BoxShape3D).size) < 0.001,
					"D27b. SteppingPads mesh and collider sizes match"
				)
		"balance_beam":
			var bb: ObstacleBalanceBeam = obs as ObstacleBalanceBeam
			_assert_true(
				bb.get_beam_mesh_size().distance_to(bb.get_beam_collision_size()) < 0.001,
				"D27c. BalanceBeam mesh and collider sizes match"
			)
		"moving_platform":
			var mp: ObstacleMovingPlatform = obs as ObstacleMovingPlatform
			_assert_true(
				mp.get_platform_mesh_size().distance_to(mp.get_platform_collision_size()) < 0.001,
				"D27d. MovingPlatform mesh and collider sizes match"
			)
		"rotating_sweeper":
			var rs: ObstacleRotatingSweeper = obs as ObstacleRotatingSweeper
			_assert_true(
				rs.get_arm_mesh_size().distance_to(rs.get_arm_collision_size()) < 0.001,
				"D27e. RotatingSweeper arm mesh and collider sizes match"
			)
		"swinging_pendulum":
			var pend: ObstacleSwingingPendulum = obs as ObstacleSwingingPendulum
			_assert_true(
				is_equal_approx(pend.get_rod_height(), pend.pendulum_length)
				and is_equal_approx(pend.get_bob_local_y(), -pend.pendulum_length),
				"D27f. SwingingPendulum rod height and bob collision offset match"
			)
		"warped_wall":
			var ww: ObstacleWarpedWall = obs as ObstacleWarpedWall
			var top_body: StaticBody3D = ww.get_top_deck_body()
			_assert_true(top_body != null, "D27g. WarpedWall TopDeck body exists")
			if top_body != null:
				var wm: MeshInstance3D = top_body.get_node("MeshInstance3D") as MeshInstance3D
				var wc: CollisionShape3D = top_body.get_node("CollisionShape3D") as CollisionShape3D
				_assert_true(
					(wm.mesh as BoxMesh).size.distance_to((wc.shape as BoxShape3D).size) < 0.001,
					"D27h. WarpedWall TopDeck mesh and collider sizes match"
				)


func _get_obstacle_solid_point(obs: ObstacleBase) -> Vector3:
	if obs is ObstacleSteppingPads:
		var pads: Array[StaticBody3D] = (obs as ObstacleSteppingPads).get_pad_bodies()
		if not pads.is_empty():
			return pads[0].global_position
	elif obs is ObstacleMovingPlatform:
		return (obs as ObstacleMovingPlatform).get_platform_body().global_position
	return obs.global_position + Vector3(0.0, -0.2, -2.0)


func _all_collisions_disabled(node: Node) -> bool:
	if node is CollisionObject3D:
		var co: CollisionObject3D = node as CollisionObject3D
		if co.collision_layer != 0 or co.collision_mask != 0:
			return false
	elif node is CollisionShape3D:
		if not (node as CollisionShape3D).disabled:
			return false
	for child: Node in node.get_children():
		if not _all_collisions_disabled(child):
			return false
	return true


func _all_collisions_restored(node: Node) -> bool:
	if node is CollisionObject3D:
		var co: CollisionObject3D = node as CollisionObject3D
		var orig_layer: int = int(co.get_meta(ObstacleBase.META_ORIG_LAYER, co.collision_layer))
		var orig_mask: int = int(co.get_meta(ObstacleBase.META_ORIG_MASK, co.collision_mask))
		if co.collision_layer != orig_layer or co.collision_mask != orig_mask:
			return false
	elif node is CollisionShape3D:
		if (node as CollisionShape3D).disabled:
			return false
	for child: Node in node.get_children():
		if not _all_collisions_restored(child):
			return false
	return true


func _dictionaries_approx_equal(a: Dictionary, b: Dictionary) -> bool:
	if a.size() != b.size():
		return false
	for k: Variant in a.keys():
		if not b.has(k):
			return false
		var va: Variant = a[k]
		var vb: Variant = b[k]
		if (typeof(va) == TYPE_FLOAT or typeof(va) == TYPE_INT) and (typeof(vb) == TYPE_FLOAT or typeof(vb) == TYPE_INT):
			if absf(float(va) - float(vb)) > 0.001:
				return false
		elif va is Array and vb is Array:
			var arr_a: Array = va as Array
			var arr_b: Array = vb as Array
			if arr_a.size() != arr_b.size():
				return false
			for i: int in range(arr_a.size()):
				if absf(float(arr_a[i]) - float(arr_b[i])) > 0.001:
					return false
		elif va != vb:
			return false
	return true


func _on_session_completed(
	_run_id: String,
	_final_state: RunSession.RunState,
	_elapsed_sec: float,
	_reason: String,
	_last_obstacle_id: String
) -> void:
	_completed_signals += 1


func _assert_true(condition: bool, message: String) -> void:
	if condition:
		_passed_checks += 1
	else:
		_failures.append(message)
		push_error("STABILIZATION_TEST_FAIL: " + message)


func _finish() -> void:
	if _failures.is_empty():
		print("SMOKE_TEST_M1A_STABILIZATION: PASS (%d checks passed)" % _passed_checks)
		quit(0)
	else:
		print("SMOKE_TEST_M1A_STABILIZATION: FAIL (%d failures, %d passed)" % [_failures.size(), _passed_checks])
		quit(1)

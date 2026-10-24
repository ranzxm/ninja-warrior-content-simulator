extends SceneTree

## Run: godot --headless --path . -s res://tests/geometry_safeguards_check.gd


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var changes: Dictionary = {
		"stepping_pads": {"pad_dimensions": [8.0, 0.1, 8.0], "lateral_offset": 2.0},
		"balance_beam": {"beam_width": 2.5},
		"moving_platform": {"platform_size": [10.0, 0.15, 10.0]},
		"rotating_sweeper": {"arm_length": 12.0, "initial_angle_deg": 45.0},
		"swinging_pendulum": {"pendulum_length": 12.0, "initial_phase_deg": 90.0},
		"warped_wall": {"wall_width": 8.0, "wall_height": 6.0},
	}
	for obstacle_type: String in ObstacleFactory.get_supported_types():
		var obstacle: ObstacleBase = ObstacleFactory.create_obstacle(obstacle_type)
		var peer: ObstacleBase = ObstacleFactory.create_obstacle(obstacle_type)
		root.add_child(obstacle)
		root.add_child(peer)
		obstacle.set_editor_mode(true)
		var peer_geometry: Dictionary = _resources(peer)
		var peer_mesh_bounds: Dictionary = _mesh_bounds(peer)
		var geometry: Dictionary = _resources(obstacle)
		var revision: int = obstacle.geometry_revision
		obstacle.mark_entered()
		assert(obstacle.apply_parameters(obstacle.get_parameters()))
		assert(obstacle.geometry_revision == revision)
		assert(obstacle.get_traversal_state() == ObstacleBase.TraversalState.ENTERED)
		var original: Dictionary = obstacle.get_parameters()
		obstacle.display_name = ""
		assert(not obstacle.apply_parameters(changes[obstacle_type]))
		assert(obstacle.get_parameters() == original)
		assert(obstacle.geometry_revision == revision)
		obstacle.display_name = "Check"
		assert(not obstacle.apply_parameters({"unknown": 1}))
		assert(obstacle.get_parameters() == original)
		assert(obstacle.apply_parameters(changes[obstacle_type]))
		assert(obstacle.geometry_revision == revision + 1)
		assert(_resources(obstacle) == geometry, "Resources must survive resizing: " + obstacle_type)
		assert(_resources(peer) == peer_geometry)
		assert(_mesh_bounds(peer) == peer_mesh_bounds, "Meshes must remain instance-local")
		assert(peer.get_parameters() == original, "Parameters must remain instance-local")
		_assert_mesh_bounds(obstacle, obstacle, Transform3D.IDENTITY)
		if obstacle is ObstacleSteppingPads:
			var pads: Array[StaticBody3D] = (obstacle as ObstacleSteppingPads).get_pad_bodies()
			var removed: StaticBody3D = pads.back()
			assert(obstacle.apply_parameters({"pad_count": 1}))
			assert((obstacle as ObstacleSteppingPads).get_pad_bodies()[0] == pads[0])
			assert(is_instance_valid(removed) and removed.is_queued_for_deletion())
			assert(removed.get_parent() == null and removed.collision_layer == 0)
			var request: Dictionary = {"pad_count": 3}
			obstacle.request_apply_parameters(request)
			request["pad_count"] = 12
			assert((obstacle as ObstacleSteppingPads).pad_count == 1)
			await process_frame
			assert((obstacle as ObstacleSteppingPads).pad_count == 3)
		var pick: Node = obstacle.get_node("_EditorPickBody")
		obstacle.set_editor_mode(false)
		obstacle.set_editor_mode(true)
		assert(obstacle.get_node("_EditorPickBody") == pick)
		obstacle.queue_free()
		peer.queue_free()
	await process_frame
	print("PASS geometry safeguards: six rebuilds, no-op, rollback, reuse, bounds, deferred snapshot")
	quit()


func _resources(obstacle: ObstacleBase) -> Dictionary:
	var resources: Dictionary = {}
	for node: Node in obstacle.find_children("*", "", true, false):
		if node is MeshInstance3D:
			resources[String(obstacle.get_path_to(node))] = (node as MeshInstance3D).mesh
		elif node is CollisionShape3D:
			resources[String(obstacle.get_path_to(node))] = (node as CollisionShape3D).shape
	return resources


func _mesh_bounds(obstacle: ObstacleBase) -> Dictionary:
	var bounds: Dictionary = {}
	for node: Node in obstacle.find_children("*", "MeshInstance3D", true, false):
		bounds[String(obstacle.get_path_to(node))] = (node as MeshInstance3D).get_aabb()
	return bounds


func _assert_mesh_bounds(obstacle: ObstacleBase, node: Node, local: Transform3D) -> void:
	if node != obstacle and node is Node3D:
		local = local * (node as Node3D).transform
	if node is MeshInstance3D:
		var actual: AABB = local * (node as MeshInstance3D).get_aabb()
		var bounds: AABB = obstacle.get_local_bounds_aabb().grow(0.001)
		assert(bounds.encloses(actual), "Bounds must contain " + String(node.name))
	for child: Node in node.get_children():
		_assert_mesh_bounds(obstacle, child, local)

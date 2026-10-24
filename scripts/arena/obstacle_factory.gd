class_name ObstacleFactory
extends RefCounted

## Whitelisted obstacle registry and parameter descriptor metadata for M1b Arena Editor & Serializer.
## Security rule: never load scene or script paths directly from user JSON.

const OBSTACLE_SCENE_REGISTRY: Dictionary = {
	"stepping_pads": "res://scenes/obstacles/obs_01_stepping_pads.tscn",
	"balance_beam": "res://scenes/obstacles/obs_02_balance_beam.tscn",
	"moving_platform": "res://scenes/obstacles/obs_03_moving_platform.tscn",
	"rotating_sweeper": "res://scenes/obstacles/obs_04_rotating_sweeper.tscn",
	"swinging_pendulum": "res://scenes/obstacles/obs_05_swinging_pendulum.tscn",
	"warped_wall": "res://scenes/obstacles/obs_06_warped_wall.tscn",
}

const OBSTACLE_DISPLAY_NAMES: Dictionary = {
	"stepping_pads": "Stepping Pads",
	"balance_beam": "Balance Beam",
	"moving_platform": "Moving Platform",
	"rotating_sweeper": "Rotating Sweeper",
	"swinging_pendulum": "Swinging Pendulum",
	"warped_wall": "Warped Wall",
}

const OBSTACLE_COLORS: Dictionary = {
	"stepping_pads": Color(0.22, 0.64, 0.86, 1.0),
	"balance_beam": Color(0.88, 0.68, 0.22, 1.0),
	"moving_platform": Color(0.24, 0.78, 0.54, 1.0),
	"rotating_sweeper": Color(0.92, 0.24, 0.24, 1.0),
	"swinging_pendulum": Color(0.95, 0.42, 0.14, 1.0),
	"warped_wall": Color(0.26, 0.44, 0.78, 1.0),
}

const PARAMETER_DESCRIPTORS: Dictionary = {
	"stepping_pads": [
		{"key": "pad_count", "label": "Pad Count", "type": "int", "min": 1, "max": 12, "step": 1, "default": 4},
		{"key": "pad_dimensions", "label": "Pad Size (X,Y,Z)", "type": "vec3", "min": 0.4, "max": 8.0, "axis_min": [0.4, 0.1, 0.4], "axis_max": [8.0, 4.0, 8.0], "step": 0.1, "default": [1.8, 0.4, 1.8]},
		{"key": "gap_distance", "label": "Gap Distance (m)", "type": "float", "min": 0.2, "max": 4.0, "step": 0.1, "default": 0.8},
		{"key": "height_variation", "label": "Height Var (m)", "type": "float", "min": -1.2, "max": 1.2, "step": 0.05, "default": 0.12},
		{"key": "lateral_offset", "label": "Lateral Offset (m)", "type": "float", "min": 0.0, "max": 2.0, "step": 0.05, "default": 0.45},
	],
	"balance_beam": [
		{"key": "beam_length", "label": "Beam Length (m)", "type": "float", "min": 1.5, "max": 25.0, "step": 0.5, "default": 7.0},
		{"key": "beam_width", "label": "Beam Width (m)", "type": "float", "min": 0.25, "max": 2.5, "step": 0.05, "default": 0.6},
		{"key": "beam_height", "label": "Beam Height (m)", "type": "float", "min": 0.15, "max": 3.0, "step": 0.05, "default": 0.4},
	],
	"moving_platform": [
		{"key": "movement_distance", "label": "Move Distance (m)", "type": "float", "min": 0.5, "max": 25.0, "step": 0.25, "default": 4.6},
		{"key": "movement_speed", "label": "Move Speed (m/s)", "type": "float", "min": 0.1, "max": 15.0, "step": 0.25, "default": 2.4},
		{"key": "travel_mode", "label": "Travel Mode", "type": "enum", "options": ["PING_PONG", "LOOP", "ONE_WAY"], "default": "PING_PONG"},
		{"key": "initial_direction", "label": "Initial Dir", "type": "dir_int", "options": [-1, 1], "default": 1},
		{"key": "platform_size", "label": "Platform Size", "type": "vec3", "min": 0.8, "max": 10.0, "axis_min": [0.8, 0.15, 0.8], "axis_max": [10.0, 4.0, 10.0], "step": 0.1, "default": [2.8, 0.4, 2.8]},
	],
	"rotating_sweeper": [
		{"key": "rotation_speed", "label": "Rot Speed (rad/s)", "type": "float", "min": 0.1, "max": 10.0, "step": 0.1, "default": 1.6},
		{"key": "rotation_direction", "label": "Rot Direction", "type": "dir_int", "options": [-1, 1], "default": 1},
		{"key": "arm_length", "label": "Arm Length (m)", "type": "float", "min": 1.0, "max": 12.0, "step": 0.2, "default": 4.0},
		{"key": "arm_height", "label": "Arm Height (m)", "type": "float", "min": 0.15, "max": 3.0, "step": 0.05, "default": 0.52},
		{"key": "initial_angle_deg", "label": "Init Angle (deg)", "type": "float", "min": -360.0, "max": 360.0, "step": 5.0, "default": 0.0},
		{"key": "push_strength", "label": "Push Strength", "type": "float", "min": 0.5, "max": 25.0, "step": 0.5, "default": 8.5},
	],
	"swinging_pendulum": [
		{"key": "swing_amplitude_deg", "label": "Amplitude (deg)", "type": "float", "min": 1.0, "max": 89.0, "step": 1.0, "default": 45.0},
		{"key": "swing_period", "label": "Period (sec)", "type": "float", "min": 0.4, "max": 15.0, "step": 0.1, "default": 2.4},
		{"key": "pendulum_length", "label": "Length (m)", "type": "float", "min": 1.0, "max": 12.0, "step": 0.2, "default": 3.2},
		{"key": "initial_phase_deg", "label": "Init Phase (deg)", "type": "float", "min": -360.0, "max": 360.0, "step": 5.0, "default": 0.0},
		{"key": "knockback_speed", "label": "Knockback Speed", "type": "float", "min": 0.5, "max": 30.0, "step": 0.5, "default": 9.0},
	],
	"warped_wall": [
		{"key": "wall_height", "label": "Wall Height (m)", "type": "float", "min": 1.8, "max": 6.0, "step": 0.2, "default": 3.2},
		{"key": "wall_width", "label": "Wall Width (m)", "type": "float", "min": 1.5, "max": 8.0, "step": 0.2, "default": 3.6},
		{"key": "curve_profile", "label": "Curve Profile", "type": "float", "min": 0.5, "max": 2.2, "step": 0.1, "default": 1.0},
	],
}

static var _packed_cache: Dictionary = {}


static func get_supported_types() -> Array[String]:
	var types: Array[String] = [
		"stepping_pads",
		"balance_beam",
		"moving_platform",
		"rotating_sweeper",
		"swinging_pendulum",
		"warped_wall",
	]
	return types


static func is_valid_type(type_name: String) -> bool:
	return OBSTACLE_SCENE_REGISTRY.has(type_name.strip_edges())


static func get_display_name(type_name: String) -> String:
	return String(OBSTACLE_DISPLAY_NAMES.get(type_name, type_name))


static func get_indicator_color(type_name: String) -> Color:
	return OBSTACLE_COLORS.get(type_name, Color(0.5, 0.5, 0.5, 1.0)) as Color


static func get_parameter_descriptors(type_name: String) -> Array:
	if PARAMETER_DESCRIPTORS.has(type_name):
		return (PARAMETER_DESCRIPTORS[type_name] as Array).duplicate(true)
	return []


static func get_default_parameters(type_name: String) -> Dictionary:
	var defaults: Dictionary = {}
	for desc: Variant in get_parameter_descriptors(type_name):
		var d: Dictionary = desc as Dictionary
		defaults[String(d["key"])] = d["default"]
	return defaults


static func create_obstacle(type_name: String, custom_instance_id: String = "") -> ObstacleBase:
	var clean_type: String = type_name.strip_edges()
	if not is_valid_type(clean_type):
		return null

	var scene_path: String = String(OBSTACLE_SCENE_REGISTRY[clean_type])
	var packed: PackedScene = _packed_cache.get(clean_type, null) as PackedScene
	if packed == null:
		packed = load(scene_path) as PackedScene
		if packed != null:
			_packed_cache[clean_type] = packed
	if packed == null:
		return null

	var instance: ObstacleBase = packed.instantiate() as ObstacleBase
	if instance == null:
		return null

	if not custom_instance_id.strip_edges().is_empty():
		instance.set_obstacle_instance_id(custom_instance_id.strip_edges())
	elif instance.get_obstacle_instance_id().is_empty():
		instance.set_obstacle_instance_id(ObstacleBase.allocate_unique_instance_id())
	return instance

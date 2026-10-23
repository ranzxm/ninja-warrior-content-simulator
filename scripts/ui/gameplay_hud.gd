class_name GameplayHud
extends Control

## Minimal gameplay HUD for M0 displaying title, PLAY mode badge, state, and key hints.

@onready var _root_margin: Control = get_node_or_null("MarginContainer") as Control
@onready var _title_label: Label = get_node_or_null("MarginContainer/VBoxContainer/TopBar/TitleLabel") as Label
@onready var _mode_label: Label = get_node_or_null("MarginContainer/VBoxContainer/TopBar/ModeLabel") as Label
@onready var _state_label: Label = get_node_or_null("MarginContainer/VBoxContainer/TopBar/StateLabel") as Label
@onready var _controls_label: Label = get_node_or_null("MarginContainer/VBoxContainer/BottomBar/ControlsLabel") as Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_mode_text("PLAY")
	set_player_state_text("IDLE")


func set_mode_text(mode_name: String) -> void:
	if _mode_label != null:
		_mode_label.text = "MODE: %s" % mode_name.to_upper()


func set_player_state_text(state_name: String) -> void:
	if _state_label != null:
		_state_label.text = "STATE: %s" % state_name.to_upper()


func toggle_clean_feed() -> void:
	visible = not visible


func get_mode_text() -> String:
	return _mode_label.text if _mode_label != null else ""


func get_state_text() -> String:
	return _state_label.text if _state_label != null else ""

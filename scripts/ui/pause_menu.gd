class_name PauseMenu
extends Control

## Pause overlay with Resume, Restart, and Quit actions.

signal resume_requested()
signal restart_requested()
signal quit_requested()

@onready var _resume_button: Button = get_node_or_null("CenterContainer/PanelContainer/MarginContainer/VBoxContainer/ResumeButton") as Button
@onready var _restart_button: Button = get_node_or_null("CenterContainer/PanelContainer/MarginContainer/VBoxContainer/RestartButton") as Button
@onready var _quit_button: Button = get_node_or_null("CenterContainer/PanelContainer/MarginContainer/VBoxContainer/QuitButton") as Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if _resume_button != null and not _resume_button.pressed.is_connected(_on_resume_pressed):
		_resume_button.pressed.connect(_on_resume_pressed)
	if _restart_button != null and not _restart_button.pressed.is_connected(_on_restart_pressed):
		_restart_button.pressed.connect(_on_restart_pressed)
	if _quit_button != null and not _quit_button.pressed.is_connected(_on_quit_pressed):
		_quit_button.pressed.connect(_on_quit_pressed)


func set_open(open: bool) -> void:
	visible = open
	mouse_filter = Control.MOUSE_FILTER_STOP if open else Control.MOUSE_FILTER_IGNORE
	if open and _resume_button != null:
		_resume_button.grab_focus()


func _on_resume_pressed() -> void:
	resume_requested.emit()


func _on_restart_pressed() -> void:
	restart_requested.emit()


func _on_quit_pressed() -> void:
	quit_requested.emit()

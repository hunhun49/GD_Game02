class_name PauseMenu
extends CanvasLayer

signal resume_requested

@onready var _root: Control = $Root
@onready var _resume: Button = %Resume

func _ready() -> void:
	_resume.pressed.connect(_on_resume_pressed)
	close()

func open() -> void:
	_root.show()
	_resume.grab_focus()

func close() -> void:
	_resume.release_focus()
	_root.hide()

func is_open() -> bool:
	return _root.visible

func _input(event: InputEvent) -> void:
	if is_open() and event.is_action_pressed("pause"):
		# Consume before signaling so Esc cannot immediately pause again.
		get_viewport().set_input_as_handled()
		resume_requested.emit()

func _on_resume_pressed() -> void:
	resume_requested.emit()

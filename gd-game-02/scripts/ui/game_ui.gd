class_name GameUI
extends Node

signal pause_requested
signal resume_requested

@onready var _hud: SchoolHUD = $HUD
@onready var _dialogue: DialogueView = $DialogueView
@onready var _pause: PauseMenu = $PauseMenu

func _ready() -> void:
	_pause.resume_requested.connect(func() -> void: resume_requested.emit())

func get_dialogue_view() -> DialogueView:
	return _dialogue

func show_location(title: String) -> void:
	_hud.show_location(title)

func show_status(message: String) -> void:
	_hud.show_status(message)

func show_interaction(display_name: String, action: String) -> void:
	_hud.show_interaction(display_name, action)

func show_movement_mode(direction_count: int) -> void:
	_hud.show_movement_mode(direction_count)

func set_paused(value: bool) -> void:
	if value:
		_pause.open()
	else:
		_pause.close()

func is_pause_open() -> bool:
	return _pause.is_open()

func _unhandled_input(event: InputEvent) -> void:
	if _dialogue.is_open() or _pause.is_open():
		return
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		pause_requested.emit()

func show_clock(value: String) -> void:
	_hud.show_clock(value)

func show_needs(hunger: float, thirst: float, fatigue: float) -> void:
	_hud.show_needs(hunger, thirst, fatigue)

func show_relationship(message: String) -> void:
	_hud.show_relationship(message)

func show_health(current: float, maximum: float) -> void:
	_hud.show_health(current, maximum)

func show_stamina(current: float, maximum: float) -> void:
	_hud.show_stamina(current, maximum)

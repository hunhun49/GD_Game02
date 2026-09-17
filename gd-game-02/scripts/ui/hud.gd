class_name SchoolHUD
extends CanvasLayer

@onready var _location: Label = %Location
@onready var _status: Label = %Status
@onready var _prompt: Label = %Prompt
@onready var _combat: Label = %Combat
var _health_text: String = "체력 100 / 100"
var _stamina_text: String = "스태미나 100 / 100"

@onready var _life: Label = %Life
@onready var _relationship: Label = %Relationship
var _clock_text: String = "1일차 08:00"
var _needs_text: String = ""

@onready var _movement: Label = %Movement

# Presentation accepts values, never player/NPC nodes or gameplay enums.
func show_location(title: String) -> void:
	_location.text = title

func show_status(message: String) -> void:
	_status.text = message

func show_interaction(display_name: String, action: String) -> void:
	_prompt.text = "[E / X] %s · %s" % [display_name, action] if not display_name.is_empty() else ""

func show_movement_mode(direction_count: int) -> void:
	_movement.text = "WASD · 방향키 이동  |  %d방향 (F2 전환)  |  E 상호작용  |  Tab 대상 변경" % direction_count

func displayed_location() -> String:
	return _location.text

func displayed_status() -> String:
	return _status.text

func displayed_prompt() -> String:
	return _prompt.text

func displayed_movement() -> String:
	return _movement.text

func show_clock(value: String) -> void:
	_clock_text = value
	_refresh_life()

func show_needs(hunger: float, thirst: float, fatigue: float) -> void:
	_needs_text = "허기 %.0f  ·  갈증 %.0f  ·  피로 %.0f / 100" % [hunger, thirst, fatigue]
	_refresh_life()

func show_relationship(message: String) -> void:
	_relationship.text = message

func _refresh_life() -> void:
	_life.text = _clock_text + "  |  " + _needs_text

func displayed_life() -> String:
	return _life.text

func displayed_relationship() -> String:
	return _relationship.text

func show_health(current: float, maximum: float) -> void:
	_health_text = "체력 %.0f / %.0f" % [current, maximum]
	_refresh_combat()

func show_stamina(current: float, maximum: float) -> void:
	_stamina_text = "스태미나 %.0f / %.0f" % [current, maximum]
	_refresh_combat()

func _refresh_combat() -> void:
	_combat.text = _health_text + "  ·  " + _stamina_text + "  |  J / 패드 B 공격"

func displayed_combat() -> String:
	return _combat.text

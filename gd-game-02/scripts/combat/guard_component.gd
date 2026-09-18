class_name GuardComponent
extends Node

@export var deflect_window: float = 0.12
@export var rearm_interval: float = 0.18
@export var arc_degrees: float = 140.0
var holding: bool = false
var direction: Vector2 = Vector2.DOWN
var _window_left: float = 0.0
var _rearm_left: float = 0.0

func begin(facing: Vector2, allow_deflect: bool = true) -> void:
	if holding:
		return
	holding = true
	direction = facing.normalized()
	_window_left = deflect_window if allow_deflect and _rearm_left <= 0 else 0.0
	_rearm_left = rearm_interval

func end() -> void:
	holding = false
	_window_left = 0

func reset() -> void:
	end()
	_rearm_left = 0

func tick(delta: float) -> void:
	_window_left = maxf(0, _window_left - delta)
	_rearm_left = maxf(0, _rearm_left - delta)

func covers(incoming: Vector2) -> bool:
	return holding and (incoming.is_zero_approx() or direction.dot(incoming.normalized()) >= cos(deg_to_rad(arc_degrees * 0.5)))

func can_deflect() -> bool:
	return holding and _window_left > 0

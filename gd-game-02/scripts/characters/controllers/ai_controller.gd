class_name AIController
extends CharacterController

# A command receiver for future schedules/navigation; idle until commanded.
var _direction: Vector2 = Vector2.ZERO

func steer(direction: Vector2) -> void:
	_direction = direction.limit_length() if direction.is_finite() else Vector2.ZERO

func stop() -> void:
	_direction = Vector2.ZERO

func move_direction() -> Vector2:
	return _direction

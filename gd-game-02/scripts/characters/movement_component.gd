@tool
class_name MovementComponent
extends Node

signal mode_changed(direction_count: int)

enum MovementMode { FOUR_DIRECTIONS, EIGHT_DIRECTIONS }

@export var mode: MovementMode = MovementMode.EIGHT_DIRECTIONS:
	set(value):
		if mode == value:
			return
		mode = value
		if is_inside_tree():
			(get_parent() as SchoolCharacter).reset_motion()
		mode_changed.emit(8 if mode == MovementMode.EIGHT_DIRECTIONS else 4)

var previous_input: Vector2 = Vector2.ZERO
var walk_phase: float = 0.0

func step(actor: SchoolCharacter, requested: Vector2, delta: float) -> void:
	var raw := requested.limit_length()
	var direction := Vector2.ZERO
	if not raw.is_zero_approx():
		actor.facing = _cardinal_facing(raw, actor.facing)
		if mode == MovementMode.FOUR_DIRECTIONS:
			direction = actor.facing * raw.length()
			if actor.facing.x == 0.0:
				actor.velocity.x = 0.0
			else:
				actor.velocity.y = 0.0
		else:
			direction = Vector2.from_angle(snappedf(raw.angle(), PI / 4.0)) * raw.length()
	previous_input = raw
	var settings := actor.definition
	actor.velocity = actor.velocity.move_toward(direction * settings.run_speed, (settings.braking if direction.is_zero_approx() else settings.acceleration) * delta)
	actor.move_and_slide()
	walk_phase = walk_phase + delta * 14.0 if actor.get_position_delta().length() > 0.1 else 0.0

func _cardinal_facing(raw: Vector2, facing: Vector2) -> Vector2:
	if absf(raw.x) > absf(raw.y) + 0.05:
		return Vector2(signf(raw.x), 0)
	if absf(raw.y) > absf(raw.x) + 0.05:
		return Vector2(0, signf(raw.y))
	if absf(raw.x) > 0.0 and is_zero_approx(previous_input.x):
		return Vector2(signf(raw.x), 0)
	if absf(raw.y) > 0.0 and is_zero_approx(previous_input.y):
		return Vector2(0, signf(raw.y))
	if facing.dot(raw) > 0.0:
		return facing
	return Vector2(0, signf(raw.y))

func reset() -> void:
	previous_input = Vector2.ZERO
	walk_phase = 0.0

class_name DodgeComponent
extends Node

@export var speed: float = 620.0
@export var duration: float = 0.18
@export var recovery: float = 0.2
@export var counter_window: float = 0.12
var direction: Vector2 = Vector2.DOWN
var elapsed: float = 0.0
var distance_moved: float = 0.0
var moving: bool = false
var recovery_left: float = 0.0

func is_busy() -> bool:
	return moving or recovery_left > 0

func begin(aim: Vector2) -> bool:
	if is_busy() or not aim.is_finite() or aim.is_zero_approx():
		return false
	direction = aim.normalized()
	elapsed = 0
	distance_moved = 0
	recovery_left = 0
	moving = true
	return true

# Called by the character instead of ordinary movement; collision remains physical.
func step(actor: SchoolCharacter, delta: float) -> void:
	if moving:
		var travel_time := minf(delta, maxf(0, duration - elapsed))
		var before := actor.global_position
		actor.move_and_collide(direction * speed * travel_time)
		distance_moved += actor.global_position.distance_to(before)
		elapsed += delta
		if elapsed >= duration:
			moving = false
			recovery_left = maxf(0, recovery - (elapsed - duration))
	else:
		recovery_left = maxf(0, recovery_left - delta)
	actor.reset_motion()

func can_counter(incoming: Vector2) -> bool:
	return moving and elapsed > 0 and elapsed <= counter_window and distance_moved >= 1 and not incoming.is_zero_approx() and direction.dot(incoming.normalized()) >= cos(deg_to_rad(40.0))

func evades_normal() -> bool:
	return moving and elapsed >= 0.03 and elapsed <= 0.13 and distance_moved >= 1

func cancel() -> void:
	moving = false
	recovery_left = 0
	elapsed = 0
	distance_moved = 0

class_name PlayerController
extends CharacterController

signal attack_requested
signal interact_requested
signal cycle_target_requested
signal respawn_requested

func move_direction() -> Vector2:
	return Input.get_vector("move_left", "move_right", "move_up", "move_down")

func _unhandled_input(event: InputEvent) -> void:
	var actor := get_parent() as SchoolCharacter
	if event.is_echo():
		return
	if actor.can_act(SchoolCharacter.Action.ATTACK) and event.is_action_pressed("attack"):
		attack_requested.emit()
	elif actor.can_act(SchoolCharacter.Action.INTERACT) and event.is_action_pressed("interact"):
		interact_requested.emit()
	elif actor.can_act(SchoolCharacter.Action.INTERACT) and event.is_action_pressed("cycle_target"):
		cycle_target_requested.emit()
	elif (actor.can_act(SchoolCharacter.Action.MOVE) or actor.can_act(SchoolCharacter.Action.RECOVER)) and event.is_action_pressed("respawn"):
		respawn_requested.emit()
	elif actor.can_act(SchoolCharacter.Action.MOVE) and event.is_action_pressed("toggle_movement"):
		actor.movement.mode = MovementComponent.MovementMode.FOUR_DIRECTIONS if actor.movement.mode == MovementComponent.MovementMode.EIGHT_DIRECTIONS else MovementComponent.MovementMode.EIGHT_DIRECTIONS
	else:
		return
	get_viewport().set_input_as_handled()

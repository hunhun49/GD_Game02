class_name PlayerController
extends CharacterController

signal guard_requested(pressed: bool, allow_deflect: bool)
signal dodge_requested
signal purple_requested
signal attack_requested
signal interact_requested
signal cycle_target_requested
signal respawn_requested

func move_direction() -> Vector2:
	return Input.get_vector("move_left", "move_right", "move_up", "move_down")

func _input(event: InputEvent) -> void:
	var aim := get_parent().get_node_or_null("Aim") as AimComponent
	if aim == null:
		return
	if event is InputEventMouseMotion or event is InputEventMouseButton:
		aim.track_pointer(event.position)
	elif event is InputEventJoypadButton or (event is InputEventJoypadMotion and absf(event.axis_value) > 0.25):
		aim.pointer_active = false

func _unhandled_input(event: InputEvent) -> void:
	var actor := get_parent() as SchoolCharacter
	if event.is_echo():
		return
	var aim := actor.get_node_or_null("Aim") as AimComponent
	if aim != null:
		aim.refresh()
	if actor.can_act(SchoolCharacter.Action.COMBAT_TICK) and event.is_action_pressed("dodge"):
		dodge_requested.emit()
	elif actor.can_act(SchoolCharacter.Action.COMBAT_TICK) and event.is_action_pressed("purple_attack"):
		purple_requested.emit()
	elif event.is_action_released("guard"):
		guard_requested.emit(false, false)
	elif actor.can_act(SchoolCharacter.Action.COMBAT_TICK) and event.is_action_pressed("guard"):
		guard_requested.emit(true, true)
	elif actor.can_act(SchoolCharacter.Action.COMBAT_TICK) and event.is_action_pressed("attack"):
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

func _physics_process(_delta: float) -> void:
	# Releases consumed by a dialogue/menu must not leave a latched guard.
	if not Input.is_action_pressed("guard"):
		guard_requested.emit(false, false)
	else:
		guard_requested.emit(true, false)

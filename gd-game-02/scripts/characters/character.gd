@tool
class_name SchoolCharacter
extends CharacterBody2D

enum Action { MOVE = 1, INTERACT = 2, ATTACK = 4, RECOVER = 8, ALL = 15 }

@export var character_id: StringName
@export var definition: CharacterDefinition

var state: CharacterState
var facing: Vector2:
	get: return state.facing if state != null else Vector2.DOWN
	set(value):
		if state != null:
			state.facing = value

@onready var movement: MovementComponent = $Movement
@onready var controller: CharacterController = $Controller
var _locks: Dictionary[int, int] = {}
var _next_token: int = 0

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	if definition == null or character_id.is_empty():
		push_error("Character requires an explicit ID and definition: %s" % name)
		set_physics_process(false)
		return
	if state == null:
		bind_state_store(CharacterStateStore.new())

func bind_state_store(store: CharacterStateStore) -> void:
	state = store.get_or_create(character_id, definition)
	var health := get_node_or_null("Health") as HealthComponent
	if health != null:
		health.bind_character(self)
	var stamina := get_node_or_null("Stamina") as StaminaComponent
	if stamina != null and state != null:
		stamina.bind_character(self)

func bind_session(session: SessionState) -> void:
	bind_state_store(session.characters)
	var needs_component := get_node_or_null("Needs") as NeedsComponent
	if needs_component != null:
		needs_component.configure(session.needs, character_id, definition.needs_profile)

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if can_act(Action.MOVE):
		movement.step(self, controller.move_direction(), delta)
	else:
		reset_motion()

func can_act(action: Action) -> bool:
	if state == null or not is_inside_tree() or not can_process() or is_queued_for_deletion():
		return false
	if action == Action.RECOVER:
		if state.activity != CharacterState.Activity.INCAPACITATED or state.current_health > 0:
			return false
	elif state.activity != CharacterState.Activity.ACTIVE or state.current_health <= 0:
		return false
	for blocked in _locks.values():
		if blocked & action:
			return false
	return true

func acquire_action_lock(actions: int) -> int:
	_next_token += 1
	_locks[_next_token] = actions
	if actions & Action.MOVE:
		reset_motion()
	return _next_token

func release_action_lock(token: int) -> void:
	_locks.erase(token)

# Existing dialogue/cutscene API; each caller releases only its own token.
func acquire_control_lock() -> int:
	return acquire_action_lock(Action.ALL)

func release_control_lock(token: int) -> void:
	release_action_lock(token)

func has_action_locks() -> bool:
	return not _locks.is_empty()

func is_control_locked() -> bool:
	return state == null or state.activity != CharacterState.Activity.ACTIVE or not _locks.is_empty()

func reset_motion() -> void:
	velocity = Vector2.ZERO
	if is_instance_valid(movement):
		movement.reset()

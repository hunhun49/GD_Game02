class_name TrainingController
extends CharacterController

# Idle guard -> normal -> blue -> red -> purple -> guard.
@export var blue_attack: AttackDefinition
@export var purple_attack: AttackDefinition
@export var danger_attack: AttackDefinition
@export var reply_delay: float = 0.7
@export var disengage_distance: float = 240.0
var _source_id: StringName
var _remaining: float = 0.0
var _step: int = 0
var _combat: CombatComponent
var _normal: AttackDefinition
var _danger: AttackDefinition

func _ready() -> void:
	_combat = get_parent().get_node("Combat")
	_normal = _combat.attack
	_danger = danger_attack
	if _danger == null or not _danger.is_valid() or blue_attack == null or not blue_attack.is_valid() or purple_attack == null or not purple_attack.is_valid():
		push_error("TrainingController requires a valid danger attack definition.")
		set_physics_process(false)
		return
	_combat.contact_received.connect(_on_contact)
	get_parent().get_node("Health").incapacitated.connect(reset_training)

func is_training() -> bool:
	return not _source_id.is_empty()

func _on_contact(source: CombatComponent, _outcome: HitResolver.Outcome) -> void:
	if _combat.health().current() <= 0 or not is_instance_valid(source):
		return
	if _source_id.is_empty():
		_source_id = source.actor().character_id
		_remaining = reply_delay
		_step = 0

func reset_training() -> void:
	_source_id = &""
	_remaining = reply_delay
	_step = 0
	if is_instance_valid(_combat):
		_combat.reset_encounter()
		_combat.attack = _normal

func _physics_process(delta: float) -> void:
	if not _combat.time_running() or _combat.is_staggered():
		return
	if not is_training():
		_combat.set_guard(true, false)
		return
	var target := _combat.find_target(_source_id)
	if target == null or _combat.actor().global_position.distance_to(target.actor().global_position) > disengage_distance:
		if is_instance_valid(target) and not _other_trainer_active(target):
			target.reset_encounter()
		reset_training()
		return
	if _combat.phase != CombatComponent.Phase.READY:
		return
	_remaining -= delta
	_combat.face_target(target)
	if _step == 0:
		_combat.set_guard(true, false)
	if _remaining > 0:
		return
	_combat.set_guard(false)
	_combat.attack = [_normal, blue_attack, _danger, purple_attack][_step]
	# Out-of-range targets are not pursued. Aiming is fixed at commitment.
	if _combat.try_attack(target):
		_step = (_step + 1) % 4
		_remaining = reply_delay if _step == 0 else 0.12

func _other_trainer_active(target: CombatComponent) -> bool:
	for node in get_tree().get_nodes_in_group("combatants"):
		var other := node as CombatComponent
		if other == _combat or other.get_scope() != _combat.get_scope():
			continue
		var controller := other.actor().controller as TrainingController
		if controller != null and controller._source_id == _source_id and other.health().current() > 0 and other.actor().global_position.distance_to(target.actor().global_position) <= controller.disengage_distance:
			return true
	return false

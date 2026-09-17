class_name TrainingController
extends CharacterController

@export var reply_delay: float = 0.75
var _source_id: StringName
var _remaining: float = 0.0

func _ready() -> void:
	get_parent().get_node("Health").damaged.connect(_on_damaged)
	get_parent().get_node("Health").incapacitated.connect(reset_training)

func _on_damaged(event: DamageEvent, _amount: float) -> void:
	if _source_id.is_empty():
		_source_id = event.source_id
		_remaining = reply_delay

func reset_training() -> void:
	_source_id = &""
	_remaining = 0.0

func _physics_process(delta: float) -> void:
	var character := get_parent() as SchoolCharacter
	if _source_id.is_empty() or not character.can_act(SchoolCharacter.Action.ATTACK):
		return
	_remaining -= delta
	if _remaining > 0:
		return
	var combat := character.get_node("Combat") as CombatComponent
	var target := combat.find_target(_source_id)
	reset_training()
	if target == null:
		return
	var direction := target.actor().global_position - character.global_position
	if not direction.is_zero_approx():
		character.facing = Vector2(signf(direction.x), 0) if absf(direction.x) > absf(direction.y) else Vector2(0, signf(direction.y))
	combat.try_attack(target)

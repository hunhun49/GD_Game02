class_name StatusCharacterBridge
extends RefCounted

# The only status service aware of the concrete character/combat implementation.
var _actor: WeakRef
var _lock_token: int = 0
var _blocked: int = 0
var modifiers := StatusModifiers.new()

func _init(actor: SchoolCharacter) -> void:
	_actor = weakref(actor)

func actor() -> SchoolCharacter:
	return _actor.get_ref() as SchoolCharacter

func available() -> bool:
	var target := actor()
	return is_instance_valid(target) and target.is_inside_tree() and not target.is_queued_for_deletion() and target.state != null and target.state.current_health > 0 and target.state.activity == CharacterState.Activity.ACTIVE

func time_running() -> bool:
	return available() and actor().can_act(SchoolCharacter.Action.COMBAT_TICK)

func update(value: StatusModifiers) -> void:
	var added := value.blocked_actions & ~_blocked
	modifiers = value
	if not is_instance_valid(actor()):
		return
	if _blocked != value.blocked_actions:
		if _lock_token != 0:
			actor().release_action_lock(_lock_token)
		_blocked = value.blocked_actions
		_lock_token = actor().acquire_action_lock(_blocked, false) if _blocked != 0 else 0
	if actor().definition != null:
		actor().velocity = actor().velocity.limit_length(actor().definition.run_speed * modifiers.multiplier(&"movement_speed"))
	var combat := actor().get_node_or_null("Combat") as CombatComponent
	if combat != null and added != 0:
		# Publish only after all state is committed: callbacks may update us again.
		combat.interrupt_actions(added)
	elif added & SchoolCharacter.Action.DODGE:
		var dodge := actor().get_node_or_null("Dodge") as DodgeComponent
		if dodge != null:
			dodge.cancel()

func release() -> void:
	if is_instance_valid(actor()) and _lock_token != 0:
		actor().release_action_lock(_lock_token)
	_lock_token = 0
	_blocked = 0
	modifiers = StatusModifiers.new()

func damage(effect: StatusEffectInstance, amount: float, type: DamageType.Type, sequence: int) -> float:
	var health := actor().get_node_or_null("Health") as HealthComponent
	if health == null:
		return 0.0
	var request := DamageRequest.new()
	request.source_id = effect.source_id
	request.target_id = actor().character_id
	request.attack_id = effect.definition.status_id
	request.emitter_id = get_instance_id()
	request.sequence = sequence
	request.amount = amount
	request.damage_type = type
	var combat := actor().get_node_or_null("Combat") as CombatComponent
	var result := DamageResolver.resolve_periodic(request, combat.defense_profile if combat != null else null)
	return health.take_damage(DamageEvent.from_result(result)) if result != null else 0.0

func heal(amount: float) -> float:
	var health := actor().get_node_or_null("Health") as HealthComponent
	return health.heal(amount) if health != null else 0.0
